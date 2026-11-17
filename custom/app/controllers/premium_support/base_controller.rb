# Customer sessions must not inherit the agent API authentication or its CSRF exemption.
class PremiumSupport::BaseController < ActionController::Base # rubocop:disable Rails/ApplicationController
  layout 'premium_support'
  protect_from_forgery with: :exception

  before_action :prevent_caching
  before_action :require_customer
  around_action :use_customer_locale
  helper_method :current_customer
  rescue_from ActiveRecord::RecordNotFound, with: :ticket_not_found

  private

  def customer_tickets
    current_customer.contact.conversations.where(inbox_id: Tickets::Portal.inbox.id)
  end

  def ticket_not_found
    render 'premium_support/tickets/not_found', status: :not_found
  end

  def current_customer
    return @current_customer if defined?(@current_customer)

    customer = PortalCustomer.find_by(id: session[:portal_customer_id], account_id: Tickets::Portal.inbox.account_id)
    valid = customer&.active? && customer.session_version == session[:portal_session_version] &&
            session[:portal_expires_at].to_i > Time.current.to_i
    @current_customer = valid ? customer : nil
  end

  def require_customer
    redirect_to premium_support_login_path unless current_customer
  end

  def use_customer_locale(&)
    requested_locale = params[:locale].presence || session[:portal_locale] || current_customer&.locale
    locale = PortalCustomer::SUPPORTED_LOCALES.include?(requested_locale) ? requested_locale : 'en'
    session[:portal_locale] = locale
    I18n.with_locale(locale, &)
  end

  def prevent_caching
    response.headers['Cache-Control'] = 'no-store'
    response.headers['Referrer-Policy'] = 'no-referrer'
  end

  def start_customer_session(customer)
    reset_session
    session[:portal_customer_id] = customer.id
    session[:portal_session_version] = customer.session_version
    session[:portal_expires_at] = PortalCustomer::SESSION_DURATION.from_now.to_i
  end
end
