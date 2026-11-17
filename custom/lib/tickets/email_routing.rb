module Tickets::EmailRouting
  module_function

  def enabled?
    ENV['TICKET_EMAIL_REPLIES_ENABLED'] == 'true'
  end

  def address
    Mail::Address.new(ENV.fetch('TICKET_SUPPORT_EMAIL')).address.downcase
  end

  def recipient_prefix
    "#{address.split('@').first}+ticket-"
  end

  def reply_to(conversation)
    local, domain = address.split('@')
    "#{local}+ticket-#{conversation.uuid}@#{domain}"
  end

  def conversation_for(mail)
    domain = address.split('@').last
    pattern = /\A#{Regexp.escape(recipient_prefix)}([a-f0-9-]{36})@#{Regexp.escape(domain)}\z/i
    tokens = (Array(mail.to) + Array(mail.cc)).filter_map { |recipient| pattern.match(recipient)&.[](1)&.downcase }.uniq
    return unless tokens.one?

    Tickets::Portal.inbox.conversations.find_by(uuid: tokens.first)
  end
end
