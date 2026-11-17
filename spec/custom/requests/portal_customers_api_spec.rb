require 'rails_helper'

RSpec.describe 'Portal customer management', type: :request do
  let(:account) { create(:account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:path) { "/api/v1/accounts/#{account.id}/portal_customers" }
  let(:headers) { admin.create_new_auth_token }

  it 'invites a customer without making them an agent' do
    payload = { portal_customer: { name: 'Example Customer', email: 'customer@example.com', locale: 'vi' } }
    expect do
      post path, params: payload, headers: headers, as: :json
    end.to change(PortalCustomer, :count).by(1).and change(Contact, :count).by(1).and not_change(User, :count)
    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('email' => 'customer@example.com', 'status' => 'invited', 'locale' => 'vi')
  end

  it 'reuses an existing contact in the same account' do
    contact = create(:contact, account: account, name: 'Existing customer', email: 'customer@example.com')
    expect do
      post path, params: { portal_customer: { name: 'Existing customer', email: contact.email } }, headers: headers, as: :json
    end.not_to change(Contact, :count)
    expect(PortalCustomer.last.contact).to eq(contact)
  end

  it 'does not expose password digests or session versions' do
    customer = create(:portal_customer, :active, account: account)
    get path, headers: headers, as: :json
    expect(response.parsed_body.first).to include('id' => customer.id)
    expect(response.parsed_body.first.keys).not_to include('password_digest', 'session_version')
  end

  it 'denies non-administrators' do
    get path, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'does not list customers from another account' do
    own = create(:portal_customer, account: account)
    create(:portal_customer)
    get path, headers: headers, as: :json
    expect(response.parsed_body.pluck('id')).to eq([own.id])
  end

  it 'does not change customers belonging to another account' do
    other = create(:portal_customer)
    post "#{path}/#{other.id}/suspend", headers: headers, as: :json
    expect(response).to have_http_status(:not_found)
    expect(other.reload).to be_invited
  end

  it 'suspends and reactivates invited customers without activating them' do
    customer = create(:portal_customer, account: account)
    post "#{path}/#{customer.id}/suspend", headers: headers, as: :json
    expect(customer.reload).to be_suspended
    post "#{path}/#{customer.id}/reactivate", headers: headers, as: :json
    expect(customer.reload).to be_invited
  end

  it 'does not allow password reset for a suspended customer' do
    customer = create(:portal_customer, account: account, status: :suspended)
    expect do
      post "#{path}/#{customer.id}/password_reset", headers: headers, as: :json
    end.not_to have_enqueued_mail(PortalCustomerMailer, :access_link)
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
