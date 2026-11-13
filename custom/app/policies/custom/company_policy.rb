module Custom::CompanyPolicy
  include Custom::CustomRolePermissions

  def destroy?
    super || custom_role_permission?('contact_manage')
  end
end
