require 'rails_helper'

RSpec.describe 'Premium support customer authentication', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, channel: create(:channel_api, account: account)) }
  let(:customer) { create(:portal_customer, :active, account: account) }

  around do |example|
    with_modified_env(TICKET_PORTAL_INBOX_ID: inbox.id.to_s, FRONTEND_URL: 'http://www.example.com') { example.run }
  end

  def log_in(as_customer = customer)
    post '/premium-support/login', params: { email: as_customer.contact.email, password: 'Customer test password 123!' }
  end

  def change_password(token, purpose: 'invitation', password: 'A new customer password 123!')
    patch "/premium-support/access/#{token}", params: {
      purpose: purpose, portal_customer: { password: password, password_confirmation: password }
    }
  end

  it 'requires customer authentication for the ticket list' do
    get '/premium-support'
    expect(response).to redirect_to('/premium-support/login')
  end

  it 'does not accept an agent login as a customer session' do
    agent = create(:user, account: account, role: :administrator)
    get '/premium-support', headers: agent.create_new_auth_token
    expect(response).to redirect_to('/premium-support/login')
  end

  it 'signs an active customer in and displays only that contact’s portal tickets' do
    own = create(:conversation, account: account, inbox: inbox, contact: customer.contact)
    other = create(:conversation, account: account, inbox: inbox)
    log_in
    expect(response).to redirect_to('/premium-support')
    follow_redirect!
    expect(response.body).to include("Ticket ##{own.display_id}<")
    expect(response.body).not_to include("Ticket ##{other.display_id}<")
    expect(response.headers['Cache-Control']).to include('no-store')
  end

  it 'rejects invited, suspended, and unknown accounts without distinguishing them' do
    customer.change_access!(:suspended)
    log_in
    suspended_response = response.body
    expect(response).to have_http_status(:unprocessable_entity)
    post '/premium-support/login', params: { email: 'missing@example.com', password: 'Customer test password 123!' }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include(I18n.t('premium_support.invalid_login'))
    expect(suspended_response).to include(I18n.t('premium_support.invalid_login'))
    post '/premium-support/login', params: { email: customer.contact.email, password: 'a' * 73 }
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'does not admit a customer from another Chatwoot account' do
    other = create(:portal_customer, :active)
    log_in(other)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'invalidates an existing session when a customer is suspended, even after reactivation' do
    log_in
    customer.change_access!(:suspended)
    get '/premium-support'
    expect(response).to redirect_to('/premium-support/login')
    customer.change_access!(:active)
    get '/premium-support'
    expect(response).to redirect_to('/premium-support/login')
  end

  it 'expires sessions after twelve hours' do
    log_in
    travel 13.hours do
      get '/premium-support'
      expect(response).to redirect_to('/premium-support/login')
    end
  end

  it 'signs out the customer' do
    log_in
    delete '/premium-support/logout'
    get '/premium-support'
    expect(response).to redirect_to('/premium-support/login')
  end

  it 'activates an invited customer and rejects token reuse' do
    invited = create(:portal_customer, account: account)
    token = invited.generate_token_for(:invitation)
    change_password(token)
    expect(response).to redirect_to('/premium-support')
    expect(invited.reload).to be_active
    change_password(token)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'rejects invalid passwords without consuming the invitation' do
    invited = create(:portal_customer, account: account)
    token = invited.generate_token_for(:invitation)
    change_password(token, password: 'short')
    expect(response).to have_http_status(:unprocessable_entity)
    expect(invited.reload).to be_invited
    expect(PortalCustomer.find_by_token_for(:invitation, token)).to eq(invited)
  end

  it 'rejects invitation links for another account' do
    invited = create(:portal_customer)
    get "/premium-support/access/#{invited.generate_token_for(:invitation)}", params: { purpose: 'invitation' }
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'does not disclose whether an email exists when requesting a password reset' do
    post '/premium-support/password', params: { email: customer.contact.email }
    expect(response).to redirect_to('/premium-support/login')
    post '/premium-support/password', params: { email: 'missing@example.com' }
    expect(response).to redirect_to('/premium-support/login')
  end

  it 'resets an active password and invalidates earlier sessions and the reset token' do
    log_in
    old_browser = open_session
    old_browser.post '/premium-support/login', params: { email: customer.contact.email, password: 'Customer test password 123!' }
    token = customer.generate_token_for(:password_reset)
    change_password(token, purpose: 'password_reset')
    expect(customer.reload.authenticate('A new customer password 123!')).to eq(customer)
    expect(PortalCustomer.find_by_token_for(:password_reset, token)).to be_nil
    old_browser.get '/premium-support'
    expect(old_browser.response).to have_http_status(:found)
    expect(URI.parse(old_browser.response.location).path).to eq('/premium-support/login')
  end

  it 'renders Vietnamese sign-in and ticket status pages' do
    get '/premium-support/login', params: { locale: 'vi' }
    expect(response.body).to include('Đăng nhập cổng hỗ trợ')
    customer.update!(locale: 'vi')
    create(:conversation, account: account, inbox: inbox, contact: customer.contact)
    log_in
    follow_redirect!
    expect(response.body).to include('Phiếu hỗ trợ #', 'Đang xử lý')
    expect(response.body).not_to include('Translation missing')
  end

  context 'with CSRF protection enabled' do
    around do |example|
      previous_setting = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = previous_setting
    end

    it 'rejects login without a CSRF token' do
      log_in
      expect(response).to have_http_status(:unprocessable_entity)
      get '/premium-support'
      expect(response).to redirect_to('/premium-support/login')
    end
  end
end
