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
