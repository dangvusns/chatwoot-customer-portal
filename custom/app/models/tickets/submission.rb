class Tickets::Submission
  include ActiveModel::Model
  include ActiveModel::Attributes
  include Tickets::AttachmentValidation

  attribute :issue_type, :string
  attribute :message, :string
  attribute :subject, :string
  attribute :product, :string
  attribute :priority, :string, default: 'medium'

  attr_reader :conversation
  attr_accessor :portal_customer

  validates :message, presence: true, length: { maximum: Tickets::Portal::MAX_CONTENT_LENGTH }
  validate :issue_type_is_allowed
  validates :subject, presence: true, length: { maximum: 255 }
  validates :product, inclusion: { in: ->(_) { Tickets::Portal.products } }
  validates :priority, inclusion: { in: Conversation.priorities.keys }
  validate :customer_can_submit

  def save
    return false unless valid?

    @conversation = ActiveRecord::Base.transaction { create_conversation_with_message }
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.record.errors.full_messages.join(', '))
    false
  end

  private

  def issue_type_is_allowed
    allowed_types = Tickets::Portal.issue_types
    return if allowed_types.empty? || allowed_types.include?(issue_type)

    errors.add(:issue_type, :inclusion)
  end

  def create_conversation_with_message
    inbox = Tickets::Portal.inbox
    contact_inbox = build_contact_inbox(inbox)
    conversation = Conversation.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: contact_inbox.contact_id,
      contact_inbox_id: contact_inbox.id,
      priority: priority,
      custom_attributes: { Tickets::Portal::ISSUE_TYPE_KEY => issue_type, Tickets::Portal::PRODUCT_KEY => product },
      additional_attributes: { source: Tickets::Portal::SOURCE, mail_subject: subject }
    )
    Tickets::Portal.post_customer_message(conversation, content: message, attachments: attachments)
    conversation
  end

  def build_contact_inbox(inbox)
    portal_customer.contact.contact_inboxes.find_by(inbox: inbox) ||
      ContactInboxBuilder.new(contact: portal_customer.contact, inbox: inbox, source_id: nil).perform
  end

  def customer_can_submit
    return if portal_customer&.active? && portal_customer.account_id == Tickets::Portal.inbox.account_id

    errors.add(:base, :invalid)
  end
end
