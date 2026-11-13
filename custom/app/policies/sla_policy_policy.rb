class SlaPolicyPolicy < ApplicationPolicy
  # Policy names are shown to agents (for example in automation and conversation views), so reading is open
  def index?
    true
  end

  def show?
    true
  end

  def create?
    account_user.administrator?
  end

  def update?
    account_user.administrator?
  end

  def destroy?
    account_user.administrator?
  end
end
