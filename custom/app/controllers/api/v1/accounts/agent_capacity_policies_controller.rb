class Api::V1::Accounts::AgentCapacityPoliciesController < Api::V1::Accounts::BaseController
  before_action :fetch_policy, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @agent_capacity_policies = Current.account.agent_capacity_policies.includes(:inbox_capacity_limits).order(:id)
  end

  def show; end

  def create
    @agent_capacity_policy = Current.account.agent_capacity_policies.create!(policy_params)
    render :show
  end

  def update
    @agent_capacity_policy.update!(policy_params)
    render :show
  end

  def destroy
    @agent_capacity_policy.destroy!
    head :ok
  end

  private

  def fetch_policy
    @agent_capacity_policy = Current.account.agent_capacity_policies.find(params[:id])
  end

  def policy_params
    params.permit(:name, :description, exclusion_rules: [:exclude_older_than_hours, { excluded_labels: [] }])
  end
end
