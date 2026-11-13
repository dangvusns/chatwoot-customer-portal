module Custom::ContactPolicy
  include Custom::CustomRolePermissions

  %i[import? export? destroy?].each do |action|
    define_method(action) { super() || custom_role_permission?('contact_manage') }
  end
end
