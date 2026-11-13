module Custom::Audit::InboxMember
  extend ActiveSupport::Concern

  included do
    delegate :account, to: :inbox

    audited only: %i[user_id inbox_id], on: [:create, :destroy], associated_with: :account
  end
end
