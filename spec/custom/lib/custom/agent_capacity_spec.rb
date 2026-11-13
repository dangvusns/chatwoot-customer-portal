require 'rails_helper'

RSpec.describe Custom::AgentCapacity do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:policy) { create(:agent_capacity_policy, account: account, exclusion_rules: {}) }

  before do
    create(:inbox_member, inbox: inbox, user: agent)
    create(:inbox_member, inbox: inbox, user: other_agent)
    agent.account_users.find_by(account: account).update!(agent_capacity_policy: policy)
    InboxCapacityLimit.create!(agent_capacity_policy: policy, inbox: inbox, conversation_limit: 2)
  end

  def open_conversations(count, assignee: agent, in_inbox: inbox)
    create_list(:conversation, count, account: account, inbox: in_inbox, assignee: assignee, status: :open)
  end

  describe '.eligible_user_ids' do
    it 'keeps an agent below the limit' do
      open_conversations(1)

      expect(described_class.eligible_user_ids(inbox, [agent.id, other_agent.id])).to contain_exactly(agent.id, other_agent.id)
    end

    it 'drops an agent who reached the limit but never an agent without a policy' do
      open_conversations(2)
      open_conversations(5, assignee: other_agent)

      expect(described_class.eligible_user_ids(inbox, [agent.id, other_agent.id])).to eq([other_agent.id])
    end

    it 'does not count resolved conversations or conversations in other inboxes' do
      open_conversations(2).each(&:resolved!)
      open_conversations(3, in_inbox: create(:inbox, account: account))

      expect(described_class.eligible_user_ids(inbox, [agent.id])).to eq([agent.id])
    end

    it 'does not limit an agent in an inbox where the policy has no limit' do
      other_inbox = create(:inbox, account: account)
      open_conversations(4, in_inbox: other_inbox)

      expect(described_class.eligible_user_ids(other_inbox, [agent.id])).to eq([agent.id])
    end

    it 'does not count conversations with an excluded label' do
      policy.update!(exclusion_rules: { 'excluded_labels' => ['vip'] })
      open_conversations(2).each do |conversation|
        conversation.label_list = 'vip'
        conversation.save!
      end

      expect(described_class.eligible_user_ids(inbox, [agent.id])).to eq([agent.id])
    end

    it 'does not count conversations older than the configured hours' do
      policy.update!(exclusion_rules: { 'exclude_older_than_hours' => 24 })
      open_conversations(2).each { |conversation| conversation.update_columns(last_activity_at: 3.days.ago) } # rubocop:disable Rails/SkipsModelValidations

      expect(described_class.eligible_user_ids(inbox, [agent.id])).to eq([agent.id])
    end

    it 'returns the input untouched when nobody has a policy' do
      agent.account_users.find_by(account: account).update!(agent_capacity_policy: nil)
      open_conversations(5)

      expect(described_class.eligible_user_ids(inbox, [agent.id, other_agent.id])).to eq([agent.id, other_agent.id])
    end
  end

  describe 'automatic assignment hooks' do
    before { open_conversations(2) }

    it 'removes full agents from the legacy assignment candidates' do
      expect(inbox.member_ids_with_assignment_capacity).to eq([other_agent.id])
    end

    it 'removes full agents from the assignment v2 candidates' do
      members = inbox.inbox_members.includes(:user).to_a
      service = AutoAssignment::AssignmentService.new(inbox: inbox)

      remaining = service.send(:filter_agents_by_rate_limit, members)

      expect(remaining.map(&:user_id)).to eq([other_agent.id])
    end
  end
end
