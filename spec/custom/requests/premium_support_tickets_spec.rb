require 'rails_helper'

RSpec.describe 'Authenticated customer ticket workflow', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, channel: create(:channel_api, account: account)) }
  let(:customer) { create(:portal_customer, :active, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: customer.contact) }
  let(:ticket_path) { "/premium-support/tickets/#{conversation.display_id}" }
  let(:payload) do
    { tickets_submission: { subject: 'Cannot access my product', product: 'Product A', issue_type: 'Technical issue',
                            priority: 'high', message: 'Please help with my account.' } }
  end

  around do |example|
    with_modified_env(TICKET_PORTAL_INBOX_ID: inbox.id.to_s, FRONTEND_URL: 'http://www.example.com') { example.run }
  end

  before do
    create(:custom_attribute_definition, account: account, attribute_key: Tickets::Portal::PRODUCT_KEY,
                                         attribute_model: :conversation_attribute, attribute_display_type: :list,
                                         attribute_values: ['Product A', 'Product B'])
    create(:custom_attribute_definition, account: account, attribute_key: Tickets::Portal::ISSUE_TYPE_KEY,
                                         attribute_model: :conversation_attribute, attribute_display_type: :list,
                                         attribute_values: ['Technical issue', 'Billing'])
  end

  def sign_in_customer
    post '/premium-support/login', params: { email: customer.contact.email, password: 'Customer test password 123!' }
  end

  def image_upload
    fixture_file_upload(Rails.root.join('spec/assets/avatar.png'), 'image/png')
  end

  it 'requires sign-in to display or submit the form' do
    get '/premium-support/tickets/new'
    expect(response).to redirect_to('/premium-support/login')
    expect { post '/premium-support/tickets', params: payload }.not_to change(Conversation, :count)
    expect(response).to redirect_to('/premium-support/login')
  end

  it 'shows a submit button and the full catalog to the signed-in customer' do
    sign_in_customer
    get '/premium-support'
    expect(response.body).to include('Submit ticket', '/premium-support/tickets/new')
    page = Nokogiri::HTML(response.body)
    expect(page.at_css('main a[href="/premium-support/tickets/new"]').text).to eq('Submit ticket')
    get '/premium-support/tickets/new'
    expect(response.body).to include('Product A', 'Product B', 'Subject', 'Urgency', 'Technical issue')
  end

  it 'offers exactly four urgency values and defaults to Normal without a blank option' do
    sign_in_customer
    get '/premium-support/tickets/new'
    select = Nokogiri::HTML(response.body).at_css('select[name="tickets_submission[priority]"]')
    expect(select.css('option').map { |option| option['value'] }).to eq(%w[low medium high urgent])
    expect(select.at_css('option[selected]')['value']).to eq('medium')
    expect(select.css('option').map(&:text)).to eq(%w[Low Normal High Urgent])
  end

  it 'creates a ticket owned by the authenticated contact and ignores forged identity fields' do
    sign_in_customer
    payload[:tickets_submission].merge!(name: 'Someone else', email: 'someone-else@example.com')
    expect { post '/premium-support/tickets', params: payload }
      .to change(Conversation, :count).by(1).and change(Message, :count).by(1).and not_change(Contact, :count)
    ticket = Conversation.last
    expect(ticket.contact_id).to eq(customer.contact_id)
    expect(ticket).to be_high
    expect(ticket.custom_attributes).to include('support_product' => 'Product A', 'issue_type' => 'Technical issue')
    expect(ticket.additional_attributes['mail_subject']).to eq('Cannot access my product')
    expect(response).to redirect_to("/premium-support/tickets/#{ticket.display_id}")
  end

  it 'queues a confirmation email linked to the authenticated portal' do
    sign_in_customer
    expect { post '/premium-support/tickets', params: payload }.to have_enqueued_mail(TicketMailer, :received)
    expect(Tickets::Portal.url_for(Conversation.last)).to eq("http://www.example.com/premium-support/tickets/#{Conversation.last.display_id}")
  end

  it 'rejects a product outside the catalog without creating a partial ticket' do
    sign_in_customer
    payload[:tickets_submission][:product] = 'Unknown product'
    expect { post '/premium-support/tickets', params: payload }.not_to change(Conversation, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'rejects an unsupported urgency' do
    sign_in_customer
    payload[:tickets_submission][:priority] = 'unlimited'
    expect { post '/premium-support/tickets', params: payload }.not_to change(Conversation, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'requires a subject and preserves the entered message on validation failure' do
    sign_in_customer
    payload[:tickets_submission][:subject] = ''
    post '/premium-support/tickets', params: payload
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('Please help with my account.')
  end

  it 'rejects too many attachments without creating a partial ticket' do
    sign_in_customer
    payload[:tickets_submission][:attachments] = Array.new(6) { image_upload }
    expect { post '/premium-support/tickets', params: payload }.not_to change(Conversation, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'stores an uploaded attachment with the first customer message' do
    sign_in_customer
    payload[:tickets_submission][:attachments] = [image_upload]
    post '/premium-support/tickets', params: payload
    expect(response).to have_http_status(:found)
    expect(Conversation.last.messages.incoming.first.attachments.first.file).to be_attached
  end

  it 'shows public messages while hiding private notes and internal activity' do
    sign_in_customer
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming, content: 'My public question')
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing, content: 'Public agent response')
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing,
                     private: true, content: 'Private support note')
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :activity, content: 'Internal activity')
    get ticket_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('My public question')
    expect(response.body).to include('Submitter', 'Date submitted', 'Last updated', 'Source')
    expect(response.body).not_to include('Private support note', 'Internal activity')
    expect(response.body.index('My public question')).to be < response.body.index('Public agent response')
    page = Nokogiri::HTML(response.body)
    expect(page.at_css('form[action$="/reply"] input[type="submit"]')['value']).to eq('Send reply')
  end

  it 'denies access to another customer’s ticket and reply endpoint' do
    other = create(:conversation, account: account, inbox: inbox)
    sign_in_customer
    get "/premium-support/tickets/#{other.display_id}"
    expect(response).to have_http_status(:not_found)
    expect do
      post "/premium-support/tickets/#{other.display_id}/reply", params: { tickets_reply: { content: 'Forged reply' } }
    end.not_to change(Message, :count)
    expect(response).to have_http_status(:not_found)
  end

  it 'denies access to another inbox even when the contact matches' do
    other = create(:conversation, account: account, inbox: create(:inbox, account: account), contact: customer.contact)
    sign_in_customer
    get "/premium-support/tickets/#{other.display_id}"
    expect(response).to have_http_status(:not_found)
  end

  it 'reopens a resolved ticket when the customer replies' do
    conversation.resolved!
    sign_in_customer
    expect { post "#{ticket_path}/reply", params: { tickets_reply: { content: 'I still need help' } } }
      .to change { conversation.messages.incoming.count }.by(1)
    expect(conversation.reload).to be_open
    expect(response).to redirect_to(ticket_path)
  end

  it 'rejects an empty reply without adding a message' do
    conversation
    sign_in_customer
    expect { post "#{ticket_path}/reply", params: { tickets_reply: { content: '' } } }.not_to change(Message, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'allows the customer to close and reopen their ticket' do
    sign_in_customer
    patch ticket_path, params: { status: 'resolved' }
    expect(conversation.reload).to be_resolved
    patch ticket_path, params: { status: 'open' }
    expect(conversation.reload).to be_open
  end

  it 'does not let the customer set internal statuses or change someone else’s ticket' do
    conversation
    other = create(:conversation, account: account, inbox: inbox)
    sign_in_customer
    patch ticket_path, params: { status: 'snoozed' }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(conversation.reload).to be_open
    patch "/premium-support/tickets/#{other.display_id}", params: { status: 'resolved' }
    expect(response).to have_http_status(:not_found)
    expect(other.reload).to be_open
  end

  it 'serves a public attachment through an authenticated ownership check' do
    sign_in_customer
    message = create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming)
    attachment = message.attachments.create!(account: account, file_type: :image, file: image_upload)
    get "#{ticket_path}/attachments/#{attachment.id}"
    expect(response).to have_http_status(:ok)
    expect(response.headers['Content-Disposition']).to include('attachment')
    expect(response.body).to eq(File.binread(Rails.root.join('spec/assets/avatar.png')))
  end

  it 'embeds a public image in the timeline and serves its authorized inline preview' do
    sign_in_customer
    message = create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming)
    attachment = message.attachments.create!(account: account, file_type: :image, file: image_upload)
    get ticket_path
    page = Nokogiri::HTML(response.body)
    expect(page.at_css('article img')['src']).to eq("#{ticket_path}/attachments/#{attachment.id}?preview=1")
    get "#{ticket_path}/attachments/#{attachment.id}", params: { preview: '1' }
    expect(response).to have_http_status(:ok)
    expect(response.headers['Content-Disposition']).to include('inline')
    expect(response.body).to eq(File.binread(Rails.root.join('spec/assets/avatar.png')))
  end

  it 'offers non-image files as downloads without allowing inline rendering' do
    sign_in_customer
    message = create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming)
    attachment = message.attachments.create!(account: account, file_type: :file,
                                            file: { io: StringIO.new('Support attachment'), filename: 'notes.txt', content_type: 'text/plain' })
    get "#{ticket_path}/attachments/#{attachment.id}", params: { preview: '1' }
    expect(response).to have_http_status(:not_found)
    get "#{ticket_path}/attachments/#{attachment.id}"
    expect(response).to have_http_status(:ok)
    expect(response.headers['Content-Disposition']).to include('attachment')
  end

  it 'rejects a private-note attachment even on an owned ticket' do
    sign_in_customer
    message = create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing, private: true)
    attachment = message.attachments.create!(account: account, file_type: :image, file: image_upload)
    get "#{ticket_path}/attachments/#{attachment.id}"
    expect(response).to have_http_status(:not_found)
    get "#{ticket_path}/attachments/#{attachment.id}", params: { preview: '1' }
    expect(response).to have_http_status(:not_found)
  end

  it 'does not expose another ticket’s attachment through an owned ticket URL' do
    sign_in_customer
    message = create(:message, account: account, inbox: inbox)
    attachment = message.attachments.create!(account: account, file_type: :image, file: image_upload)
    get "#{ticket_path}/attachments/#{attachment.id}"
    expect(response).to have_http_status(:not_found)
  end

  it 'renders the Vietnamese form and reports an unconfigured catalog visibly' do
    sign_in_customer
    get '/premium-support/tickets/new', params: { locale: 'vi' }
    expect(response.body).to include('Gửi phiếu hỗ trợ', 'Tiêu đề', 'Sản phẩm')
    account.custom_attribute_definitions.find_by!(attribute_key: Tickets::Portal::PRODUCT_KEY).destroy!
    get '/premium-support/tickets/new'
    expect(response.body).to include('Danh mục sản phẩm chưa được thiết lập')
  end

  it 'renders Vietnamese conversation timestamps without depending on global time-format translations' do
    sign_in_customer
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming, content: 'Vietnamese ticket')
    get ticket_path, params: { locale: 'vi' }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Trao đổi', 'Vietnamese ticket')
    expect(response.body).not_to include('Translation missing')
  end

  it 'shows a Vietnamese validation message for a missing subject' do
    sign_in_customer
    get '/premium-support/tickets/new', params: { locale: 'vi' }
    payload[:tickets_submission][:subject] = ''
    post '/premium-support/tickets', params: payload
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('không được để trống')
    expect(response.body).not_to include('Translation missing')
  end
end
