# Filters applied SLAs for the SLA report (list, metrics and CSV share it).
class Custom::Sla::ReportQuery
  def initialize(account, params)
    @account = account
    @params = params
  end

  def applied_slas
    scope = AppliedSla.where(account_id: @account.id)
    scope = scope.where(created_at: Time.zone.at(@params[:since].to_i)..Time.zone.at(@params[:until].to_i)) if date_range?
    scope = scope.where(sla_policy_id: @params[:sla_policy_id]) if @params[:sla_policy_id].present?
    scope = scope.where(conversation_id: filtered_conversations.select(:id)) if conversation_filtered?
    scope.order(created_at: :desc, id: :desc)
  end

  def metrics
    total = applied_slas.count
    misses = applied_slas.where(sla_status: %i[missed active_with_misses]).count
    { total_applied_slas: total, number_of_sla_misses: misses, hit_rate: hit_rate(total, misses) }
  end

  private

  def date_range?
    @params[:since].present? && @params[:until].present?
  end

  def conversation_filtered?
    conversation_filters.any? || labels.any?
  end

  def conversation_filters
    {
      assignee_id: @params[:assigned_agent_id].presence,
      inbox_id: @params[:inbox_id].presence,
      team_id: @params[:team_id].presence
    }.compact
  end

  def filtered_conversations
    conversations = Conversation.where(account_id: @account.id).where(conversation_filters)
    conversations = conversations.where(id: labeled_conversation_ids) if labels.any?
    conversations
  end

  # Straight taggings lookup: the tagging gem's own scopes build SQL that cannot be used as a subquery
  def labeled_conversation_ids
    tag_ids = ActsAsTaggableOn::Tag.where(name: labels).select(:id)
    ActsAsTaggableOn::Tagging.where(taggable_type: 'Conversation', context: 'labels', tag_id: tag_ids).select(:taggable_id)
  end

  def labels
    Array(@params[:label_list]).flat_map { |label| label.to_s.split(',') }.compact_blank
  end

  def hit_rate(total, misses)
    return '0%' if total.zero?

    "#{((total - misses) * 100.0 / total).round(1)}%"
  end
end
