# Chatwoot + Customer Support Portal

A company fork of [Chatwoot](https://www.chatwoot.com) 4.19.1 (MIT) with an **invite-only customer support portal**.

- Agents work in the normal Chatwoot dashboard (`http://localhost:3000`).
- Customers are **invited by the team**, verify their email, set a password, and then sign in at `/premium-support` to submit and follow tickets, reply, attach files, and close/reopen.
- Notification emails are plain text. Customers can **reply by email** and the reply lands on the ticket. Unanswered tickets get a reminder after 48 h and are auto-resolved 24 h later (opt-in).
- English and Vietnamese. Also in this fork: custom roles, SLA policies, audit logs, capacity-based assignment (see `FORK_CHANGES.md`).

Chatwoot's own README is kept at `docs/UPSTREAM_README.md`.

> **Security first:** never commit `.env`, passwords, API keys or real customer/employee emails. All addresses in this repo are `example.com` placeholders. Real values live only in your local `.env` (git-ignored) or on the server.

---

## 1. What you need (Windows 10/11)

| Tool | Notes |
| --- | --- |
| [Git for Windows](https://git-scm.com/download/win) | Line endings are forced to LF by `.gitattributes`. |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | Use the **WSL 2** backend. Give it at least **8 GB RAM** (the first image build compiles the frontend). Example `%UserProfile%\.wslconfig`: `[wsl2]` then `memory=8GB`, then run `wsl --shutdown`. |
| [Claude Code](https://docs.claude.com/en/docs/claude-code/setup) | Follow the official Windows install guide. |

You do **not** need Ruby, Node or PostgreSQL on Windows. Everything runs in containers. All commands below are PowerShell.

## 2. Quick start

```powershell
# 1. Get the code (history is large, ~300 MB; the first clone takes a while)
git clone <REPO_URL> chatwoot-portal
cd chatwoot-portal

# 2. Create your local config
Copy-Item .env.local.example .env

# 3. Generate SECRET_KEY_BASE (128 hex chars) and paste it into .env
-join ((1..128) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })

# 4. Build the image from source (10-20 min the first time, cached afterwards)
docker compose build rails

# 5. Create the database, then start everything
docker compose run --rm rails bundle exec rails db:chatwoot_prepare
docker compose up -d
```

Open **http://localhost:3000**. The first visit shows the onboarding page: create your administrator and account. Outgoing mail is caught by Mailpit at **http://localhost:8025**.

```powershell
# 6. Create the portal inbox + issue types (prints TICKET_PORTAL_INBOX_ID)
docker compose exec rails bundle exec rails tickets:setup
#    -> put that number in .env as TICKET_PORTAL_INBOX_ID=<number>, then:
docker compose up -d --force-recreate rails sidekiq
```

```text
# 7. Add the product list the "Submit ticket" form needs (in the dashboard, as admin):
Settings -> Custom Attributes -> Add -> "Conversation" tab
  Display name: Support product      (the key must become  support_product)
  Type: List        Values: your products, e.g. Product A, Product B
```

Without `support_product` the portal's Product dropdown is empty and submitting is disabled.

Stop: `docker compose stop`. Remove everything including data: `docker compose down -v`.

## 3. Run the tests

Specs run in a container against a separate test database (never your dev data).

```powershell
docker compose build rails                    # the test image is built on top of it
# first time only: create the test database
docker compose --profile test run --rm --build portal_test sh -c "bundle exec rails db:create db:schema:load"
# run the fork's specs (rebuilds the test image so it sees your latest code)
docker compose --profile test run --rm --build portal_test bundle exec rspec spec/custom
# one file / lint
docker compose --profile test run --rm --build portal_test bundle exec rspec spec/custom/requests/premium_support_tickets_spec.rb
docker compose --profile test run --rm --build portal_test bundle exec rubocop custom spec/custom
docker compose --profile test run --rm --build portal_test pnpm exec eslint app/javascript/dashboard/api/portalCustomers.js
```

Expected: `spec/custom` is the fork's suite (about 210 examples, all passing at handover).

## 4. Day-to-day workflow

```powershell
# After changing code: rebuild once (rails and sidekiq share the image) and restart
docker compose build rails
docker compose up -d rails sidekiq

docker compose logs -f rails sidekiq   # watch logs
docker compose ps                      # status
```

- After editing `.env`, recreate the containers: `docker compose up -d --force-recreate rails sidekiq`. A plain restart does not re-read it.
- Database changes: generate migrations with `bundle exec rails g migration Name` inside a container, then `docker compose run --rm rails bundle exec rails db:migrate`. Back up first if the data matters.

## 5. Credentials and configuration

Everything is configured through `.env` (copy of `.env.local.example`). **Do not paste real credentials into chats, issues or commits.** For daily development use Mailpit and no real credentials at all.

### 5.1 Email, local testing (default, no credentials)

`.env.local.example` already points SMTP at the Mailpit container (`SMTP_ADDRESS=mailpit`, port 1025). Keep `SMTP_USERNAME`, `SMTP_PASSWORD` and `SMTP_AUTHENTICATION` commented out or absent: even an empty value makes Rails attempt a login, which Mailpit rejects (`502 Command not implemented`) and no mail is sent. Every email the portal sends shows up at http://localhost:8025: invitations, ticket confirmations, agent replies, reminders.

### 5.2 Email, real sending (Google Workspace / Gmail)

Put these in the **server's** `.env` (or temporarily in yours if you must test with real mail):

```ini
MAILER_SENDER_EMAIL=Company Support <support@yourdomain.com>
SMTP_DOMAIN=yourdomain.com
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=mailbox-owner@yourdomain.com
SMTP_PASSWORD=<Google app password>
SMTP_AUTHENTICATION=login
SMTP_ENABLE_STARTTLS_AUTO=true
SMTP_OPENSSL_VERIFY_MODE=peer
```

Create the app password at Google Account -> Security -> 2-Step Verification -> App passwords (2-step verification must be on). Then recreate `rails` and `sidekiq`.

### 5.3 Reply-by-email (optional, needs real Gmail)

When enabled, ticket emails go out from the support address with a ticket-specific reply address (`support+ticket-<id>@yourdomain.com`). A job runs every minute, reads the Gmail inbox read-only over IMAP (`imap.gmail.com`, using `SMTP_USERNAME` / `SMTP_PASSWORD`), and imports replies from the **active portal customer** who owns the ticket. Anything else is ignored.

```ini
TICKET_EMAIL_REPLIES_ENABLED=true
TICKET_SUPPORT_EMAIL=support@yourdomain.com
```

Requirements: IMAP enabled on the mailbox; `support@` is an alias of the `SMTP_USERNAME` account; plus-addressing works for the domain. Mailpit cannot test this part. Details and the test history: `docs/support-email-notifications.md`.

### 5.4 Follow-up reminders (optional)

`TICKET_FOLLOW_UP_ENABLED=true` turns on: reminder 48 h after an agent reply that the customer has not answered, auto-resolve 24 h later. Any new conversation activity cancels the old countdown. Implemented and covered by specs; not yet observed live over the full 48 h.

### 5.5 Portal variables

| Variable | Meaning |
| --- | --- |
| `TICKET_PORTAL_INBOX_ID` | Inbox that receives portal tickets. Printed by `rails tickets:setup`. |
| `FRONTEND_URL` | Base URL used in every email link. Must be the URL customers actually open (`http://localhost:3000` locally). |
| `TICKET_EMAIL_REPLIES_ENABLED`, `TICKET_SUPPORT_EMAIL` | Reply-by-email (5.3). |
| `TICKET_FOLLOW_UP_ENABLED` | Reminders and auto-resolve (5.4). |

Product list = Conversation custom attribute `support_product`; issue types = `issue_type` (created by `tickets:setup`). Both are edited under Settings -> Custom Attributes.

## 6. Tour of the basic features

1. **Invite a customer.** As administrator: Settings -> **Portal customers** -> add name, email, language. An invitation email is sent (Mailpit locally). The list shows status *invited / active / suspended*, and has resend invitation, password reset, suspend and reactivate.
2. **Customer activates.** Open the link in the email, choose a password (12+ characters). Sign-in is at `/premium-support/login`. Invitation links are valid for 48 h; reset links for 30 min.
3. **Customer submits a ticket.** `/premium-support` -> *Submit ticket*: product, subject, issue type, urgency, message, up to 5 attachments (10 MB each). A confirmation email is sent.
4. **Agent replies.** In the dashboard the ticket is a conversation in the *Support Portal* inbox. A public reply emails the customer and appears in the portal; private notes are never shown to customers.
5. **Customer continues.** Replies in the portal (or by email if 5.3 is on), or closes/reopens the ticket. A customer reply reopens a resolved ticket.
6. **Account control.** Suspending a customer signs them out and blocks portal access and email notifications. Contacts who are not active portal customers get no portal emails.
7. **Language.** The portal follows the customer's language (en/vi); `?locale=vi` switches it.

The old anonymous `/support` form was removed on purpose. Only invited customers can use the portal.

## 7. Where things live

| Area | Path |
| --- | --- |
| Portal models, controllers, views, jobs, mailers, listener, services | `custom/` (`custom/app/...`, `custom/lib/tickets/`) |
| Portal routes | `config/routes/tickets.rb` |
| Portal customers admin (API + Settings page) | `custom/app/controllers/api/v1/accounts/portal_customers_controller.rb`, `app/javascript/dashboard/routes/dashboard/settings/portalCustomers/` |
| Email: send, receive, follow-up | `custom/app/mailers/ticket_mailer.rb`, `custom/lib/tickets/email_routing.rb`, `custom/app/services/tickets/`, `custom/app/jobs/tickets/`, `config/schedule.yml` |
| Specs | `spec/custom/` |
| Fork changes to upstream files | `FORK_CHANGES.md` |
| Design and email notes | `docs/customer-portal.md`, `docs/support-email-notifications.md` |

`docs/` mentions helper scripts under `.codex/`. Those are local, git-ignored files and are not in this repo; use the Docker commands in section 3 instead.

## 8. Working with Claude Code

```powershell
cd chatwoot-portal
claude
```

- `CLAUDE.md` (imports `AGENTS.md`) is loaded automatically and holds the repo rules: smallest change, Conventional Commits, no mention of AI tools in commit messages, never commit secrets.
- Ask it to run specs through Docker (section 3), and to ask before any migration or data change.
- Keep real credentials out of the conversation. If Claude must read `.env`, use the Mailpit setup.

## 9. Status and next steps

Working locally: invitations, portal sign-in, ticket submit/reply/close/reopen, attachments, plain-text notification emails, reply-by-email through Gmail (tested with a real round trip), follow-up logic (specs).

Not done yet:
- Production deployment, domain and TLS (`FRONTEND_URL` and email links must use the public URL).
- Subscriptions / licensing, and a knowledge base.
- Portal polish: profile editing, ticket list search and filters, final branding. The product list is global (no per-customer restriction).

## 10. Troubleshooting

| Symptom | Fix |
| --- | --- |
| `exec ... no such file or directory` when a container starts | A script got CRLF line endings. Re-clone, or run `git config core.autocrlf false`, delete the folder, clone again. |
| Build killed or "out of memory" | Raise Docker/WSL2 memory to 8 GB (section 1). |
| `Bind for 127.0.0.1:3000 failed` | Something else uses port 3000. Stop it or change the port mapping in `docker-compose.local.yaml`. |
| Changed `.env`, nothing happened | `docker compose up -d --force-recreate rails sidekiq` |
| Portal says request rejected (422) | Hard-refresh; check the Rails log with `docker compose logs rails`. Forms need the portal's `same-origin` referrer policy, which is already set. |
| Product dropdown empty | Create the `support_product` attribute (step 7). |
| No email arrives | Locally open http://localhost:8025. Otherwise check `docker compose logs sidekiq` and the SMTP settings in 5.2. |
