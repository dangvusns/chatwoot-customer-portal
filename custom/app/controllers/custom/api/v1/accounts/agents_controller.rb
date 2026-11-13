module Custom::Api::V1::Accounts::AgentsController
  def create
    super
    assign_custom_role(@agent) if @agent.present? && !performed? && params.key?(:custom_role_id)
  end

  def update
    super
    assign_custom_role(@agent) if params.key?(:custom_role_id)
  end

  private

  # A blank custom_role_id clears the role. A role always makes the user a plain agent underneath.
  def assign_custom_role(agent)
    # same instance the JSON view reads, so the response shows the new role
    account_user = agent.current_account_user
    custom_role = Current.account.custom_roles.find(params[:custom_role_id]) if params[:custom_role_id].present?
    account_user.custom_role = custom_role
    account_user.role = :agent if custom_role.present?
    account_user.save!
  end
end
