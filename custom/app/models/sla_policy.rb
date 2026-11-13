# == Schema Information
#
# Table name: sla_policies
#
#  id                            :bigint           not null, primary key
#  description                   :string
#  first_response_time_threshold :float
#  name                          :string           not null
#  next_response_time_threshold  :float
#  only_during_business_hours    :boolean          default(FALSE)
#  resolution_time_threshold     :float
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  account_id                    :bigint           not null
#
class SlaPolicy < ApplicationRecord
  THRESHOLD_ATTRIBUTES = %i[first_response_time_threshold next_response_time_threshold resolution_time_threshold].freeze

  belongs_to :account
  has_many :applied_slas, dependent: :destroy
  has_many :conversations, dependent: :nullify

  validates :name, presence: true
  validates(*THRESHOLD_ATTRIBUTES, numericality: { greater_than: 0 }, allow_nil: true)
end
