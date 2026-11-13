require 'csv'

class Api::V1::Accounts::AppliedSlasController < Api::V1::Accounts::BaseController
  PER_PAGE = 25
  CSV_HEADERS = ['Conversation', 'SLA policy', 'Status', 'Assignee', 'Labels', 'Missed events', 'Applied at'].freeze

  before_action :check_authorization

  def index
    @applied_slas = report_query.applied_slas.includes(:sla_policy, :sla_events, conversation: [:contact, :assignee])
                                .page(params.fetch(:page, 1).to_i).per(PER_PAGE)
  end

  def metrics
    render json: report_query.metrics
  end

  def download
    send_data csv_report, filename: 'sla_report.csv', type: 'text/csv'
  end

  private

  # Same access as the other reports (administrators and custom roles with report_manage)
  def check_authorization
    authorize(:report, :view?)
  end

  def report_query
    Custom::Sla::ReportQuery.new(Current.account, params)
  end

  def csv_report
    CSV.generate do |csv|
      csv << CSV_HEADERS
      report_query.applied_slas.includes(:sla_policy, :sla_events, conversation: :assignee).find_each { |applied_sla| csv << csv_row(applied_sla) }
    end
  end

  def csv_row(applied_sla)
    conversation = applied_sla.conversation
    [conversation.display_id, applied_sla.sla_policy.name, applied_sla.sla_status, conversation.assignee&.name,
     conversation.label_list.join(', '), applied_sla.sla_events.map(&:event_type).join(', '), applied_sla.created_at.iso8601]
  end
end
