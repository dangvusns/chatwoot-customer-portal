# == Schema Information
#
# Table name: sla_events
#
#  id              :bigint           not null, primary key
#  event_type      :integer
#  meta            :jsonb
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  applied_sla_id  :bigint           not null
#  conversation_id :bigint           not null
#  inbox_id        :bigint           not null
#  sla_policy_id   :bigint           not null
#
class SlaEvent < ApplicationRecord
  belongs_to :account
  belongs_to :applied_sla
  belongs_to :conversation
  belongs_to :inbox
  belongs_to :sla_policy

  enum :event_type, { frt: 0, nrt: 1, rt: 2 }

  validates :event_type, presence: true
end
