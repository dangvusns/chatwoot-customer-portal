# Customer support portal

## Agreed scope

Build and verify locally at `/premium-support` first. Public deployment at
`https://solidnsoft.com/premium-support` comes after local acceptance.

- Individual customers see only their own tickets; no public registration or guest submissions.
- Chatwoot administrators invite customers, resend invitations, reset passwords, suspend and reactivate access, and manage the product catalog.
- Invitations let customers set their own passwords. Customer identities are separate from agent users.
- Customer screens: sign-in, activation/reset, profile, searchable/filterable ticket list, submission, conversation, close/reopen.
- Submission: subject, full-catalog product selection, issue type, urgency (Low/Normal/High/Urgent), message and attachments.
- Show customer identity as full name and email from the profile.
- A customer reply reopens a resolved ticket; reopening has no time limit.
- English and Vietnamese; customer language preference also controls notifications.
- Portal and email branding: Solid&Soft Support, using the existing company logo once supplied/configured.
- Email supports replies to existing tickets only. Subscription/license/expiry information and knowledge base are later releases.

## Implementation milestones

1. Customer accounts and administrator management.
2. Complete ticket workflow and customer profile.
3. Final branded portal and bilingual HTML/plain-text notification templates.
4. Inbound email integration with ownership, threading, attachment, duplicate and loop checks.
5. Legacy ticket ownership/link migration and local end-to-end verification.
6. Public HTTPS deployment planning after local acceptance.

## Account foundation

`PortalCustomer` links an account and contact, without adding agent privileges.
A unique contact index prevents concurrent invitations creating multiple identities
for the same contact. Existing account/contact deletion hooks remove the portal identity.

Passwords use Rails `has_secure_password` and the installed BCrypt dependency.
Passwords require at least 12 characters and at most 72 bytes. Invitations expire
after 48 hours; password resets expire after 30 minutes. Rails signed tokens bind
to the account's access version and status. Activation/reset, resend, suspension,
and reactivation invalidate earlier relevant tokens or sessions. Sessions expire
after 12 hours. Changing the linked contact email suspends access, clears the old
password and requires administrator reactivation followed by a new invitation. Authentication pages keep CSRF protection and use generic failure messages.

Administrator APIs return only identity, locale and status, never password digests,
session versions or access tokens. They scope lookups to `Current.account` and
require its administrator role. Invitation emails go to the linked contact address.

The current local implementation adds `/premium-support` authentication, a paginated
customer-scoped ticket list, submission, public conversation history, replies,
close/reopen actions, and authenticated attachment downloads, plus Settings → Portal
customers. Profile editing, list search/filters, final branding, inbound mail and
legacy link restrictions remain subsequent work. Existing `/support` and signed-ticket
routes remain unchanged until migration is implemented.

The product catalog reuses the administrator-only Custom Attributes settings:
create a Conversation List attribute with key `support_product` and the full catalog
as its list values. Issue types use the existing `issue_type` Conversation List.
The preview seeds Product A/Product B and sample issue types. No purchase/license
restriction is applied. An empty catalog displays a clear notice and disables submission.
Ticket subjects use the existing `additional_attributes.mail_subject` field; urgency
uses Chatwoot's native priority, with Normal displayed for its `medium` value.
Signed-in identity is bound on the server rather than accepted from form fields.

Ticket history loads the newest 50 public incoming/outgoing messages per page and
renders them chronologically; older messages remain pageable. Attachment downloads
check contact, inbox, conversation and public-message ownership before using Rails'
blob streaming. Internal notes and their attachments are never exposed.

## Required acceptance checks

| Check | Expected result | Evidence |
| --- | --- | --- |
| Activate invitation | Password set; expired/reused link rejected | Model and request specs |
| Agent vs customer | Agent credentials do not grant a portal session; customer is not an agent | Request specs |
| Tenant isolation | Customer and administrator lookups cannot cross account boundaries | Request specs |
| Suspension | Existing sessions and earlier access links are rejected, including after reactivation | Model and request specs |
| Recovery | Generic response for unknown email; single-use expiring reset | Model and request specs |
| Localization | English/Vietnamese screens and correct customer email language | Request and mailer specs |
| CSRF and throttling | Cross-site mutations denied; authentication attempts bounded | Request/middleware checks |
| Final tickets | Own-ticket and attachment access only; private notes never exposed | Later workflow specs |
| Final incoming email | Same-ticket reply, verified ownership, deduplication, no new tickets | Later integration specs |

## Local test environment

`docker/portal-test.Dockerfile` extends the existing local `co.4` image with the
repository's test dependencies. Run the compose override together with the outer
workspace's `docker-compose.yaml`; its build paths intentionally match that layout.

The `portal_test` service uses `RAILS_ENV=test`, database
`chatwoot_customer_portal_test`, and Redis DB 14. Its runner must unset
`DATABASE_URL` so an inherited URL cannot override the named test database.
Do not run tests against the live database. Source schema changes must be inspected
before building a deployment image. Do not change the running service's image yet.

Developer-local helpers live under `.codex/` and are ignored by Git. The current
validation helper logs to `.codex/account-tests.log`. Runtime test results, lint
results and browser checks must be recorded before marking a milestone complete.

## Verification status (2026-11-16)

- Isolated test run: **143 examples, 0 failures** across `spec/custom`.
- RuboCop: **17 files inspected, no offenses**.
- Frontend ESLint: completed without errors after the Ruby checks.
- JavaScript/JSON syntax and `git diff --check`: passed.
- Account checks above passed before the submission workflow was added.
- Expanded submission workflow suite: **165 examples, 0 failures**.
- Expanded RuboCop: **23 files inspected, no offenses**; frontend ESLint completed without errors.
- Browser walkthrough on port 3101: created a ticket, confirmed it in Chatwoot,
  sent an administrator reply, closed the ticket and reopened it by customer reply,
  and checked English/Vietnamese screens and chronological history.
- Browser file upload could not be exercised because the browser tool denied the
  local fixture path; automated attachment tests are included in the expanded suite.
- No deployment or migration has been applied to the original running Chatwoot database.
- The local preview must remain running in its terminal; restart `.codex/preview-accounts.sh` if port 3101 stops responding.

The preview helper uses database `chatwoot_customer_portal_preview`, Redis DB 15,
and a localhost-only binding. It seeds synthetic administrator and customer
accounts and keeps Rails in the test environment so mail does not leave the app.
These credentials and this test image are for local review only.

## Portal control visibility regression

The initial DOM-only checks missed white text on transparent button backgrounds.
The portal templates used `bg-blue-700`, which is absent from this fork's Tailwind
palette. Custom ERB changes were also missing from Vite Ruby's asset watch paths.

- Replaced unsupported blue utilities with the existing `n-blue` design tokens,
  including sign-in, recovery, activation, submission, navigation and reply controls.
- Added a prominent Submit ticket action inside the main ticket-list content.
- Urgency now has exactly Low, Normal, High and Urgent, with Normal selected.
  Its single select has no `required` attribute because Rails otherwise inserts an
  empty option; the existing server-side enum validation remains in force.
- Added custom ERB paths to `config/vite.json` so utility changes rebuild assets.
- Browser assertions and screenshots verified the main and reply actions at
  desktop and 390px viewport widths, with no horizontal overflow. Primary button
  foreground/background contrast measured 4.91:1. Native urgency options were
  inspected in the live browser, rather than inferred from source templates.
- Regression specs now check the action within `main`, all four urgency values
  and its default, and the reply form submit control. Updated suite rerun pending.

## Reference ticket-page design

The user supplied a reference screenshot for the ticket detail/reply page.
The local page now uses a centered 672px column, compact heading/status, bordered
metadata summary (submitter, submitted/updated dates, product, urgency and source),
and author/date/role message headers with avatar initials and a left timeline rail.
Message panels have square white bordered surfaces; the reply panel retains a
visible blue Send reply action.

A dedicated Tailwind portal stylesheet excludes the old help-center/widget reset,
which otherwise removes the borders and spacing needed by this layout. No custom
CSS rules or new dependencies were added.

Raster attachments (PNG/JPEG/GIF/WebP) can render inside the message through the
same ownership-checked download controller using `preview=1`. Other file types
remain downloads; private messages/attachments remain inaccessible. Real image
loading was observed in the preview after the customer uploaded a screenshot.
Desktop and 390px layouts were inspected, including borders, timeline rail,
button visibility, English/Vietnamese metadata and absence of horizontal overflow.
Expanded metadata/inline-file authorization tests and lint are pending a fresh run.

## Later deployment prerequisites

Confirm iNet path proxying and public reachability, exact Workspace receiving
mailbox under `solidnsoft.vn`, company logo asset, and product catalog values.
These do not block local account development. Do not assume that outgoing SMTP
already provides incoming mail or that a From header alone proves ticket ownership.
