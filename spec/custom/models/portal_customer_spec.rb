require 'rails_helper'

RSpec.describe PortalCustomer, type: :model do
  describe 'validation' do
    it 'allows invitation before a password is set' do
      expect(build(:portal_customer)).to be_valid
    end

    it 'rejects a contact from another account' do
      customer = build(:portal_customer, contact: create(:contact, :with_email))
      expect(customer).not_to be_valid
    end

    it 'requires an email address' do
      customer = build(:portal_customer)
      customer.contact.email = nil
      expect(customer).not_to be_valid
    end

    it 'rejects an active account without a password' do
      expect(build(:portal_customer, status: :active)).not_to be_valid
    end

    it 'rejects short passwords and mismatched confirmation' do
      expect(build(:portal_customer, :active, password: 'short')).not_to be_valid
      expect(build(:portal_customer, :active, password_confirmation: 'different')).not_to be_valid
    end

    it 'rejects unsupported languages' do
      expect(build(:portal_customer, locale: 'unknown')).not_to be_valid
    end

    it 'does not store a plaintext password' do
      customer = create(:portal_customer, :active)
      expect(customer.password_digest).not_to eq(customer.password)
      expect(customer.authenticate('Customer test password 123!')).to eq(customer)
      expect(customer.authenticate('incorrect')).to be(false)
    end
  end

  describe 'access links' do
    let(:customer) { create(:portal_customer) }

    it 'expires invitation links after 48 hours' do
      token = customer.generate_token_for(:invitation)
      expect(described_class.find_by_token_for(:invitation, token)).to eq(customer)
      travel 49.hours do
        expect(described_class.find_by_token_for(:invitation, token)).to be_nil
      end
    end

    it 'invalidates earlier links when an invitation is resent' do
      token = customer.generate_token_for(:invitation)
      expect { customer.issue_access_link!(:invitation) }.to have_enqueued_mail(PortalCustomerMailer, :access_link)
      expect(described_class.find_by_token_for(:invitation, token)).to be_nil
    end

    it 'invalidates links on suspension and reactivation' do
      token = customer.generate_token_for(:invitation)
      customer.change_access!(:suspended)
      customer.change_access!(:invited)
      expect(described_class.find_by_token_for(:invitation, token)).to be_nil
    end

    it 'expires password reset links after 30 minutes' do
      customer.update!(status: :active, password: 'Customer test password 123!')
      token = customer.generate_token_for(:password_reset)
      travel 31.minutes do
        expect(described_class.find_by_token_for(:password_reset, token)).to be_nil
      end
    end

    it 'revokes credentials when the linked contact email changes' do
      customer.update!(status: :active, password: 'Customer test password 123!')
      token = customer.generate_token_for(:password_reset)
      customer.contact.update!(email: 'changed@example.com')
      expect(customer.reload).to be_suspended
      expect(customer.password_digest).to be_nil
      expect(described_class.find_by_token_for(:password_reset, token)).to be_nil
    end
  end
end
