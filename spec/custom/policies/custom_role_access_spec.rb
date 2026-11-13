require 'rails_helper'

# One spec covers every policy and service a custom role affects, so it has no single described class.
RSpec.describe 'Custom role access rules' do # rubocop:disable RSpec/DescribeClass
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:account_user) { agent.account_users.find_by(account: account) }
  let(:context) { { user: agent, account: account, account_user: account_user } }
  let(:other_agent) { create(:user, account: account, role: :agent) }

  before { create(:inbox_member, inbox: inbox, user: agent) }

  def assign_role(*permissions)
    account_user.update!(custom_role: create(:custom_role, account: account, permissions: permissions))
  end

  def conversation_for(assignee: nil)
    create(:conversation, account: account, inbox: inbox, assignee: assignee)
  end

  describe ConversationPolicy do
    it 'lets conversation_manage see everything in the agent inboxes' do
      assign_role('conversation_manage')

      expect(described_class.new(context, conversation_for(assignee: other_agent)).show?).to be(true)
    end

    it 'limits conversation_unassigned_manage to unassigned and own conversations' do
      assign_role('conversation_unassigned_manage')

      policy = ->(conversation) { described_class.new(context, conversation).show? }
      expect(policy.call(conversation_for)).to be(true)
      expect(policy.call(conversation_for(assignee: agent))).to be(true)
      expect(policy.call(conversation_for(assignee: other_agent))).to be(false)
    end

    it 'limits conversation_participating_manage to own and participating conversations' do
      assign_role('conversation_participating_manage')
      participating = conversation_for(assignee: other_agent)
      participating.conversation_participants.create!(user: agent, account: account)

      policy = ->(conversation) { described_class.new(context, conversation).show? }
      expect(policy.call(conversation_for(assignee: agent))).to be(true)
      expect(policy.call(participating)).to be(true)
      expect(policy.call(conversation_for)).to be(false)
    end

    it 'shows nothing when the role has no conversation permission' do
      assign_role('report_manage')

      expect(described_class.new(context, conversation_for(assignee: agent)).show?).to be(false)
    end

    it 'leaves plain agents unchanged' do
      expect(described_class.new(context, conversation_for(assignee: other_agent)).show?).to be(true)
    end
  end

  describe Conversations::PermissionFilterService do
    let!(:unassigned) { conversation_for }
    let!(:mine) { conversation_for(assignee: agent) }
    let!(:theirs) { conversation_for(assignee: other_agent) }

    def visible_ids
      described_class.new(account.conversations, agent, account).perform.pluck(:id)
    end

    it 'returns everything in the agent inboxes for plain agents and conversation_manage' do
      expect(visible_ids).to contain_exactly(unassigned.id, mine.id, theirs.id)

      assign_role('conversation_manage')
      expect(visible_ids).to contain_exactly(unassigned.id, mine.id, theirs.id)
    end

    it 'returns unassigned and own conversations for conversation_unassigned_manage' do
      assign_role('conversation_unassigned_manage')

      expect(visible_ids).to contain_exactly(unassigned.id, mine.id)
    end

    it 'returns own and participating conversations for conversation_participating_manage' do
      theirs.conversation_participants.create!(user: agent, account: account)
      assign_role('conversation_participating_manage')

      expect(visible_ids).to contain_exactly(mine.id, theirs.id)
    end

    it 'combines both permissions' do
      assign_role('conversation_unassigned_manage', 'conversation_participating_manage')

      expect(visible_ids).to contain_exactly(unassigned.id, mine.id)
    end

    it 'returns nothing without a conversation permission' do
      assign_role('contact_manage')

      expect(visible_ids).to be_empty
    end
  end

  describe 'feature permissions' do
    it 'opens reports for report_manage only' do
      expect(ReportPolicy.new(context, :report).view?).to be(false)

      assign_role('report_manage')
      expect(ReportPolicy.new(context, :report).view?).to be(true)
      expect(CsatSurveyResponsePolicy.new(context, CsatSurveyResponse).metrics?).to be(true)
    end

    it 'opens contact deletion for contact_manage only' do
      assign_role('report_manage')
      expect(ContactPolicy.new(context, Contact).destroy?).to be(false)

      assign_role('contact_manage')
      expect(ContactPolicy.new(context, Contact).destroy?).to be(true)
      expect(CompanyPolicy.new(context, Company).destroy?).to be(true)
    end

    it 'opens help center management for knowledge_base_manage only' do
      assign_role('contact_manage')
      expect(ArticlePolicy.new(context, Article).create?).to be(false)

      assign_role('knowledge_base_manage')
      expect(ArticlePolicy.new(context, Article).create?).to be(true)
      expect(CategoryPolicy.new(context, Category).update?).to be(true)
      expect(PortalPolicy.new(context, Portal).update?).to be(true)
    end

    it 'keeps administrators unaffected' do
      admin_user = create(:user, account: account, role: :administrator)
      admin_context = { user: admin_user, account: account, account_user: admin_user.account_users.find_by(account: account) }

      expect(ReportPolicy.new(admin_context, :report).view?).to be(true)
    end
  end
end
