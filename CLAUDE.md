@AGENTS.md

# This fork: customer support portal

Chatwoot 4.19.1 plus an invite-only customer support portal. Read `README.md` first
(local setup on Windows, credentials, features), then `docs/customer-portal.md` and
`docs/support-email-notifications.md`.

- Fork code lives in `custom/` (models, controllers, jobs, mailers, views, `Tickets::*`
  services) with routes in `config/routes/tickets.rb`. Upstream files were touched only where listed in `FORK_CHANGES.md`.
- Customer portal URL: `/premium-support`. The old anonymous `/support` site was removed on purpose.
- Never commit `.env`, real passwords, API keys, or real customer/employee email addresses. Use `example.com` placeholders in docs and specs.
- Run specs and lint through Docker (see README, "Run the tests"); they do not run on a bare Windows Ruby install.
- Commit messages follow Conventional Commits and must not mention Claude or any AI tool.
- Ask before running migrations or anything that changes or deletes data on a database the user cares about.
