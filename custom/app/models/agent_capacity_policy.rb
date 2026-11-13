# == Schema Information
#
# Table name: agent_capacity_policies
#
#  id              :bigint           not null, primary key
#  description     :text
#  exclusion_rules :jsonb            not null
#  name            :string(255)      not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#
class AgentCapacityPolicy < ApplicationRecord
  belongs_to :account
  has_many :inbox_capacity_limits, dependent: :destroy
  has_many :account_users, dependent: :nullify

  validates :name, presence: true, length: { maximum: 255 }
  validate :exclusion_rules_are_valid

  private

  def exclusion_rules_are_valid
    labels = exclusion_rules['excluded_labels']
    hours = exclusion_rules['exclude_older_than_hours']

    errors.add(:exclusion_rules, :invalid) if labels.present? && !(labels.is_a?(Array) && labels.all?(String))
    errors.add(:exclusion_rules, :invalid) if hours.present? && !(hours.is_a?(Integer) && hours.positive?)
  end
end
