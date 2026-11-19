require 'rails_helper'

RSpec.describe Tickets::SyncEmailReplies do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:imap) { instance_double(Net::IMAP) }
  let(:key) { "portal-email:#{inbox.id}:support@example.com:123" }
  let(:metadata) { instance_double(Net::IMAP::FetchData, attr: { 'RFC822.SIZE' => 100 }) }
  let(:body_data) { instance_double(Net::IMAP::FetchData, attr: { 'BODY[]' => 'From: customer@example.com' }) }
  let(:oversized_metadata) { instance_double(Net::IMAP::FetchData, attr: { 'RFC822.SIZE' => 80.megabytes }) }

  around do |example|
    with_modified_env(TICKET_PORTAL_INBOX_ID: inbox.id.to_s, TICKET_SUPPORT_EMAIL: 'support@example.com',
                      TICKET_EMAIL_REPLIES_ENABLED: 'true', SMTP_USERNAME: 'owner@example.com', SMTP_PASSWORD: 'test-secret') { example.run }
  end

  before do
    allow(Net::IMAP).to receive(:new).with('imap.gmail.com', port: 993, ssl: true).and_return(imap)
    allow(imap).to receive(:login).with('owner@example.com', 'test-secret')
    allow(imap).to receive(:examine).with('INBOX')
    allow(imap).to receive(:status).with('INBOX', %w[UIDVALIDITY UIDNEXT]).and_return('UIDVALIDITY' => 123, 'UIDNEXT' => 2001)
    allow(imap).to receive_messages(disconnected?: false, disconnect: nil)
    allow(Redis::Alfred).to receive(:get).with(key).and_return('1000')
    allow(Redis::Alfred).to receive(:set)
  end

  it 'searches only tagged recipients in a bounded UID window without marking messages read' do
    expect(imap).to receive(:uid_search).with(['UID', '1001:2000', 'OR', 'TO', 'support+ticket-', 'CC', 'support+ticket-']).and_return([1500])
    expect(imap).to receive(:uid_fetch).with(1500, 'RFC822.SIZE').and_return([metadata])
    expect(imap).to receive(:uid_fetch).with(1500, 'BODY.PEEK[]').and_return([body_data])
    importer = instance_double(Tickets::ImportEmailReply, perform: :imported)
    allow(Tickets::ImportEmailReply).to receive(:new).and_return(importer)
    expect(Redis::Alfred).to receive(:set).with(key, 2000)
    expect(described_class.new.perform).to eq(imported: 1)
  end

  it 'does not advance the cursor when message retrieval fails' do
    allow(imap).to receive(:uid_search).and_return([1500])
    allow(imap).to receive(:uid_fetch).and_raise(IOError)
    expect(Redis::Alfred).not_to receive(:set)
    expect { described_class.new.perform }.to raise_error(IOError)
    expect(imap).to have_received(:disconnect)
  end

  it 'bounds each poll to 20 messages and resumes at the last processed UID' do
    allow(imap).to receive(:uid_search).and_return((1500..1525).to_a)
    allow(imap).to receive(:uid_fetch).with(anything, 'RFC822.SIZE').and_return([oversized_metadata])
    expect(Redis::Alfred).to receive(:set).with(key, 1519)
    expect(described_class.new.perform).to eq(oversized: 20)
    expect(imap).not_to have_received(:uid_fetch).with(anything, 'BODY.PEEK[]')
  end

  it 'does not connect or query Redis when disabled' do
    with_modified_env(TICKET_EMAIL_REPLIES_ENABLED: nil) do
      expect(Net::IMAP).not_to receive(:new)
      expect(Redis::Alfred).not_to receive(:get)
      described_class.new.perform
    end
  end
end
