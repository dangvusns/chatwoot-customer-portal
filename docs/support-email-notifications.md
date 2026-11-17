# Support email notifications

## Confirmed requirements

- Adapt the customer's Dropbox reference to Solid&Soft Support, in English and Vietnamese.
- Mailbox: `support@solidnsoft.vn` on Google Workspace.
- Separate the public sender address from a ticket-specific Reply-To address.
- Customers can reply through the portal or email; email updates existing tickets only.
- Remind after 48 hours without a customer response; resolve 24 hours after the reminder if still unanswered.
- A customer response cancels the old countdown; a later public support reply begins a new waiting period.
- Private notes, activity messages and private attachments never enter customer emails.
- Subscription and knowledge-base features remain later work; templates must not link to unbuilt pages.

## Real email setup and agent identities

The main company domain is `solidnsoft.com`; its mail hosting supports POP3 but not
IMAP. Agents use their individual `.com` addresses to sign in to the Chatwoot agent
dashboard. This is their application identity and does not require Chatwoot to read
their personal mailboxes.

`support@solidnsoft.vn` is an alias of another Google Workspace account, not a
separate login or mailbox. Its owning account is `dangvu@solidnsoft.vn`, confirmed
by the user. Authenticate SMTP and IMAP using that owning account.
The user confirmed that its app password is already saved in the project-root
`.env`; do not duplicate it in documentation, source files, or diagnostic output.
The saved SMTP login differs from the alias, which is expected for this setup;
the saved default sender is not yet the support alias. Verify Gmail's Send mail as
configuration and actual delivered From/Reply-To headers before switching senders.

Customer-facing
outgoing notifications use this shared mailbox, and ticket-specific Reply-To aliases
under this mailbox receive customer responses. The message body may identify the
supporting agent by display name; the notification sender remains Solid&Soft Support.
Agent login addresses are not automatically used as the notification From address.

The expected flow after inbound integration is enabled:

1. An agent signs in as their `@solidnsoft.com` account and writes a public reply in Chatwoot.
2. The support notification goes from `support@solidnsoft.vn` to the customer.
3. The customer's email client replies to a ticket-tagged address under `support@solidnsoft.vn`.
4. The Google Workspace receiving integration validates and appends the reply to the same Chatwoot ticket.
5. Agents continue handling it in the dashboard, without connecting their individual POP3 mailboxes.

Agent invitation and password recovery emails still go to each agent's registered
`.com` mailbox. This design does not include agents replying from their own external
POP3 email clients; they reply inside the Chatwoot dashboard.

## Routing design

Example only; the exact token encoding is an implementation detail:

```
From: Solid&Soft Support <support@solidnsoft.vn>
Reply-To: Solid&Soft Support <support+ticket-<opaque-thread-token>@solidnsoft.vn>
```

The Reply-To token identifies the ticket thread, not an agent mailbox. Google Workspace
plus-addressing can deliver tagged variants to the base mailbox. Receiving tagged mail
and mapping it into a portal ticket are separate integration steps. Sender/token ownership,
account/inbox scope, suspended customer access, duplicate deliveries, auto-replies and
attachment handling must be verified before enabling real incoming mail.

Use Message-ID, In-Reply-To and References to preserve threading as well as the tagged
receiving address. Reject unmatched email as a premium-support ticket creation request.
Keep portal links authenticated and match customer email to the verified ticket owner.
Do not enable direct-reply instructions until the receiving pipeline is connected.

Because the owning mailbox may also contain unrelated mail, inbound integration must
select only support-addressed messages and must not import the owner's other email.
Delivery to a tagged support alias needs a real round-trip check; successful IMAP
authentication alone does not prove alias routing works. The user agreed to testing
and supplied `ledangvu96@gmail.com` as the test recipient, replacing the earlier
recipient `dangvu@solidnsoft.vn`. Use this separate Gmail mailbox for the
customer-to-support reply-routing test. The authentication account remains
`dangvu@solidnsoft.vn`.

## Notification content

- Confirmation: ticket number/subject, personalized greeting, acknowledgement and authenticated portal action.
- Support reply: ticket number/subject, public agent reply with author/date, bounded relevant public context,
  authenticated portal action, and same-address reply instructions once ingestion is enabled.
- Reminder: waiting-for-customer explanation, the 24-hour resolution deadline and response options.
- Resolution: status update and how to reopen by responding.
- All ticket notifications: branded sender and plain text only, with no HTML alternative or private content.
- On 2026-11-17 the user chose plain-text notifications for compatibility across email apps, replacing the earlier HTML design.

## Local verification sequence

1. Run `bash chatwoot-customer-portal/.codex/check-support-email.sh` from the outer
   Docker project directory. It uses the saved primary-account credentials, checks
   IMAP authentication without selecting or reading a mailbox, and submits one test
   email from the support alias to `ledangvu96@gmail.com`. It does not boot Rails,
   alter the running services, or access the application database.
2. Inspect the delivered message's From and Reply-To headers, then reply to it.
   Confirm that this tagged reply reaches `dangvu@solidnsoft.vn`. This proves provider
   delivery only; the diagnostic address is not linked to an application ticket.
3. Implement the ticket-specific receiving path, then send a notification for a local
   test ticket. Reply from the separate Gmail recipient and verify the original ticket
   receives exactly one public customer message without creating another ticket.
4. Verify unmatched senders/tokens, duplicate deliveries, private content, suspended
   customers, and unrelated owner-mailbox messages before enabling inbound processing.

The user executed the diagnostic helper on 2026-11-16. IMAP authentication passed
without reading messages, and Gmail SMTP accepted the test addressed to
`ledangvu96@gmail.com`. Its expected Reply-To was
`support+check-2f696d6ea79be751@solidnsoft.vn`. The user confirmed receiving the
test in Gmail and that replying delivered the response to `dangvu@solidnsoft.vn`.
This establishes tagged alias reply delivery; explicit inspection of the delivered
From header was not reported. Each invocation sends one test email.

## Current code constraints

`TicketMailer` now prepares plain-text received, agent reply, reminder and
resolved notifications in English and Vietnamese, using the portal customer's locale.
There is no HTML part or layout. Localized support copy provides the branding and
footer. Subjects include the ticket number and title.
Agent replies include one prior public incoming message, bounded to 2000 characters.
Private messages are rejected even on direct mailer calls; attachments remain behind
the authenticated portal instead of exposing Active Storage URLs.
The new gated routing path adds the support From alias and ticket-specific Reply-To
for active portal customers. Agent replies use Message-ID, In-Reply-To and References.
Guest notifications and disabled routing retain their previous behavior.
The ticket portal uses an API inbox.
The existing IMAP processor is separate from the Action Mailbox conversation finder;
changing only one does not connect Google Workspace ingestion. Reuse the existing mail
presentation, attachment and message handling where appropriate without allowing fallback
new-conversation creation for the premium-support mailbox.

ApplicationMailer provides account locale handling and catches some SMTP exceptions.
TicketMailer explicitly renders in customer locale and propagates SMTP exceptions to
the calling job. A failed reminder must not begin its closing countdown.

## Receiving implementation awaiting validation

- `TICKET_EMAIL_REPLIES_ENABLED=true` and `TICKET_SUPPORT_EMAIL=support@solidnsoft.vn`
  opt in. These variables have not been enabled on the running installation.
- The dedicated sync job runs once per minute when enabled, using the saved SMTP
  primary-account credentials for Gmail IMAP. It examines INBOX read-only and fetches
  only messages addressed To/Cc a ticket-tagged recipient; it does not mark mail read,
  delete mail, or create an Email channel that could import unrelated messages.
- Each poll searches at most 1000 UIDs and processes at most 20 matching messages,
  with a 50-second timeout and a 75 MB raw-message cap. A Redis cursor includes inbox,
  support alias and UIDVALIDITY. First activation considers the latest 1000 UIDs;
  older history needs a deliberate backfill. A failed batch retains its cursor.
- Import requires one known ticket token in the configured inbox, an active customer,
  a nonsuspended account and matching customer From. Reply-To never establishes identity.
  The random thread token is a bearer secret; matching From alone is not sender authentication.
- The ticket row lock and Message-ID check prevent duplicate imports into the same
  ticket. Existing message callbacks reopen resolved tickets on a customer reply.
- Automated replies, bounces, invalid IDs, oversized content/attachments and unmatched
  tokens are ignored. Existing attachment handling is reused within portal limits.
  Rejected messages remain in Gmail; the job logs aggregate outcome counts.
- New processor, mail-header and sync regression specs are prepared. Run
  `.codex/validate-email-routing.sh` using host Docker before real-ticket testing.

The first host run completed 193 examples with four failures in the importer, all
caused by calling `delete` on a nil trim result. Investigation found that the shared
MailPresenter did not recognize plain-text mail without an explicit Content-Type,
so the importer received an empty body. The parser now defaults missing Content-Type
to text/plain, and the importer handles the trimmer's nil result for genuinely empty
mail. Regressions cover missing MIME headers, empty bodies, attachment-only mail and
HTML-only mail. The validation helper now also runs the shared presenter specs and
reports lint results even if specs fail. The host rerun passed all 224 examples.
It reported 14 lint offenses: complexity, spec paths, verifying doubles and alignment.
The methods were split along persistence/search/thread-header responsibilities, specs
moved to their conventional paths, and doubles/alignment corrected. The refactoring
and lint corrections were followed by another host run: all 224 examples passed
again, with only a helper naming offense and one hash alignment offense remaining.
Those two are corrected; `.codex/lint-email-routing.sh` checks the final lint state
without rebuilding or rerunning the passing test suite. The user ran that check:
10 files inspected with no offenses.

The local round-trip helper is ready: run `.codex/test-ticket-email.sh send` from
the worktree (or prefix its path from the outer Docker directory). It requires the
existing isolated preview database/inbox, creates one test ticket for the confirmed
Gmail recipient and directly delivers only its checked notification. Other preview
mail remains disabled. Reply using the displayed text, then run the helper with
`fetch`; it imports tagged replies and asserts one imported response and no duplicate
after repeated polling. This manual helper does not enable polling in the running
production or preview server. On 2026-11-16, the user received the notification at
`ledangvu96@gmail.com` and replied with `Local reply check 1931e5f5`. The fetch helper
reported `{imported: 1}` and passed the single-import/repeated-poll assertions for
preview ticket #2 (conversation ID 3, account ID 3). Agent view:
`http://localhost:3101/app/accounts/3/conversations/2`. The helper initially printed
the database ID (3) instead of the conversation display ID (2), which opened an empty
agent view. The helper now uses display_id for dashboard links.

## Follow-up implementation awaiting validation

- `TICKET_FOLLOW_UP_ENABLED=true` opts in independently from email ingestion. It is
  not enabled on the running installation. Only new public User replies for active
  portal customers schedule a delayed reminder job, due at reply creation +48 hours.
- At execution, the job checks account/customer eligibility, inbox, status and the
  latest public message. Private notes and activities do not affect the countdown.
  Customer replies and newer public support replies invalidate earlier jobs.
- The existing distributed job mutex serializes reminder attempts per conversation.
  SMTP has explicit connection/read timeouts and a 40-second reminder delivery limit;
  no database row lock is held during delivery.
- Only successful reminder delivery records `support_follow_up` in conversation
  additional_attributes, with reply ID and reminder timestamp. Resolution is scheduled
  for 24 hours after that timestamp. SMTP failures propagate and record no deadline.
- A retried job with an existing successful reminder does not resend it and can
  reschedule resolution if enqueueing was interrupted. A process crash after SMTP
  accepts mail but before the timestamp commits can still cause a duplicate reminder
  on retry; SMTP delivery is not transactional with the database.
- Resolution rechecks the latest public reply, eligibility and deadline under the
  conversation row lock. Manually resolved or snoozed tickets are left alone. No
  global auto-resolution settings or bot-related pending status are changed.
- Existing resolved notifications and reply-to-reopen behavior are reused. Turning
  this feature off makes already queued follow-up jobs no-ops.
- Tests cover timing boundaries, cancellation, private notes, suspended customers,
  duplicate reminder execution, SMTP failure, job guards, localization and message privacy.
  Run `.codex/validate-email-notifications.sh` on the host; it sends no real emails.

The first notification check on 2026-11-17 ran 250 examples with one failure and
clean lint across nine files. The rejected-private-note case exposed an after-action
trying to add headers without a prepared conversation. The callback now skips that
case; direct private reminders and incoming-message rejection also have regressions.
Rerun `.codex/validate-email-notifications.sh --focused` to check mailers, routing,
follow-up behavior and lint without repeating the unaffected full suite.
The user ran that focused check on 2026-11-17: 28 examples passed, with no offenses
across nine linted files. The corrected rejection cases, multipart/localized templates
and follow-up timing/cancellation checks pass. Gmail visual review remains pending;
`.codex/test-ticket-email.sh send` now uses the new branded agent-reply template and
sends one message to the confirmed Gmail test recipient.

## References

- Zendesk incoming threading: https://support.zendesk.com/hc/en-us/articles/8396827889946-How-are-incoming-emails-threaded-to-tickets
- Google Workspace plus-addressing: https://support.google.com/a/users/answer/9282734?hl=en

Status: provider connectivity and tagged reply delivery confirmed. Receiving code and
header integration passed 224 automated examples, final lint and the real-ticket Gmail
round trip. Automatic polling remains disabled on the running installation. Branded
templates and opt-in follow-up automation passed focused runtime tests and lint in the
worktree before the format change. The plain-text update subsequently passed 29 focused
examples and clean lint across nine files on 2026-11-17. Gmail review of the updated
format remains pending. Preview SMTP delivery and scheduled workers
are not automatically enabled by these changes.

The requested plain-text change removes the five ticket HTML templates and the unused
Liquid-layout override. Regression coverage requires all four notification types to use
`text/plain`, with no multipart body or HTML part. Reply routing, English/Vietnamese
copy, authenticated attachment access and follow-up timing remain the same. Run
`.codex/validate-email-notifications.sh --focused` verified this change: 29 examples,
zero failures and nine linted files with no offenses. No additional test rerun is
needed unless the implementation changes.
