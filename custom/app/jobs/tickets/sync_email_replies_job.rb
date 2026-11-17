class Tickets::SyncEmailRepliesJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    results = Tickets::SyncEmailReplies.new.perform
    Rails.logger.info("[Portal email] #{results}") if results.present?
  end
end
