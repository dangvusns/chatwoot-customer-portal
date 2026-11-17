class TicketNotificationListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event).first
    return unless customer_visible_agent_message?(message)

    conversation = message.conversation
    TicketMailer.with(account: conversation.account).agent_reply(message).deliver_later
    schedule_follow_up(message)
  end

  def conversation_status_changed(event)
    conversation = extract_conversation_and_account(event).first
    return unless notifiable_conversation?(conversation) && conversation.resolved?

    TicketMailer.with(account: conversation.account).resolved(conversation).deliver_later
  end

  private

  def schedule_follow_up(message)
    return unless Tickets::FollowUp.enabled? && message.sender_type == 'User'

    Tickets::RemindUnansweredJob.set(wait_until: message.created_at + Tickets::FollowUp::REMIND_AFTER).perform_later(message.id)
  end

  def customer_visible_agent_message?(message)
    message.outgoing? && !message.private? && notifiable_conversation?(message.conversation)
  end

  def notifiable_conversation?(conversation)
    return false unless Tickets::Portal.ticket_inbox?(conversation) && conversation.contact.email.present?

    PortalCustomer.active.exists?(account_id: conversation.account_id, contact_id: conversation.contact_id)
  end
end
