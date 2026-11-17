require 'rails_helper'

RSpec.describe TicketMailer, type: :mailer do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, channel: create(:channel_api, account: account)) }
  let(:customer) { create(:portal_customer, :active, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: customer.contact) }

  around do |example|
    with_modified_env(TICKET_PORTAL_INBOX_ID: inbox.id.to_s, FRONTEND_URL: 'http://www.example.com',
                      TICKET_SUPPORT_EMAIL: 'support@solidnsoft.vn', TICKET_EMAIL_REPLIES_ENABLED: 'true') { example.run }
  end

  it 'uses the alias and ticket token for an active portal customer' do
    mail = described_class.with(account: account).received(conversation)
    expect(mail.from).to eq(['support@solidnsoft.vn'])
    expect(mail.reply_to).to eq([Tickets::EmailRouting.reply_to(conversation)])
    expect(mail.reply_to.first.split('@').first.length).to be <= 64
  end

  it 'threads the agent reply against the latest incoming email' do
    incoming = create(
      :message, conversation: conversation, account: account, inbox: inbox, source_id: 'incoming@example.com', message_type: :incoming
    )
    message = create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing)
    mail = described_class.with(account: account).agent_reply(message)
    expect(mail.in_reply_to).to eq(incoming.source_id)
    expect(Array(mail.references)).to eq([incoming.source_id])
  end

  it 'leaves existing guest notifications unchanged' do
    customer.destroy!
    mail = described_class.with(account: account).received(conversation)
    expect(mail.reply_to).to be_nil
  end

  it 'leaves notifications unchanged when disabled' do
    with_modified_env(TICKET_EMAIL_REPLIES_ENABLED: nil) do
      mail = described_class.with(account: account).received(conversation)
      expect(mail.reply_to).to be_nil
    end
  end
end
