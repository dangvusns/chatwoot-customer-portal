json.array! @agent_capacity_policies do |agent_capacity_policy|
  json.partial! 'api/v1/accounts/agent_capacity_policies/agent_capacity_policy', agent_capacity_policy: agent_capacity_policy
end
