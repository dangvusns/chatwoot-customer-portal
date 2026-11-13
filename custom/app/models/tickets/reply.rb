class Tickets::Reply
  include ActiveModel::Model
  include ActiveModel::Attributes
  include Tickets::AttachmentValidation

  attribute :content, :string

  validates :content, presence: true, length: { maximum: Tickets::Portal::MAX_CONTENT_LENGTH }

  def save(conversation)
    return false unless valid?

    Tickets::Portal.post_customer_message(conversation, content: content, attachments: attachments)
    true
  end
end
