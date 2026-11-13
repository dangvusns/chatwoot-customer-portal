class Custom::Sla::ProcessAppliedSlasJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    AppliedSla.in_progress.includes(:sla_policy, conversation: :inbox).find_each do |applied_sla|
      Custom::Sla::Evaluator.new(applied_sla).perform
    rescue StandardError => e
      # One broken record must not stop the others from being checked
      ChatwootExceptionTracker.new(e, account: applied_sla.account).capture_exception
    end
  end
end
