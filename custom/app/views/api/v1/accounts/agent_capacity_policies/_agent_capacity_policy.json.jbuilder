json.id agent_capacity_policy.id
json.name agent_capacity_policy.name
json.description agent_capacity_policy.description
json.exclusion_rules agent_capacity_policy.exclusion_rules
json.assigned_agent_count agent_capacity_policy.account_users.count
json.users []
json.inbox_capacity_limits agent_capacity_policy.inbox_capacity_limits do |inbox_limit|
  json.partial! 'api/v1/accounts/agent_capacity_policies/inbox_limits/inbox_limit', inbox_limit: inbox_limit
end
json.created_at agent_capacity_policy.created_at.to_i
json.updated_at agent_capacity_policy.updated_at.to_i
