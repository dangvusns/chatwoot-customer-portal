module Custom::AutoAssignment::AssignmentService
  private

  # Runs alongside the rate limit: agents at their inbox capacity are not candidates
  def filter_agents_by_rate_limit(agents)
    eligible_user_ids = Custom::AgentCapacity.eligible_user_ids(inbox, agents.map(&:user_id))
    super(agents.select { |agent_member| eligible_user_ids.include?(agent_member.user_id) })
  end
end
