module Custom::Audit::Team
  extend ActiveSupport::Concern

  included do
    audited only: %i[name description allow_auto_assign], associated_with: :account
  end
end
