module Custom::Audit::AutomationRule
  extend ActiveSupport::Concern

  included do
    audited only: %i[name description event_name active conditions actions], associated_with: :account
  end
end
