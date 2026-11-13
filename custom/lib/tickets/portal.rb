module Tickets::Portal
  TOKEN_PURPOSE = :ticket_portal
  TOKEN_TTL = 180.days
  ISSUE_TYPE_KEY = 'issue_type'.freeze
  SOURCE = 'support_portal'.freeze
  MAX_ATTACHMENTS = 5
  MAX_ATTACHMENT_SIZE = 10.megabytes
  MAX_CONTENT_LENGTH = 10_000

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
    definition = CustomAttributeDefinition.conversation_attribute.find_by(account_id: inbox.account_id, attribute_key: ISSUE_TYPE_KEY)
    definition&.attribute_values || []
  end

  def token_for(conversation)
    conversation.signed_id(purpose: TOKEN_PURPOSE, expires_in: TOKEN_TTL)
  end

  def find_conversation!(token)
    # find_signed returns nil for a tampered, expired or wrong-purpose token (find_signed! raises InvalidSignature)
    conversation = Conversation.find_signed(token, purpose: TOKEN_PURPOSE)
    raise ActiveRecord::RecordNotFound unless conversation && ticket_inbox?(conversation)

    conversation
  end

  def url_for(conversation)
    Rails.application.routes.url_helpers.ticket_url(token_for(conversation), host: ENV.fetch('FRONTEND_URL'))
  end

  def post_customer_message(conversation, content:, attachments:)
    params = ActionController::Parameters.new(content: content, message_type: 'incoming', attachments: attachments)
    Messages::MessageBuilder.new(nil, conversation, params).perform
  end
end
