class Api::V1::Accounts::AgentCapacityPolicies::UsersController < Api::V1::Accounts::BaseController
  before_action :fetch_policy
  before_action :check_authorization

  def index
    @users = Current.account.users.where(account_users: { agent_capacity_policy_id: @agent_capacity_policy.id }).order(:id)
  end

  def create
    @user = Current.account.users.find(params[:user_id])
    @user.account_users.find_by!(account_id: Current.account.id).update!(agent_capacity_policy: @agent_capacity_policy)
    render :show
  end

  def destroy
    account_user = AccountUser.find_by!(account_id: Current.account.id, user_id: params[:id], agent_capacity_policy_id: @agent_capacity_policy.id)
    account_user.update!(agent_capacity_policy: nil)
    head :ok
  end

  private

  def check_authorization
    super(AgentCapacityPolicy)
  end

  def fetch_policy
    @agent_capacity_policy = Current.account.agent_capacity_policies.find(params[:agent_capacity_policy_id])
  end
end
