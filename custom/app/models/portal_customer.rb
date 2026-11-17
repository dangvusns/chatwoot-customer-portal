class PortalCustomer < ApplicationRecord
  SESSION_DURATION = 12.hours
  SUPPORTED_LOCALES = %w[en vi].freeze

  belongs_to :account
  belongs_to :contact

  has_secure_password validations: false, reset_token: false
  enum :status, { invited: 0, active: 1, suspended: 2 }

  generates_token_for :invitation, expires_in: 48.hours do
    [session_version, status]
  end
  generates_token_for :password_reset, expires_in: 30.minutes do
    [session_version, status]
  end

  validates :contact_id, uniqueness: true
  validates :locale, inclusion: { in: SUPPORTED_LOCALES }
  validates :password_digest, presence: true, if: :active?
  validates :password, length: { minimum: 12 }, confirmation: true, if: -> { password.present? }
  validate :password_within_bcrypt_limit
  validate :contact_belongs_to_account
  validate :contact_has_email
  validate :contact_has_name

  before_validation :set_defaults, on: :create

  def issue_access_link!(purpose)
    raise ArgumentError, 'Invalid access link purpose' unless %i[invitation password_reset].include?(purpose)
    raise ArgumentError, 'Customer is not eligible' unless eligible_for?(purpose)

    with_lock { update!(session_version: session_version + 1) }
    PortalCustomerMailer.access_link(self, purpose.to_s).deliver_later
  end

  def eligible_for?(purpose)
    purpose == :invitation ? invited? : active?
  end

  def change_access!(new_status)
    with_lock { update!(status: new_status, session_version: session_version + 1) }
  end

  private

  def set_defaults
    self.locale ||= 'en'
    self.status ||= :invited
    self.session_version ||= 0
  end

  def password_within_bcrypt_limit
    errors.add(:password, :too_long, count: 72) if password.present? && password.bytesize > 72
  end

  def contact_belongs_to_account
    errors.add(:contact, :invalid) if contact && contact.account_id != account_id
  end

  def contact_has_email
    errors.add(:contact, :invalid) if contact && contact.email.blank?
  end

  def contact_has_name
    errors.add(:contact, :invalid) if contact && contact.name.blank?
  end
end
