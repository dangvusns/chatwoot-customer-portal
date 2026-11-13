json.audit_logs @audit_logs do |audit_log|
  json.id audit_log.id
  json.user_id audit_log.user_id
  json.auditable_type audit_log.auditable_type
  json.auditable_id audit_log.auditable_id
  json.action audit_log.action
  json.audited_changes audit_log.audited_changes
  json.created_at audit_log.created_at.to_i
  json.location audit_log.location
  json.remote_address audit_log.remote_address if @show_ip_address
  account_user = @account_users_by_id[audit_log.auditable_id] if audit_log.auditable_type == 'AccountUser'
  json.auditable(account_user ? { user_id: account_user.user_id } : nil) if audit_log.auditable_type == 'AccountUser'
end
json.total_entries @audit_logs.total_count
json.per_page @per_page
json.current_page @audit_logs.current_page
