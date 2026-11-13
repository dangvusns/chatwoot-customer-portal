# Decides which agents may still receive an automatic assignment in an inbox, based on their capacity policy.
# Agents without a policy, or whose policy has no limit for the inbox, are never limited.
module Custom::AgentCapacity
  module_function

  def eligible_user_ids(inbox, user_ids)
    return user_ids if user_ids.empty?

    account_users = limited_account_users(inbox, user_ids)
    return user_ids if account_users.empty?

    limits = InboxCapacityLimit.where(inbox_id: inbox.id, agent_capacity_policy_id: account_users.map(&:agent_capacity_policy_id))
                               .index_by(&:agent_capacity_policy_id)
    full_user_ids = account_users.select { |account_user| at_limit?(inbox, account_user, limits[account_user.agent_capacity_policy_id]) }
                                 .map(&:user_id)
    user_ids - full_user_ids
  end

  def limited_account_users(inbox, user_ids)
    AccountUser.where(account_id: inbox.account_id, user_id: user_ids)
               .where.not(agent_capacity_policy_id: nil)
               .includes(:agent_capacity_policy).to_a
  end

  def at_limit?(inbox, account_user, limit)
    return false if limit.blank?

    open_conversation_count(inbox, account_user) >= limit.conversation_limit
  end

  # Open conversations assigned to the agent in this inbox, minus those the policy excludes
  def open_conversation_count(inbox, account_user)
    rules = account_user.agent_capacity_policy.exclusion_rules
    conversations = inbox.conversations.open.where(assignee_id: account_user.user_id)
    conversations = exclude_stale(conversations, rules['exclude_older_than_hours'])
    conversations = exclude_labels(conversations, rules['excluded_labels'])
    conversations.count
  end

  def exclude_stale(conversations, hours)
    return conversations unless hours.to_i.positive?

    conversations.where(Conversation.arel_table[:last_activity_at].gteq(hours.to_i.hours.ago))
  end

  def exclude_labels(conversations, labels)
    return conversations if labels.blank?

    conversations.tagged_with(labels, exclude: true, any: true)
  end
end
