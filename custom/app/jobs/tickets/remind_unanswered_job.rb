class Tickets::RemindUnansweredJob < MutexApplicationJob
  queue_as :scheduled_jobs
  retry_on_lock_conflict wait: 1.minute, attempts: 5

  def perform(message_id)
    return unless Tickets::FollowUp.enabled?

    message = Message.find_by(id: message_id)
    return unless message

    with_lock("portal-reminder:#{message.conversation_id}", 120) do
      Tickets::FollowUp.new(message).remind
    end
  end
end
