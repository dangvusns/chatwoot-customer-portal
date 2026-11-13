require 'rails_helper'

RSpec.describe Custom::Sla::Evaluator do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:policy) do
    create(:sla_policy, account: account, first_response_time_threshold: 600, next_response_time_threshold: 300, resolution_time_threshold: 3600)
  end
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:applied_sla) { conversation.reload.applied_sla }
  let(:start) { conversation.created_at }

  before do
    conversation.update_columns(waiting_since: nil, first_reply_created_at: nil) # rubocop:disable Rails/SkipsModelValidations
    conversation.update!(sla_policy: policy)
  end

  def evaluate(at:)
    described_class.new(applied_sla.reload, now: at).perform
  end

  it 'records nothing before any deadline' do
    evaluate(at: start + 4.minutes)

    expect(applied_sla.sla_events).to be_empty
    expect(applied_sla).to be_active
  end

  it 'records a first response miss once, and flags the SLA' do
    evaluate(at: start + 11.minutes)
    evaluate(at: start + 12.minutes)

    expect(applied_sla.sla_events.frt.count).to eq(1)
    expect(applied_sla).to be_active_with_misses
  end

  it 'accepts a first reply inside the deadline' do
    conversation.update_columns(first_reply_created_at: start + 2.minutes) # rubocop:disable Rails/SkipsModelValidations

    evaluate(at: start + 20.minutes)

    expect(applied_sla.sla_events.frt).to be_empty
  end

  it 'counts a late first reply as a miss even if the job did not run in between' do
    conversation.update_columns(first_reply_created_at: start + 15.minutes) # rubocop:disable Rails/SkipsModelValidations

    evaluate(at: start + 20.minutes)

    expect(applied_sla.sla_events.frt.count).to eq(1)
  end

  it 'records a resolution miss' do
    conversation.update_columns(first_reply_created_at: start + 1.minute) # rubocop:disable Rails/SkipsModelValidations

    evaluate(at: start + 61.minutes)

    expect(applied_sla.sla_events.rt.count).to eq(1)
  end

  describe 'next response' do
    let(:waiting_since) { start + 30.minutes }

    before do
      conversation.update_columns(first_reply_created_at: start + 1.minute, waiting_since: waiting_since) # rubocop:disable Rails/SkipsModelValidations
    end

    it 'only runs while the conversation is waiting for an agent and records one miss per waiting period' do
      evaluate(at: waiting_since + 4.minutes)
      expect(applied_sla.sla_events.nrt).to be_empty

      evaluate(at: waiting_since + 6.minutes)
      evaluate(at: waiting_since + 7.minutes)
      expect(applied_sla.sla_events.nrt.count).to eq(1)
    end

    it 'starts a new period when the customer writes again' do
      evaluate(at: waiting_since + 6.minutes)
      applied_sla.sla_events.nrt.first.update!(created_at: waiting_since + 6.minutes)
      new_waiting_since = waiting_since + 10.minutes
      conversation.update_columns(waiting_since: new_waiting_since) # rubocop:disable Rails/SkipsModelValidations

      evaluate(at: new_waiting_since + 6.minutes)

      expect(applied_sla.sla_events.nrt.count).to eq(2)
    end
  end

  describe 'when the conversation is resolved' do
    it 'marks the SLA as hit when nothing was missed' do
      conversation.resolved!

      evaluate(at: start + 5.minutes)

      expect(applied_sla).to be_hit
      expect(applied_sla.completed_at).to be_present
    end

    it 'marks the SLA as missed when a deadline was missed' do
      evaluate(at: start + 11.minutes)
      conversation.resolved!

      evaluate(at: start + 12.minutes)

      expect(applied_sla).to be_missed
    end
  end
end
