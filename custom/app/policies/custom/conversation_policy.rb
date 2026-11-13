module Custom::ConversationPolicy
  include Custom::CustomRolePermissions

  private

  # Inbox or team access is still required. A custom role then narrows it by assignment.
  def agent_can_view_conversation?
    return super unless account_user&.agent? && account_user.custom_role.present?

    super && custom_role_allows_conversation?
  end

  def custom_role_allows_conversation?
    return true if custom_role_permission?('conversation_manage')
    return true if custom_role_permission?('conversation_unassigned_manage') && (record.assignee_id.nil? || assigned_to_user?)

    custom_role_permission?('conversation_participating_manage') && (assigned_to_user? || participant?)
  end
end
