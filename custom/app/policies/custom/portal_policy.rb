module Custom::PortalPolicy
  include Custom::CustomRolePermissions

  %i[update? edit? create? destroy? logo? remove_locale? send_instructions?].each do |action|
    define_method(action) { super() || custom_role_permission?('knowledge_base_manage') }
  end
end
