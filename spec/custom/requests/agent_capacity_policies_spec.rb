require 'rails_helper'

RSpec.describe 'Agent capacity policies API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:policies_path) { "/api/v1/accounts/#{account.id}/agent_capacity_policies" }
  let!(:policy) do
    create(:agent_capacity_policy, account: account, name: 'Standard',
                                   exclusion_rules: { 'excluded_labels' => ['vip'], 'exclude_older_than_hours' => 48 })
  end

  describe 'policies' do
    it 'lists policies as a plain array with the fields the dashboard reads' do
      get policies_path, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first).to include('id' => policy.id, 'name' => 'Standard', 'assigned_agent_count' => 0,
                                                    'exclusion_rules' => { 'excluded_labels' => ['vip'], 'exclude_older_than_hours' => 48 })
    end

    it 'creates, updates and deletes a policy' do
      post policies_path, params: { name: 'Night', exclusion_rules: { excluded_labels: ['spam'], exclude_older_than_hours: 12 } },
                          headers: admin.create_new_auth_token, as: :json
      created = AgentCapacityPolicy.find(response.parsed_body['id'])
      expect(created.exclusion_rules).to eq('excluded_labels' => ['spam'], 'exclude_older_than_hours' => 12)

      patch "#{policies_path}/#{created.id}", params: { name: 'Night shift' }, headers: admin.create_new_auth_token, as: :json
      expect(created.reload.name).to eq('Night shift')

      delete "#{policies_path}/#{created.id}", headers: admin.create_new_auth_token, as: :json
      expect(AgentCapacityPolicy.exists?(created.id)).to be(false)
    end

    it 'rejects a policy without a name' do
      post policies_path, params: { name: '' }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'is not available to agents or across accounts' do
      get policies_path, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)

      foreign = create(:agent_capacity_policy, account: create(:account))
      get "#{policies_path}/#{foreign.id}", headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'assigned agents' do
    it 'assigns and removes an agent and counts them' do
      post "#{policies_path}/#{policy.id}/users", params: { user_id: agent.id, capacity: 20 }, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body).to include('id' => agent.id, 'email' => agent.email)
      expect(agent.account_users.find_by(account: account).agent_capacity_policy).to eq(policy)

      get "#{policies_path}/#{policy.id}/users", headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body.pluck('id')).to eq([agent.id])

      get policies_path, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body.first['assigned_agent_count']).to eq(1)

      delete "#{policies_path}/#{policy.id}/users/#{agent.id}", headers: admin.create_new_auth_token, as: :json
      expect(agent.account_users.find_by(account: account).agent_capacity_policy_id).to be_nil
    end

    it 'does not accept users from another account' do
      outsider = create(:user, account: create(:account))

      post "#{policies_path}/#{policy.id}/users", params: { user_id: outsider.id }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'inbox limits' do
    it 'creates, updates and deletes a limit' do
      post "#{policies_path}/#{policy.id}/inbox_limits", params: { inbox_id: inbox.id, conversation_limit: 5 },
                                                         headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body).to include('inbox_id' => inbox.id, 'conversation_limit' => 5, 'agent_capacity_policy_id' => policy.id)
      limit = InboxCapacityLimit.find(response.parsed_body['id'])

      patch "#{policies_path}/#{policy.id}/inbox_limits/#{limit.id}", params: { conversation_limit: 8 },
                                                                      headers: admin.create_new_auth_token, as: :json
      expect(limit.reload.conversation_limit).to eq(8)

      delete "#{policies_path}/#{policy.id}/inbox_limits/#{limit.id}", headers: admin.create_new_auth_token, as: :json
      expect(InboxCapacityLimit.exists?(limit.id)).to be(false)
    end

    it 'rejects a second limit for the same inbox and inboxes from another account' do
      InboxCapacityLimit.create!(agent_capacity_policy: policy, inbox: inbox, conversation_limit: 3)

      post "#{policies_path}/#{policy.id}/inbox_limits", params: { inbox_id: inbox.id, conversation_limit: 4 },
                                                         headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)

      foreign_inbox = create(:inbox, account: create(:account))
      post "#{policies_path}/#{policy.id}/inbox_limits", params: { inbox_id: foreign_inbox.id, conversation_limit: 4 },
                                                         headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
