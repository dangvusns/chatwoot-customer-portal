class Tickets::ResolveUnansweredJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform(message_id)
    return unless Tickets::FollowUp.enabled?

    message = Message.find_by(id: message_id)
    Tickets::FollowUp.new(message).resolve if message
  end
end
