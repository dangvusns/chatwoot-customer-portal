class Api::V1::Accounts::AuditLogsController < Api::V1::Accounts::BaseController
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100
  MIN_SEARCH_LENGTH = 3

  before_action :check_authorization

  def show
    @per_page = params.fetch(:per_page, DEFAULT_PER_PAGE).to_i.clamp(1, MAX_PER_PAGE)
    @audit_logs = filtered_audit_logs.page(params.fetch(:page, 1).to_i).per(@per_page)
    @account_users_by_id = AccountUser.where(id: @audit_logs.select { |log| log.auditable_type == 'AccountUser' }.map(&:auditable_id)).index_by(&:id)
    @show_ip_address = Current.account.feature_enabled?('audit_log_ip_address')
  end

  private

  def check_authorization
    super(:audit_log)
  end

  def filtered_audit_logs
    logs = filter_by_date_range(filter_by_type(Custom::AuditLog.for_account(Current.account)))
    logs = search(logs) if params[:q].to_s.strip.length >= MIN_SEARCH_LENGTH
    logs.order(created_at: sort_direction, id: sort_direction)
  end

  def filter_by_type(logs)
    return logs if params[:types].blank?

    logs.where(auditable_type: Array(params[:types]))
  end

  def filter_by_date_range(logs)
    return logs unless params[:since].present? && params[:until].present?

    logs.where(created_at: Time.zone.at(params[:since].to_i)..Time.zone.at(params[:until].to_i))
  end

  def search(logs)
    pattern = "%#{Custom::AuditLog.sanitize_sql_like(params[:q].to_s.strip)}%"
    table = Custom::AuditLog.arel_table
    logs.where(table[:auditable_type].matches(pattern).or(table[:action].matches(pattern)).or(table[:username].matches(pattern)))
  end

  def sort_direction
    params[:sort] == 'asc' ? :asc : :desc
  end
end
