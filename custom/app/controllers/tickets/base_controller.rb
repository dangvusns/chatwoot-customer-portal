# Public pages for customers: ApplicationController would require a logged-in agent.
class Tickets::BaseController < ActionController::Base # rubocop:disable Rails/ApplicationController
  layout 'tickets'

  before_action :set_global_config

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  private

  def set_global_config
    @global_config = GlobalConfig.get('BRAND_NAME', 'INSTALLATION_NAME')
  end

  def render_not_found
    render 'tickets/not_found', status: :not_found
  end
end
