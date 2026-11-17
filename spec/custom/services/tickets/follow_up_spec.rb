require 'rails_helper'

RSpec.describe Tickets::FollowUp do
  subject(:follow_up) { described_class.new(message) }

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, channel: create(:channel_api, account: account)) }
  let(:customer) { create(:portal_customer, :active, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: customer.contact) }
  let!(:message) { create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing) }

  around do |example|
    travel_to(Time.zone.parse('2026-11-16 09:00:00 UTC')) do
      with_modified_env(TICKET_PORTAL_INBOX_ID: inbox.id.to_s, FRONTEND_URL: 'http://www.example.com',
                        TICKET_FOLLOW_UP_ENABLED: 'true', TICKET_EMAIL_REPLIES_ENABLED: nil) { example.run }
    end
  end

  before { clear_enqueued_jobs }

  def customer_reply
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, sender: customer.contact)
  end

  it 'waits exactly 48 hours before sending the reminder and schedules resolution 24 hours later' do
    travel 48.hours - 1.second
    expect { follow_up.remind }.not_to change(ActionMailer::Base.deliveries, :count)
    travel 1.second
    expect { follow_up.remind }.to change(ActionMailer::Base.deliveries, :count).by(1)
    expect(Tickets::ResolveUnansweredJob).to have_been_enqueued.with(message.id).at(24.hours.from_now)
  end

  it 'resolves only after 24 hours from a successfully sent reminder' do
    travel 48.hours
    follow_up.remind
    travel 24.hours - 1.second
    follow_up.resolve
    expect(conversation.reload).not_to be_resolved
    travel 1.second
    follow_up.resolve
    expect(conversation.reload).to be_resolved
  end

  it 'does not close a ticket without a recorded reminder' do
    travel 80.hours
    follow_up.resolve
    expect(conversation.reload).not_to be_resolved
  end

  it 'cancels a reminder when the customer has replied' do
    travel 24.hours
    customer_reply
    travel 24.hours
    expect { follow_up.remind }.not_to change(ActionMailer::Base.deliveries, :count)
  end

  it 'cancels automatic resolution when the customer replies after the reminder' do
    travel 48.hours
    follow_up.remind
    travel 1.hour
    customer_reply
    travel 24.hours
    follow_up.resolve
    expect(conversation.reload).not_to be_resolved
  end

  it 'invalidates the old countdown when an agent sends another public reply' do
    travel 48.hours
    follow_up.remind
    travel 1.hour
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing)
    travel 24.hours
    follow_up.resolve
    expect(conversation.reload).not_to be_resolved
  end

  it 'does not let private notes restart or cancel the countdown' do
    travel 48.hours
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, private: true)
    expect { follow_up.remind }.to change(ActionMailer::Base.deliveries, :count).by(1)
  end

  it 'does not remind or close tickets for suspended customers' do
    customer.suspended!
    travel 80.hours
    expect { follow_up.remind }.not_to change(ActionMailer::Base.deliveries, :count)
    follow_up.resolve
    expect(conversation.reload).not_to be_resolved
  end

  it 'respects manual resolution and snoozing' do
    conversation.snoozed!
    travel 48.hours
    expect { follow_up.remind }.not_to change(ActionMailer::Base.deliveries, :count)
    conversation.resolved!
    expect { follow_up.remind }.not_to change(ActionMailer::Base.deliveries, :count)
  end

  it 'does not resend a successful reminder and can recover a missed resolution enqueue' do
    travel 48.hours
    follow_up.remind
    clear_enqueued_jobs
    expect { follow_up.remind }.not_to change(ActionMailer::Base.deliveries, :count)
    expect(Tickets::ResolveUnansweredJob).to have_been_enqueued.with(message.id)
  end

  it 'keeps the ticket unchanged and schedules no resolution if reminder delivery fails' do
    travel 48.hours
    mailer = TicketMailer.with(account: account)
    delivery = instance_double(ActionMailer::MessageDelivery)
    allow(TicketMailer).to receive(:with).with(account: account).and_return(mailer)
    allow(mailer).to receive(:reminder).and_return(delivery)
    allow(delivery).to receive(:deliver_now).and_raise(Net::SMTPFatalError, 'Delivery failed')
    expect { follow_up.remind }.to raise_error(Net::SMTPFatalError)
    expect(conversation.reload.additional_attributes).not_to have_key(described_class::STATE_KEY)
    expect(Tickets::ResolveUnansweredJob).not_to have_been_enqueued
  end

  it 'does nothing when the feature is disabled' do
    travel 80.hours
    with_modified_env(TICKET_FOLLOW_UP_ENABLED: nil) do
      expect { follow_up.remind }.not_to change(ActionMailer::Base.deliveries, :count)
      follow_up.resolve
      expect(conversation.reload).not_to be_resolved
    end
  end
end
