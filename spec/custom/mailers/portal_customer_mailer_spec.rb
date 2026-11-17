require 'rails_helper'

RSpec.describe PortalCustomerMailer, type: :mailer do
  around do |example|
    with_modified_env(FRONTEND_URL: 'http://www.example.com') { example.run }
  end

  it 'sends a multipart invitation with a valid activation link' do
    customer = create(:portal_customer)
    message = described_class.access_link(customer, 'invitation').message
    expect(message.to).to eq([customer.contact.email])
    expect(message.html_part.body.decoded).to include('Solid&amp;Soft Support')
    text = message.text_part.body.decoded
    link = text.lines.find { |line| line.start_with?('http://www.example.com/premium-support/access/') }
    expect(link).to be_present
    token = URI.parse(link.strip).path.split('/').last
    expect(PortalCustomer.find_by_token_for(:invitation, token)).to eq(customer)
  end

  it 'uses the customer’s chosen email language' do
    customer = create(:portal_customer, locale: 'vi')
    message = described_class.access_link(customer, 'invitation').message
    expect(message.subject).to include('Bạn được mời')
    expect(message.text_part.body.decoded).to include('Không chia sẻ liên kết này')
  end

  it 'does not deliver an access link for suspended customers' do
    customer = create(:portal_customer, status: :suspended)
    expect do
      described_class.access_link(customer, 'invitation').deliver_now
    end.not_to change(ActionMailer::Base.deliveries, :count)
  end
end
