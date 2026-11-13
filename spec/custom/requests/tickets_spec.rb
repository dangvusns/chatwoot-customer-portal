require 'rails_helper'

RSpec.describe 'Ticket portal', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, channel: create(:channel_api, account: account)) }
  let(:valid_params) do
    { tickets_submission: { name: 'Vu Le', email: 'vu@example.com', issue_type: 'Billing', message: 'I cannot access the portal.' } }
  end

  around do |example|
    with_modified_env(TICKET_PORTAL_INBOX_ID: inbox.id.to_s, FRONTEND_URL: 'http://www.example.com') { example.run }
  end

  before do
    create(:custom_attribute_definition, account: account, attribute_key: 'issue_type', attribute_model: :conversation_attribute,
                                         attribute_display_type: :list, attribute_values: %w[Billing Other])
  end

  def ticket_conversation
    contact_inbox = create(:contact_inbox, inbox: inbox, contact: create(:contact, account: account, email: 'vu@example.com'))
    create(:conversation, account: account, inbox: inbox, contact: contact_inbox.contact, contact_inbox: contact_inbox)
  end

  describe 'GET /support' do
    it 'shows the submission form with the configured issue types' do
      get '/support'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Billing')
    end
  end

  describe 'POST /support' do
    it 'creates a ticket with the first message and redirects to the ticket page' do
      expect { post '/support', params: valid_params }
        .to change(Conversation, :count).by(1).and change(Message, :count).by(1)

      conversation = Conversation.last
      expect(conversation.custom_attributes['issue_type']).to eq('Billing')
      expect(conversation.messages.last).to be_incoming
      token = response.location.split('/tickets/').last
      expect(Tickets::Portal.find_conversation!(token)).to eq(conversation)
    end

    it 'sends the customer a confirmation email' do
      expect { post '/support', params: valid_params }.to have_enqueued_mail(TicketMailer, :received)
    end

    it 'rejects an invalid email without creating a ticket' do
      valid_params[:tickets_submission][:email] = 'not-an-email'

      expect { post '/support', params: valid_params }.not_to change(Conversation, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects an issue type that is not configured' do
      valid_params[:tickets_submission][:issue_type] = 'Made up'

      expect { post '/support', params: valid_params }.not_to change(Conversation, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'ignores submissions that fill the honeypot field' do
      valid_params[:tickets_submission][:website] = 'http://spam.example'

      expect { post '/support', params: valid_params }.not_to change(Conversation, :count)
      expect(response).to redirect_to(ticket_support_path)
    end
  end

  describe 'GET /tickets/:token' do
    it 'shows the ticket number, status and public messages but hides private notes' do
      conversation = ticket_conversation
      create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming, content: 'Public question')
      create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing, private: true, content: 'Internal note')

      get "/tickets/#{Tickets::Portal.token_for(conversation)}"

      expect(response.body).to include("Ticket ##{conversation.display_id}", 'Public question')
      expect(response.body).not_to include('Internal note')
    end

    it 'returns 404 for a tampered token' do
      get '/tickets/not-a-valid-token'

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 once the link has expired' do
      token = Tickets::Portal.token_for(ticket_conversation)

      travel_to(Tickets::Portal::TOKEN_TTL.from_now + 1.day) { get "/tickets/#{token}" }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for a conversation outside the ticket inbox' do
      other_inbox = create(:inbox, account: account)
      other = create(:conversation, account: account, inbox: other_inbox)

      get "/tickets/#{other.signed_id(purpose: Tickets::Portal::TOKEN_PURPOSE)}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /tickets/:token/replies' do
    it 'adds the customer reply and reopens a resolved ticket' do
      conversation = ticket_conversation
      conversation.resolved!
      token = Tickets::Portal.token_for(conversation)

      expect { post "/tickets/#{token}/replies", params: { tickets_reply: { content: 'Still broken' } } }
        .to change { conversation.messages.incoming.count }.by(1)

      expect(response).to redirect_to(ticket_path(token))
      expect(conversation.reload).to be_open
    end

    it 'rejects an empty reply' do
      conversation = ticket_conversation

      expect { post "/tickets/#{Tickets::Portal.token_for(conversation)}/replies", params: { tickets_reply: { content: '' } } }
        .not_to(change(Message, :count))
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
