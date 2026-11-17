class PremiumSupport::SessionsController < PremiumSupport::BaseController
  skip_before_action :require_customer

  def new; end

  def create
    customer = authenticate_customer(params.permit(:email, :password))

    if customer
      start_customer_session(customer)
      redirect_to premium_support_root_path
    else
      flash.now[:alert] = t('premium_support.invalid_login')
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to premium_support_login_path
  end

  private

  def authenticate_customer(credentials)
    password = credentials.require(:password)
    return if password.bytesize > 72

    email = credentials.require(:email).strip.downcase
    contact = Tickets::Portal.inbox.account.contacts.from_email(email)
    customer = PortalCustomer.find_by(contact: contact, account_id: Tickets::Portal.inbox.account_id) if contact
    # Match password hashing work for unknown accounts to reduce login enumeration by timing.
    BCrypt::Password.create(password) if customer&.password_digest.blank?
    customer if customer&.authenticate(password) && customer.active?
  end
end
