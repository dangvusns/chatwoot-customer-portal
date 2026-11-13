module Custom::Concerns::AccountUser
  extend ActiveSupport::Concern

  included do
    belongs_to :custom_role, optional: true
    belongs_to :agent_capacity_policy, optional: true

    validate :custom_role_belongs_to_account
    validate :capacity_policy_belongs_to_account
  end

  private

  def capacity_policy_belongs_to_account
    return if agent_capacity_policy.blank? || agent_capacity_policy.account_id == account_id

    errors.add(:agent_capacity_policy, :invalid)
  end

  def custom_role_belongs_to_account
    return if custom_role.blank? || custom_role.account_id == account_id

    errors.add(:custom_role, :invalid)
  end
end
