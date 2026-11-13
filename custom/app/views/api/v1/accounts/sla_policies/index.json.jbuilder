json.payload @sla_policies do |sla_policy|
  json.partial! 'api/v1/accounts/sla_policies/sla_policy', sla_policy: sla_policy
end
