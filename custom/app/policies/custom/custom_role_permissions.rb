# Shared by policy overrides. Only agents with a custom role can match: administrators already pass the base checks.
module Custom::CustomRolePermissions
  private

  def custom_role_permission?(permission)
    return false unless account_user&.agent?

    account_user.custom_role&.permissions.to_a.include?(permission)
  end
end
