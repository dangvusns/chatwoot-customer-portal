class PremiumSupport::HomeController < PremiumSupport::BaseController
  def index
    @conversations = customer_tickets.order(last_activity_at: :desc).page(params.fetch(:page, 1)).per(20)
  end
end
