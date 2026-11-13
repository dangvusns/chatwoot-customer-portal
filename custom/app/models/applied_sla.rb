# == Schema Information
#
# Table name: applied_slas
#
#  id              :bigint           not null, primary key
#  completed_at    :datetime
#  sla_status      :integer          default("active")
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  conversation_id :bigint           not null
#  sla_policy_id   :bigint           not null
#
class AppliedSla < ApplicationRecord
  belongs_to :account
  belongs_to :sla_policy
  belongs_to :conversation
  has_many :sla_events, dependent: :destroy

  enum :sla_status, { active: 0, hit: 1, missed: 2, active_with_misses: 3 }

  scope :in_progress, -> { where(sla_status: %i[active active_with_misses]) }

  # Deadlines as unix timestamps, or nil when the policy has no such threshold. The next response clock
  # only runs while the conversation is waiting for an agent.
  def first_response_due_at
    due_at(conversation.created_at, sla_policy.first_response_time_threshold)
  end

  def next_response_due_at
    return if conversation.waiting_since.blank?

    due_at(conversation.waiting_since, sla_policy.next_response_time_threshold)
  end

  def resolution_due_at
    due_at(conversation.created_at, sla_policy.resolution_time_threshold)
  end

  private

  def due_at(start_time, threshold)
    return if threshold.blank?

    Custom::Sla::DueTime.after(start_time, threshold, inbox: conversation.inbox, business_hours_only: sla_policy.only_during_business_hours).to_i
  end
end
