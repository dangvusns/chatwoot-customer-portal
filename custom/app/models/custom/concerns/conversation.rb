module Custom::Concerns::Conversation
  extend ActiveSupport::Concern

  included do
    belongs_to :sla_policy, optional: true
    has_one :applied_sla, dependent: :destroy
    has_many :sla_events, dependent: :destroy

    after_save_commit :sync_applied_sla, if: :saved_change_to_sla_policy_id?
  end

  private

  # Changing or removing the policy restarts tracking: the old record (and its events) is replaced
  def sync_applied_sla
    applied_sla&.destroy!
    return if sla_policy.blank?

    AppliedSla.create!(account_id: account_id, sla_policy: sla_policy, conversation: self)
  end
end
