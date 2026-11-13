module Custom::Audit::Conversation
  extend ActiveSupport::Concern

  included do
    # Only deletions are audited. display_id is kept because the row itself is gone afterwards.
    audited only: %i[display_id], on: [:destroy], associated_with: :account
  end
end
