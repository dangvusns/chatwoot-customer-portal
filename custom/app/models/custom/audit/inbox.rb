module Custom::Audit::Inbox
  extend ActiveSupport::Concern

  included do
    audited only: %i[name enable_auto_assignment lock_to_single_conversation working_hours_enabled greeting_enabled greeting_message],
            associated_with: :account
  end
end
