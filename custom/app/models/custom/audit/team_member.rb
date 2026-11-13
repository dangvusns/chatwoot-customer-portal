module Custom::Audit::TeamMember
  extend ActiveSupport::Concern

  included do
    delegate :account, to: :team

    audited only: %i[user_id team_id], on: [:create, :destroy], associated_with: :account
  end
end
