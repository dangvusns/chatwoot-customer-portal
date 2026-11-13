module Custom::Concerns::Account
  extend ActiveSupport::Concern

  included do
    has_many :custom_roles, dependent: :destroy
  end
end
