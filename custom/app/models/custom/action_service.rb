module Custom::ActionService
  # Automation action `add_sla`. The dashboard sends the policy id as a one element array.
  def add_sla(sla_policy_id)
    account = @conversation.account
    return unless account.feature_enabled?('sla')

    sla_policy = account.sla_policies.find_by(id: Array(sla_policy_id).first)
    @conversation.update!(sla_policy: sla_policy) if sla_policy.present?
  end
end
