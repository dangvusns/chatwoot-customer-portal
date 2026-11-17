class Api::V1::Accounts::PortalCustomersController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :find_customer, except: [:index, :create]

  def index
    customers = Current.account.portal_customers.includes(:contact).order(id: :desc).page(params.fetch(:page, 1)).per(25)
    render json: customers.map { |customer| customer_payload(customer) }
  end

  def create
    customer = PortalCustomer.transaction do
      payload = params.require(:portal_customer).permit(:name, :email, :locale)
      contact = Current.account.contacts.find_or_initialize_by(email: payload.require(:email).strip.downcase)
      contact.name = payload.require(:name) if contact.new_record? || contact.name.blank?
      contact.save!
      Current.account.portal_customers.create!(contact: contact, locale: payload[:locale])
    end
    customer.issue_access_link!(:invitation)
    render json: customer_payload(customer), status: :created
  end

  def update
    @customer.update!(params.require(:portal_customer).permit(:locale))
    render json: customer_payload(@customer)
  end

  def invitation
    return head :unprocessable_entity unless @customer.invited?

    @customer.issue_access_link!(:invitation)
    head :no_content
  end

  def password_reset
    return head :unprocessable_entity unless @customer.active?

    @customer.issue_access_link!(:password_reset)
    head :no_content
  end

  def suspend
    @customer.change_access!(:suspended)
    head :no_content
  end

  def reactivate
    @customer.change_access!(@customer.password_digest.present? ? :active : :invited)
    head :no_content
  end

  private

  def find_customer
    @customer = Current.account.portal_customers.find(params[:id])
  end

  def customer_payload(customer)
    { id: customer.id, contact_id: customer.contact_id, name: customer.contact.name, email: customer.contact.email,
      locale: customer.locale, status: customer.status }
  end
end
