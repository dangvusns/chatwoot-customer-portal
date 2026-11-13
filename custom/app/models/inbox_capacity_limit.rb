# == Schema Information
#
# Table name: inbox_capacity_limits
#
#  id                       :bigint           not null, primary key
#  conversation_limit       :integer          not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  agent_capacity_policy_id :bigint           not null
#  inbox_id                 :bigint           not null
#
class InboxCapacityLimit < ApplicationRecord
  belongs_to :agent_capacity_policy
  belongs_to :inbox

  validates :conversation_limit, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :inbox_id, uniqueness: { scope: :agent_capacity_policy_id }
  validate :inbox_belongs_to_policy_account

  private

  def inbox_belongs_to_policy_account
    return if inbox.blank? || agent_capacity_policy.blank? || inbox.account_id == agent_capacity_policy.account_id

    errors.add(:inbox, :invalid)
  end
end
