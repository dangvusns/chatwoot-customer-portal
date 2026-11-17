require 'rails_helper'

RSpec.describe Tickets::ImportEmailReply do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, channel: create(:channel_api, account: account)) }
  let(:customer) { create(:portal_customer, :active, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: customer.contact) }
  let(:mail) do
    Mail.new(from: customer.contact.email, to: Tickets::EmailRouting.reply_to(conversation),
             message_id: 'customer-reply@example.com', subject: 'Re: Support', body: 'My customer reply')
  end

  around do |example|
    with_modified_env(TICKET_PORTAL_INBOX_ID: inbox.id.to_s, TICKET_SUPPORT_EMAIL: 'support@solidnsoft.vn',
                      TICKET_EMAIL_REPLIES_ENABLED: 'true', FRONTEND_URL: 'http://www.example.com') { example.run }
  end

  def import_reply
    described_class.new(mail).perform
  end

  it 'appends one public customer message to the existing ticket and deduplicates retries' do
    conversation
    expect { expect(import_reply).to eq(:imported) }.to change(Message, :count).by(1).and not_change(Conversation, :count)
    message = conversation.messages.incoming.last
    expect(message).to have_attributes(
      content: 'My customer reply', sender: customer.contact, private: false, source_id: 'customer-reply@example.com'
    )
    expect { expect(import_reply).to eq(:duplicate) }.not_to change(Message, :count)
  end

  it 'reopens a resolved ticket' do
    conversation.resolved!
    import_reply
    expect(conversation.reload).to be_open
  end

  it 'imports attachments using the existing email attachment handling' do
    mail.attachments['example.txt'] = { mime_type: 'text/plain', content: 'Customer attachment' }
    expect(import_reply).to eq(:imported)
    attachment = conversation.messages.incoming.last.attachments.first
    expect(attachment.file.download).to eq('Customer attachment')
  end

  it 'ignores an empty body without raising or creating a message' do
    mail.body = ''
    expect { expect(import_reply).to eq(:ignored) }.not_to change(Message, :count)
  end

  it 'accepts an attachment-only reply' do
    mail.body = ''
    mail.attachments['example.txt'] = { mime_type: 'text/plain', content: 'Customer attachment' }
    expect(import_reply).to eq(:imported)
    expect(conversation.messages.incoming.last.attachments.first.file.download).to eq('Customer attachment')
  end

  it 'extracts text from an HTML-only reply' do
    mail.content_type = 'text/html; charset=UTF-8'
    mail.body = '<p>My customer reply</p>'
    expect(import_reply).to eq(:imported)
    expect(conversation.messages.incoming.last.content).to include('My customer reply')
    expect(conversation.messages.incoming.last.content).not_to include('<p>')
  end

  it 'does not trust Reply-To as customer identity' do
    mail.from = 'other@example.com'
    mail.reply_to = customer.contact.email
    expect { expect(import_reply).to eq(:ignored) }.not_to change(Message, :count)
  end

  it 'accepts a matching customer From regardless of their Reply-To' do
    mail.reply_to = 'different@example.com'
    expect(import_reply).to eq(:imported)
  end

  it 'rejects unknown tokens without creating contacts or tickets' do
    mail.to = 'support+ticket-00000000-0000-0000-0000-000000000000@solidnsoft.vn'
    expect { expect(import_reply).to eq(:ignored) }.not_to change(Conversation, :count)
  end

  it 'ignores unrelated messages in the owning mailbox' do
    mail.to = 'dangvu@solidnsoft.vn'
    expect { expect(import_reply).to eq(:ignored) }.not_to change(Message, :count)
  end

  it 'rejects suspended customers' do
    customer.suspended!
    expect { expect(import_reply).to eq(:ignored) }.not_to change(Message, :count)
  end

  it 'rejects tickets outside the configured inbox' do
    other_inbox = create(:inbox, account: account)
    conversation.update!(inbox: other_inbox)
    expect { expect(import_reply).to eq(:ignored) }.not_to change(Message, :count)
  end

  it 'ignores automated responses' do
    mail['Auto-Submitted'] = 'auto-replied'
    expect { expect(import_reply).to eq(:ignored) }.not_to change(Message, :count)
  end

  it 'rejects messages without a Message-ID' do
    mail.message_id = nil
    expect(import_reply).to eq(:ignored)
  end

  it 'rejects too many attachments' do
    6.times { |index| mail.attachments["#{index}.txt"] = 'example' }
    expect(import_reply).to eq(:ignored)
  end

  it 'rejects ambiguous ticket recipients' do
    other = create(:conversation, account: account, inbox: inbox, contact: customer.contact)
    mail.cc = Tickets::EmailRouting.reply_to(other)
    expect(import_reply).to eq(:ignored)
  end

  it 'does no routing work when disabled' do
    with_modified_env(TICKET_EMAIL_REPLIES_ENABLED: nil) do
      expect(Tickets::EmailRouting).not_to receive(:conversation_for)
      expect(import_reply).to eq(:ignored)
    end
  end
end
