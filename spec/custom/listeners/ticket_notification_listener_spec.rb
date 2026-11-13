require 'rails_helper'

describe TicketNotificationListener do
  subject(:listener) { described_class.instance }

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, channel: create(:channel_api, account: account)) }
  let(:contact) { create(:contact, account: account, email: 'vu@example.com') }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }

  around do |example|
    with_modified_env(TICKET_PORTAL_INBOX_ID: inbox.id.to_s, FRONTEND_URL: 'http://www.example.com') { example.run }
  end

  def message_event(message)
    Events::Base.new('message.created', Time.zone.now, message: message)
  end

  def status_event(conversation)
    Events::Base.new('conversation.status_changed', Time.zone.now, conversation: conversation)
  end

  describe '#message_created' do
    it 'emails the customer about a public agent reply' do
      message = create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing, content: 'We are on it')

      expect { listener.message_created(message_event(message)) }.to have_enqueued_mail(TicketMailer, :agent_reply)
    end

    it 'ignores private notes' do
      message = create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing, private: true)

      expect { listener.message_created(message_event(message)) }.not_to have_enqueued_mail(TicketMailer, :agent_reply)
    end

    it 'ignores the customer own messages' do
      message = create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming)

      expect { listener.message_created(message_event(message)) }.not_to have_enqueued_mail(TicketMailer, :agent_reply)
    end

    it 'ignores conversations from other inboxes' do
      other_conversation = create(:conversation, account: account, inbox: create(:inbox, account: account), contact: contact)
      message = create(:message, conversation: other_conversation, account: account, inbox: other_conversation.inbox, message_type: :outgoing)

      expect { listener.message_created(message_event(message)) }.not_to have_enqueued_mail(TicketMailer, :agent_reply)
    end

    it 'does nothing and does not raise when the portal inbox is not configured' do
      message = create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing)

      with_modified_env(TICKET_PORTAL_INBOX_ID: nil) do
        expect { listener.message_created(message_event(message)) }.not_to have_enqueued_mail(TicketMailer, :agent_reply)
      end
    end
  end

  describe '#conversation_status_changed' do
    it 'emails the customer when the ticket is resolved' do
      conversation.resolved!

      expect { listener.conversation_status_changed(status_event(conversation)) }.to have_enqueued_mail(TicketMailer, :resolved)
    end

    it 'does not email for other status changes' do
      conversation.pending!

      expect { listener.conversation_status_changed(status_event(conversation)) }.not_to have_enqueued_mail(TicketMailer, :resolved)
    end
  end
end
