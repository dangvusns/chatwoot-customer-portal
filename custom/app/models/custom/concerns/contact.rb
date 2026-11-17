module Custom::Concerns::Contact
  extend ActiveSupport::Concern

  included do
    has_one :portal_customer, dependent: :destroy
    after_update_commit :revoke_portal_identity_after_email_change, if: :saved_change_to_email?
  end

  private

  def revoke_portal_identity_after_email_change
    customer = portal_customer
    return unless customer

    customer.with_lock do
      customer.update!(status: :suspended, password_digest: nil, session_version: customer.session_version + 1)
    end
  end
end
