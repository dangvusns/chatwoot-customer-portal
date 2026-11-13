json.array! @custom_roles do |custom_role|
  json.partial! 'api/v1/accounts/custom_roles/custom_role', custom_role: custom_role
end
