class TicketMailer < ApplicationMailer
  layout false

  def received(conversation)
    prepare(conversation)
    mail(to: @contact.email, subject: t('tickets.mailer.received.subject', number: @conversation.display_id))
  end

  def agent_reply(message)
    prepare(message.conversation)
    @message = message
    mail(to: @contact.email, subject: t('tickets.mailer.agent_reply.subject', number: @conversation.display_id))
  end

  def resolved(conversation)
    prepare(conversation)
    mail(to: @contact.email, subject: t('tickets.mailer.resolved.subject', number: @conversation.display_id))
  end

  private

  def prepare(conversation)
    @conversation = conversation
    @contact = conversation.contact
    @ticket_url = Tickets::Portal.url_for(conversation)
  end
end
