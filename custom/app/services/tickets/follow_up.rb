require 'timeout'

class Tickets::FollowUp
  REMIND_AFTER = 48.hours
  RESOLVE_AFTER = 24.hours
  STATE_KEY = 'support_follow_up'.freeze

  def self.enabled?
    ENV['TICKET_FOLLOW_UP_ENABLED'] == 'true'
  end

  def initialize(message)
    @message = message
    @conversation = message.conversation
  end

  def remind
    return unless eligible? && Time.current >= @message.created_at + REMIND_AFTER

    deliver_reminder unless reminded?
    return unless eligible? && reminded?

    Tickets::ResolveUnansweredJob.set(wait_until: resolution_time).perform_later(@message.id)
  end

  def resolve
    @conversation.with_lock do
      return unless eligible? && reminded? && Time.current >= resolution_time

      @conversation.resolved!
    end
  end

  private

  def deliver_reminder
    reminded_at = Time.current
    Timeout.timeout(40) do
      TicketMailer.with(account: @conversation.account).reminder(@message, reminded_at + RESOLVE_AFTER).deliver_now
    end
    @conversation.with_lock do
      return unless eligible?

      state = { 'reply_id' => @message.id, 'reminded_at' => reminded_at.utc.iso8601 }
      @conversation.update!(additional_attributes: @conversation.additional_attributes.merge(STATE_KEY => state))
    end
  end

  def eligible?
    return false unless self.class.enabled? && Tickets::Portal.ticket_inbox?(@conversation)

    @conversation.reload
    active_ticket? && latest_reply?
  end

  def active_ticket?
    return false if @conversation.resolved? || @conversation.snoozed? || @conversation.account.suspended?

    PortalCustomer.active.exists?(account_id: @conversation.account_id, contact_id: @conversation.contact_id)
  end

  def latest_reply?
    @message.reload
    return false unless @message.outgoing? && !@message.private? && @message.sender_type == 'User'

    @conversation.messages.where(private: false, message_type: %i[incoming outgoing]).reorder(created_at: :desc, id: :desc).pick(:id) == @message.id
  end

  def reminded?
    state = @conversation.additional_attributes[STATE_KEY]
    state.present? && state['reply_id'] == @message.id && state['reminded_at'].present?
  end

  def resolution_time
    Time.iso8601(@conversation.additional_attributes.fetch(STATE_KEY).fetch('reminded_at')) + RESOLVE_AFTER
  end
end
