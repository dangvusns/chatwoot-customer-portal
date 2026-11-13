module Custom::Inbox
  # Agents whose capacity policy limit for this inbox is reached are left out of automatic assignment
  def member_ids_with_assignment_capacity
    Custom::AgentCapacity.eligible_user_ids(self, super)
  end
end
