require 'rails_helper'

RSpec.describe Tickets::RemindUnansweredJob, type: :job do
  it 'does no database work when disabled' do
    with_modified_env(TICKET_FOLLOW_UP_ENABLED: nil) do
      expect(Message).not_to receive(:find_by)
      described_class.perform_now(123)
      Tickets::ResolveUnansweredJob.perform_now(123)
    end
  end

  it 'ignores deleted messages' do
    with_modified_env(TICKET_FOLLOW_UP_ENABLED: 'true') do
      expect(Tickets::FollowUp).not_to receive(:new)
      described_class.perform_now(-1)
      Tickets::ResolveUnansweredJob.perform_now(-1)
    end
  end

  it 'serializes reminder delivery by conversation through the existing mutex' do
    account = create(:account)
    message = create(:message, account: account, message_type: :outgoing)
    follow_up = instance_double(Tickets::FollowUp, remind: nil)
    allow(Tickets::FollowUp).to receive(:new).with(message).and_return(follow_up)
    with_modified_env(TICKET_FOLLOW_UP_ENABLED: 'true') do
      described_class.perform_now(message.id)
    end
    expect(follow_up).to have_received(:remind).once
  end
end
