module Tickets::Portal
  ISSUE_TYPE_KEY = 'issue_type'.freeze
  PRODUCT_KEY = 'support_product'.freeze
  SOURCE = 'support_portal'.freeze
  MAX_ATTACHMENTS = 5
  MAX_ATTACHMENT_SIZE = 10.megabytes
  MAX_CONTENT_LENGTH = 10_000
  PREVIEW_IMAGE_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze

  module_function

  # Strict read for the portal pages: a missing setting must fail visibly there.
  def inbox
    Inbox.find(ENV.fetch('TICKET_PORTAL_INBOX_ID'))
  end

  # Lenient read for event listeners, which run for every inbox. A missing setting must not break them.
  def ticket_inbox?(conversation)
    configured_id = ENV.fetch('TICKET_PORTAL_INBOX_ID', nil)
    configured_id.present? && conversation.inbox_id == configured_id.to_i
  end

  def issue_types
    choices(ISSUE_TYPE_KEY)
  end

  def products
    choices(PRODUCT_KEY)
  end

  def choices(key)
    definition = CustomAttributeDefinition.conversation_attribute.find_by(account_id: inbox.account_id, attribute_key: key)
    definition&.attribute_values || []
  end

  def url_for(conversation)
    Rails.application.routes.url_helpers.premium_support_ticket_url(conversation.display_id, host: ENV.fetch('FRONTEND_URL'))
  end

  def post_customer_message(conversation, content:, attachments:)
    params = ActionController::Parameters.new(content: content, message_type: 'incoming', attachments: attachments)
    Messages::MessageBuilder.new(nil, conversation, params).perform
  end

  def previewable_image?(attachment)
    attachment.file.attached? && PREVIEW_IMAGE_TYPES.include?(attachment.file.blob.content_type)
  end
end
