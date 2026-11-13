module Custom::Concerns::Account
  extend ActiveSupport::Concern

  included do
    has_many :custom_roles, dependent: :destroy
    has_many :agent_capacity_policies, dependent: :destroy
    has_many :sla_policies, dependent: :destroy
  end
end
