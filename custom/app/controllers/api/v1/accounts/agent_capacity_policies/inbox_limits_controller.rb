class Api::V1::Accounts::AgentCapacityPolicies::InboxLimitsController < Api::V1::Accounts::BaseController
  before_action :fetch_policy
  before_action :fetch_inbox_limit, only: [:update, :destroy]
  before_action :check_authorization

  def create
    @inbox_limit = @agent_capacity_policy.inbox_capacity_limits.create!(params.permit(:inbox_id, :conversation_limit))
    render :show
  end

  def update
    @inbox_limit.update!(params.permit(:conversation_limit))
    render :show
  end

  def destroy
    @inbox_limit.destroy!
    head :ok
  end

  private

  def check_authorization
    super(AgentCapacityPolicy)
  end

  def fetch_policy
    @agent_capacity_policy = Current.account.agent_capacity_policies.find(params[:agent_capacity_policy_id])
  end

  def fetch_inbox_limit
    @inbox_limit = @agent_capacity_policy.inbox_capacity_limits.find(params[:id])
  end
end
