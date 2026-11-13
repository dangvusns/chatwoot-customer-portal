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
