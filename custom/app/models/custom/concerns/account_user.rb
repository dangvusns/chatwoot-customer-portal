module Custom::Concerns::AccountUser
  extend ActiveSupport::Concern

  included do
    belongs_to :custom_role, optional: true

    validate :custom_role_belongs_to_account
  end

  private

  def custom_role_belongs_to_account
    return if custom_role.blank? || custom_role.account_id == account_id

    errors.add(:custom_role, :invalid)
  end
end
