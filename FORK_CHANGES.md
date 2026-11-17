# Fork changes vs upstream Chatwoot (v4.19.1)

Company fork. Keep this list current: it is the only place merge conflicts should appear
when running `git merge upstream/<tag>`.

## Licensing
- `enterprise/` and `spec/enterprise/` are removed (proprietary license). Never restore them.
- Replacement features are written clean-room under `custom/` as `Custom::*` modules
  (found by `prepend_mod_with` / `include_mod_with`). Do not copy or paraphrase upstream enterprise code.

## Edits to upstream files
| File | Change |
|------|--------|
| `config/application.rb` | Add `custom/lib`, `custom/app/**` autoload paths and `custom/app/views` view path |
| `config/initializers/01_inject_enterprise_edition_module.rb` | `next unless extension_namespace` (upstream crashes when the `Enterprise`/`Custom` namespace is undefined) |
| `config/initializers/audited.rb` | Audit class `Enterprise::AuditLog` -> `Custom::AuditLog` |
| `config/features.yml` | `audit_logs`, `sla`, `custom_roles`, `advanced_assignment` default `enabled: true` (affects newly created accounts only) |
| `app/javascript/dashboard/routes/dashboard/settings/auditlogs/audit.routes.js` | Add `COMMUNITY` to `installationTypes` |
| `app/javascript/dashboard/routes/dashboard/settings/customRoles/customRole.routes.js` | Add `COMMUNITY` to `installationTypes` |
| `app/javascript/dashboard/routes/dashboard/settings/sla/sla.routes.js` | Add `COMMUNITY` to `installationTypes` |

| `app/views/api/v1/conversations/partials/_conversation.json.jbuilder` | render the custom SLA partial (one added line) |
| `config/schedule.yml` | add the `process_applied_slas_job` entry |
| `app/views/api/v1/models/_agent.json.jbuilder` | `custom_role_id` always emitted (was enterprise-only) |
| `app/views/api/v1/models/_user.json.jbuilder` | emit `custom_role_id` per account |

## Custom roles (Phase 3)
- `custom/app/models/custom_role.rb` plus `Custom::Concerns::Account`, `Custom::Concerns::AccountUser`, `Custom::AccountUser` (permissions override)
- `Api::V1::Accounts::CustomRolesController` (admin only) and `Custom::Api::V1::Accounts::AgentsController` (assign/clear `custom_role_id`)
- Policy overrides under `custom/app/policies/custom/` and `Custom::Conversations::PermissionFilterService`
- Semantics (inferred, not copied): conversation_manage = all in agent inboxes; conversation_unassigned_manage = unassigned or own; conversation_participating_manage = own or participating; contact_manage / report_manage / knowledge_base_manage open the matching admin-only actions.
- Not covered: controllers that check `administrator?` directly (e.g. some report endpoints) and the public help center controller hooks.

## Audit logs (Phase 5)
- `Custom::AuditLog` (subclass of `Audited::Audit` on the `audits` table) and `Custom::Audit::*` concerns for Account, AccountUser, Inbox, InboxMember, Team, TeamMember, Webhook, AutomationRule, Macro, Conversation (destroy only).
- `Api::V1::Accounts::AuditLogsController#show` (admin only; filters `types`, `q`, `since`/`until` unix seconds, `sort`, paging) and `AuditLogPolicy`.
- `config/initializers/audit_sign_in.rb` records sign-ins through a Warden hook (one row per account).
- Not covered: sign-out (token sign-out does not go through Warden), Message deletion, AgentBot, IP geolocation (`city`/`country` stay empty).

## Capacity-based assignment (Phase 4)
- Models `AgentCapacityPolicy`, `InboxCapacityLimit`; associations via `Custom::Concerns::{Account,AccountUser,Inbox}`.
- Admin-only API: `agent_capacity_policies` CRUD plus nested `users` and `inbox_limits` (`AgentCapacityPolicyPolicy`).
- `Custom::AgentCapacity` decides eligibility; wired in through `Custom::Inbox#member_ids_with_assignment_capacity` (legacy auto-assignment) and `Custom::AutoAssignment::AssignmentService#filter_agents_by_rate_limit` (assignment v2).
- Rule: an agent whose policy has a limit for the inbox is skipped once their open conversations there reach it (excluded labels and conversations idle longer than `exclude_older_than_hours` do not count). No policy or no limit = unlimited.
- Not covered: the per-agent `capacity` value the UI sends (no column exists, ignored) and the `balanced` assignment order (the enum stays round_robin only).

## SLA policies (Phase 2)
- Models `SlaPolicy`, `AppliedSla`, `SlaEvent`; `Custom::Concerns::Conversation` adds `sla_policy`, `applied_sla`, `sla_events` and restarts tracking whenever `sla_policy_id` changes; `Custom::ActionService#add_sla` is the automation action.
- API: `sla_policies` CRUD (read open to agents, write admin only); `applied_slas` list / metrics / CSV for the SLA report (same access as other reports: administrators and custom roles with `report_manage`).
- `Custom::Sla::ProcessAppliedSlasJob` runs every minute (entry in `config/schedule.yml`), using `Custom::Sla::Evaluator` to record first response (frt), next response (nrt) and resolution (rt) misses and to close the SLA as hit or missed once the conversation is resolved. `Custom::Sla::DueTime` counts business hours from the inbox working hours when a policy asks for it.
- Upstream edit: `app/views/api/v1/conversations/partials/_conversation.json.jbuilder` adds `applied_sla` and `sla_events` through `custom/api/v1/conversations/partials/_sla`.
- Semantics (inferred): next-response clock runs from `waiting_since`; a late first reply counts as a miss; resolution is judged when the job runs (up to a minute of delay).
- Not covered: SLA missed notifications (the notification types exist but nothing creates them), pausing the clock while snoozed or pending, and N+1 queries when listing many conversations with SLAs.

## New files in upstream folders (no merge conflicts expected)
- `config/routes/tickets.rb` (loaded by `draw :tickets` in `config/routes.rb`, which is one added upstream line)
- `config/locales/tickets.en.yml`
- `config/initializers/rack_attack_tickets.rb`
- `lib/tasks/tickets.rake` (`rails tickets:setup` creates the portal inbox and issue types)
- `spec/custom/**`

## Ticket portal (Phase 1)
- Needs env `TICKET_PORTAL_INBOX_ID` (printed by `rails tickets:setup`) and `FRONTEND_URL`; SMTP for emails.
- Pages: `/support` (form), `/tickets/:token` (ticket page + reply). Links use signed ids valid 180 days.

## Decisions
- `ChatwootApp.enterprise?` stays false (true would activate gated routes for calls, SAML, captain).

## Customer portal account foundation (in progress)
- Isolated development at `/premium-support`; administrator-only `portal_customers` API and Settings page.
- Dedicated `PortalCustomer` identity linked to an existing account/contact, expiring activation/reset links, versioned sessions and suspension.
- Rails-generated `CreatePortalCustomers` migration; unique contact identity index.
- Upstream integration edits: settings route registration, sidebar entry, Tailwind custom-view scan path, and ticket-route/throttle additions.
- English/Vietnamese account screens and invitation/reset emails. Local isolated test container configuration.
- Full scope, remaining milestones and acceptance checks: `docs/customer-portal.md`.
- This foundation does not yet replace guest ticket routes, implement the full ticket workflow, or ingest email replies.

## Authenticated customer ticket submission (in progress)
- Submit-ticket button/form, customer-bound identity, full-catalog product selection, subject and native urgency.
- Own-ticket detail/history, replies, close/reopen and authenticated public attachment streaming.
- Reuses the existing `Tickets::Submission`, `Tickets::Reply`, conversation/message builders and Custom Attributes product catalog.
- Registered customers' notification links point to authenticated ticket pages; legacy guest routes remain until migration.
- Regression suite: `spec/custom/requests/premium_support_tickets_spec.rb`; all 165 custom examples pass; Ruby lint (23 files) and frontend lint are clean.

## Portal control visibility fixes
- Use supported Tailwind `n-blue` tokens for all customer primary actions; add Submit ticket within the main list content.
- Remove Rails' automatically inserted empty urgency option while preserving enum validation.
- Watch custom ERB templates in `config/vite.json` so their Tailwind classes rebuild.
- Verified actual button colors/contrast and screenshots at desktop and 390px widths; regression assertions added.

## Reference ticket-page layout
- Centered compact ticket summary, author/date timeline, bordered messages and reply form based on the customer-provided reference.
- Dedicated customer portal Tailwind stylesheet avoids the legacy help-center reset.
- Ownership-checked inline previews for raster images; other attachments remain downloads.
- Desktop/390px and English/Vietnamese browser checks completed; expanded automated checks pending.

## Portal email reply routing (validated locally; live activation pending)
- Opt-in support alias and ticket-specific Reply-To headers for active portal customers.
- Dedicated read-only Gmail polling for tagged replies, scoped to the portal inbox and customer, with bounded batches and Message-ID deduplication.
- Reuses existing incoming-message callbacks and attachments; does not create tickets from unmatched mail.
- Validated with 224 passing examples and clean lint. A Gmail reply was imported exactly once into preview ticket #2; repeated polling did not duplicate it.
- Automatic polling is not enabled on the running installation.

## Support notifications and follow-up (local runtime checks passed)
- Plain-text English/Vietnamese confirmation, reply, reminder and resolution emails use the customer locale. The user requested removal of HTML alternatives for email-app compatibility.
- Public reply context is bounded; private notes and direct blob links are excluded.
- Opt-in delayed reminders at 48 hours and resolution 24 hours after successful reminder delivery, with cancellation checks for newer public messages.
- Follow-up does not change global resolution settings and remains disabled until local validation and worker activation.
- Focused notification/follow-up checks passed: 28 examples and clean lint across nine files; Gmail visual review and worker activation remain pending.
- The later plain-text-only change passed 29 focused examples and clean lint across nine files. Automatic processing remains disabled.
