module Custom::Audit::AccountUser
  extend ActiveSupport::Concern

  included do
    audited only: %i[user_id role availability custom_role_id], associated_with: :account
  end
end
