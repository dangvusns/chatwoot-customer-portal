class Tickets::Submission
  include ActiveModel::Model
  include ActiveModel::Attributes
  include Tickets::AttachmentValidation

  attribute :name, :string
  attribute :email, :string
  attribute :issue_type, :string
  attribute :message, :string
  # Honeypot: hidden from people, filled in by bots
  attribute :website, :string

  attr_reader :conversation

  validates :name, presence: true, length: { maximum: 255 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :message, presence: true, length: { maximum: Tickets::Portal::MAX_CONTENT_LENGTH }
  validate :issue_type_is_allowed

  def spam?
    website.present?
  end

  def save
    return false unless valid?

    @conversation = ActiveRecord::Base.transaction { create_conversation_with_message }
    true
  end

  private

  def issue_type_is_allowed
    allowed_types = Tickets::Portal.issue_types
    return if allowed_types.empty? || allowed_types.include?(issue_type)

    errors.add(:issue_type, :inclusion)
  end

  def create_conversation_with_message
    inbox = Tickets::Portal.inbox
    contact_inbox = ContactInboxWithContactBuilder.new(inbox: inbox, contact_attributes: { name: name, email: email }).perform
    conversation = Conversation.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: contact_inbox.contact_id,
      contact_inbox_id: contact_inbox.id,
      custom_attributes: issue_type.present? ? { Tickets::Portal::ISSUE_TYPE_KEY => issue_type } : {},
      additional_attributes: { source: Tickets::Portal::SOURCE }
    )
    Tickets::Portal.post_customer_message(conversation, content: message, attachments: attachments)
    conversation
  end
end
