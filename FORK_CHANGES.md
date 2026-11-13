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

## Decisions
- `ChatwootApp.enterprise?` stays false (true would activate gated routes for calls, SAML, captain).
