module Custom::ReportPolicy
  include Custom::CustomRolePermissions

  def view?
    super || custom_role_permission?('report_manage')
  end
end
