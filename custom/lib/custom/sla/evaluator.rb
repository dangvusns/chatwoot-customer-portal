# Checks one in-progress SLA: records deadlines that were missed and closes the SLA once the conversation is resolved.
# Run every minute by Custom::Sla::ProcessAppliedSlasJob, so a miss is recorded within about a minute of the deadline.
class Custom::Sla::Evaluator
  delegate :conversation, :sla_policy, to: :applied_sla

  def initialize(applied_sla, now: Time.current)
    @applied_sla = applied_sla
    @now = now
  end

  def perform
    record_missed_deadlines
    finalize if conversation.resolved?
  end

  private

  attr_reader :applied_sla, :now

  def record_missed_deadlines
    record_miss(:frt) if first_response_missed?
    record_miss(:nrt) if next_response_missed?
    record_miss(:rt) if resolution_missed?
    applied_sla.active_with_misses! if applied_sla.active? && applied_sla.sla_events.exists?
  end

  def first_response_missed?
    due_at = applied_sla.first_response_due_at
    return false if due_at.nil? || applied_sla.sla_events.frt.exists?

    (conversation.first_reply_created_at || now).to_i > due_at
  end

  # One miss per waiting period: the clock restarts each time the customer writes again
  def next_response_missed?
    due_at = applied_sla.next_response_due_at
    return false if due_at.nil? || applied_sla.sla_events.nrt.exists?(created_at: conversation.waiting_since..)

    now.to_i > due_at
  end

  def resolution_missed?
    due_at = applied_sla.resolution_due_at
    return false if due_at.nil? || applied_sla.sla_events.rt.exists?

    now.to_i > due_at
  end

  def record_miss(event_type)
    applied_sla.sla_events.create!(
      event_type: event_type, account_id: applied_sla.account_id, conversation: conversation,
      inbox_id: conversation.inbox_id, sla_policy: sla_policy, created_at: now
    )
  end

  def finalize
    applied_sla.update!(sla_status: applied_sla.sla_events.exists? ? :missed : :hit, completed_at: now)
  end
end
