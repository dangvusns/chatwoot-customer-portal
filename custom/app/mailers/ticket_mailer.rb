class TicketMailer < ApplicationMailer
  layout false
  after_action :set_reply_routing

  def received(conversation)
    prepare(conversation)
    notify(:received)
  end

  def agent_reply(message)
    return unless message.outgoing? && !message.private?

    prepare(message.conversation)
    @message = message
    @context = @conversation.messages.incoming.where(private: false, id: ...message.id).reorder(created_at: :desc, id: :desc).first
    notify(:agent_reply)
  end

  def reminder(message, deadline)
    return unless message.outgoing? && !message.private?

    prepare(message.conversation)
    @message = message
    @deadline = deadline
    notify(:reminder)
  end

  def resolved(conversation)
    prepare(conversation)
    notify(:resolved)
  end

  private

  def notify(kind)
    @kind = kind
    I18n.with_locale(@customer&.locale || @conversation.account.locale || I18n.default_locale) do
      subject = t("support_emails.#{kind}.subject", number: @conversation.display_id)
      subject = "#{subject} — #{@title.squish.truncate(120)}" if @title.present?
      mail(to: @contact.email, subject: subject, delivery_method_options: { open_timeout: 10, read_timeout: 20 }) do |format|
        format.text { render layout: false }
      end
    end
  end

  def handle_smtp_exceptions(error)
    raise error
  end

  def set_reply_routing
    return unless @conversation
    return unless Tickets::EmailRouting.enabled? && Tickets::Portal.ticket_inbox?(@conversation)
    return unless @customer&.active?

    address = Tickets::EmailRouting.address
    mail.from = "Solid&Soft Support <#{address}>"
    mail.reply_to = Tickets::EmailRouting.reply_to(@conversation)
    apply_thread_headers(address.split('@').last)
  end

  def apply_thread_headers(domain)
    mail.message_id = "portal/#{@conversation.uuid}/#{@message&.id || SecureRandom.uuid}@#{domain}"
    return unless @message

    mail.in_reply_to = @conversation.messages.incoming.where.not(source_id: nil).reorder(id: :desc).pick(:source_id)
    mail.references = mail.in_reply_to if mail.in_reply_to.present?
  end

  def prepare(conversation)
    @conversation = conversation
    @contact = conversation.contact
    @customer = PortalCustomer.find_by(account_id: conversation.account_id, contact_id: conversation.contact_id)
    @title = conversation.additional_attributes['mail_subject'].to_s
    @reply_by_email = Tickets::EmailRouting.enabled? && @customer&.active?
    @ticket_url = Tickets::Portal.url_for(conversation)
  end
end
