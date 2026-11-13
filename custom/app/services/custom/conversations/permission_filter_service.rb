module Custom::Conversations::PermissionFilterService
  private

  # Narrow the inbox-based list for agents with a custom role (administrators never reach this).
  def accessible_conversations
    inbox_conversations = super
    permissions = custom_role_permissions
    return inbox_conversations if permissions.nil? || permissions.include?('conversation_manage')

    visible = inbox_conversations.none
    visible = visible.or(inbox_conversations.where(assignee_id: [nil, user.id])) if permissions.include?('conversation_unassigned_manage')
    visible = visible.or(participating_conversations(inbox_conversations)) if permissions.include?('conversation_participating_manage')
    visible
  end

  def participating_conversations(inbox_conversations)
    participated_ids = ConversationParticipant.where(user_id: user.id).select(:conversation_id)
    inbox_conversations.where(assignee_id: user.id).or(inbox_conversations.where(id: participated_ids))
  end

  # nil means the user is not a custom-role agent
  def custom_role_permissions
    current_account_user = account_user
    return unless current_account_user&.agent? && current_account_user.custom_role.present?

    current_account_user.custom_role.permissions
  end
end
