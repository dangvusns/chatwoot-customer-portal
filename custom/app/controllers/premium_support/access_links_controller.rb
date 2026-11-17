class PremiumSupport::AccessLinksController < PremiumSupport::BaseController
  skip_before_action :require_customer
  before_action :find_customer, only: [:edit, :update]

  def new; end

  def edit; end

  def create
    email = params.permit(:email).require(:email).strip.downcase
    contact = Tickets::Portal.inbox.account.contacts.from_email(email)
    customer = PortalCustomer.find_by(contact: contact, account_id: Tickets::Portal.inbox.account_id) if contact
    customer.issue_access_link!(:password_reset) if customer&.active?
    redirect_to premium_support_login_path, notice: t('premium_support.reset_requested')
  end

  def update
    @customer.with_lock do
      return invalid_link unless valid_token_customer == @customer && @customer.eligible_for?(@purpose)

      @customer.assign_attributes(password_params)
      @customer.status = :active
      @customer.session_version += 1
      if @customer.save
        start_customer_session(@customer)
        redirect_to premium_support_root_path, notice: t('premium_support.password_saved')
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  private

  def find_customer
    @purpose = params[:purpose] == 'invitation' ? :invitation : :password_reset
    @customer = valid_token_customer
    invalid_link unless @customer&.eligible_for?(@purpose)
  end

  def valid_token_customer
    customer = PortalCustomer.find_by_token_for(@purpose, params[:token])
    customer if customer&.account_id == Tickets::Portal.inbox.account_id
  end

  def invalid_link
    render 'premium_support/access_links/invalid', status: :unprocessable_entity
  end

  def password_params
    payload = params.require(:portal_customer).permit(:password, :password_confirmation)
    payload.require(:password)
    payload.require(:password_confirmation)
    payload
  end
end
