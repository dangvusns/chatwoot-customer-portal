require 'rails_helper'

RSpec.describe TicketMailer, type: :mailer do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, channel: create(:channel_api, account: account)) }
  let(:customer) { create(:portal_customer, :active, account: account) }
  let(:conversation) do
    create(
      :conversation,
      account: account, inbox: inbox, contact: customer.contact,
      additional_attributes: { mail_subject: 'Product access problem' }
    )
  end
  let(:reply) { create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing, content: 'Public reply') }

  around do |example|
    with_modified_env(TICKET_PORTAL_INBOX_ID: inbox.id.to_s, FRONTEND_URL: 'http://www.example.com',
                      TICKET_SUPPORT_EMAIL: 'support@solidnsoft.vn', TICKET_EMAIL_REPLIES_ENABLED: 'true') { example.run }
  end

  it 'sends a plain-text confirmation with the subject and authenticated portal link' do
    email = described_class.with(account: account).received(conversation).message
    expect(email.subject).to include('Product access problem')
    expect(email.body.decoded).to include('Solid&Soft Support', '/premium-support/tickets/')
    expect(email.body.decoded).to include(customer.contact.name, 'Product access problem', 'Reply to this email')
    expect(email.body.decoded).not_to include('Chatwoot', 'Manage notification preferences')
  end

  it 'sends every ticket notification as text/plain without an HTML part' do
    mailer = described_class.with(account: account)
    notifications = [mailer.received(conversation), mailer.agent_reply(reply),
                     mailer.reminder(reply, 24.hours.from_now), mailer.resolved(conversation)]
    notifications.each do |notification|
      expect(notification.mime_type).to eq('text/plain')
      expect(notification).not_to be_multipart
      expect(notification.html_part).to be_nil
    end
  end

  it 'uses Vietnamese for the customer even when the account uses English' do
    customer.update!(locale: 'vi')
    email = described_class.with(account: account).received(conversation).message
    expect(email.subject).to include('Chúng tôi đã nhận được yêu cầu')
    expect(email.body.decoded).to include('Xin chào', 'Trả lời email này', 'Xem yêu cầu của bạn')
    expect(email.body.decoded).not_to include('translation missing')
  end

  it 'includes one prior customer message and excludes private notes' do
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming,
                     content: 'Customer context', sender: customer.contact)
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing,
                     private: true, content: 'Secret private note')
    email = described_class.with(account: account).agent_reply(reply).message
    expect(email.body.decoded).to include('Customer context', 'Public reply')
    expect(email.body.decoded).not_to include('Secret private note')
  end

  it 'preserves HTML mentioned in a reply as literal plain text' do
    reply.update!(content: '<script>alert(1)</script><strong>Reply</strong>')
    email = described_class.with(account: account).agent_reply(reply).message
    expect(email.mime_type).to eq('text/plain')
    expect(email.body.decoded).to include('<script>alert(1)</script><strong>Reply</strong>')
  end

  it 'does not expose attachment blob URLs in email' do
    reply.attachments.create!(
      account: account, file_type: :file,
      file: { io: StringIO.new('private to this ticket'), filename: 'report.txt', content_type: 'text/plain' }
    )
    email = described_class.with(account: account).agent_reply(reply).message
    expect(email.body.decoded).to include('Sign in to your ticket to view the attachments.')
    expect(email.body.decoded).not_to include('/rails/active_storage/')
  end

  it 'does not email a private note even when called directly' do
    reply.update!(private: true)
    expect { described_class.with(account: account).agent_reply(reply).deliver_now }.not_to change(ActionMailer::Base.deliveries, :count)
  end

  it 'does not send a reminder for a private note' do
    reply.update!(private: true)
    expect do
      described_class.with(account: account).reminder(reply, 24.hours.from_now).deliver_now
    end.not_to change(ActionMailer::Base.deliveries, :count)
  end

  it 'does not email an incoming customer message as an agent reply' do
    reply.update!(message_type: :incoming, sender: customer.contact)
    expect { described_class.with(account: account).agent_reply(reply).deliver_now }.not_to change(ActionMailer::Base.deliveries, :count)
  end

  it 'includes a clear reminder deadline' do
    deadline = Time.zone.parse('2026-11-19 09:00:00 UTC')
    email = described_class.with(account: account).reminder(reply, deadline).message
    expect(email.body.decoded).to include('within 24 hours', '2026-11-19 09:00 UTC', 'reopen')
  end

  it 'explains reopening in the plain-text resolution message' do
    email = described_class.with(account: account).resolved(conversation).message
    expect(email.body.decoded).to include('respond to reopen')
    expect(email.mime_type).to eq('text/plain')
  end

  it 'does not advertise email replies while ingestion is disabled' do
    with_modified_env(TICKET_EMAIL_REPLIES_ENABLED: nil) do
      email = described_class.with(account: account).received(conversation).message
      expect(email.body.decoded).to include('Open your ticket in the support portal')
      expect(email.body.decoded).not_to include('Reply to this email', 'above this line')
    end
  end

  it 'propagates SMTP failures to the job instead of reporting successful delivery' do
    delivery = described_class.with(account: account).received(conversation)
    allow(delivery.message.delivery_method).to receive(:deliver!).and_raise(Net::SMTPSyntaxError, 'Rejected')
    expect { delivery.deliver_now }.to raise_error(Net::SMTPSyntaxError)
  end
end
