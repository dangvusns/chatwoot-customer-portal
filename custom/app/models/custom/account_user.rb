module Custom::AccountUser
  # Agents with a custom role get exactly that role's permissions. Administrators and plain agents are unchanged.
  def permissions
    return custom_role.permissions if agent? && custom_role.present?

    super
  end
end
