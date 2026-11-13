require 'rails_helper'

RSpec.describe 'SLA policies and report API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:base_path) { "/api/v1/accounts/#{account.id}" }

  describe 'policies' do
    it 'wraps lists and single policies in a payload key' do
      policy = create(:sla_policy, account: account, name: 'Gold', first_response_time_threshold: 600)

      get "#{base_path}/sla_policies", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['payload'].first).to include('id' => policy.id, 'name' => 'Gold', 'first_response_time_threshold' => 600.0)
    end

    it 'lets administrators create, update and delete a policy' do
      post "#{base_path}/sla_policies", params: { name: 'Silver', first_response_time_threshold: 900, only_during_business_hours: true },
                                        headers: admin.create_new_auth_token, as: :json
      created = SlaPolicy.find(response.parsed_body['payload']['id'])
      expect(created).to have_attributes(name: 'Silver', only_during_business_hours: true)

      patch "#{base_path}/sla_policies/#{created.id}", params: { name: 'Silver plus', resolution_time_threshold: 7200 },
                                                       headers: admin.create_new_auth_token, as: :json
      expect(created.reload).to have_attributes(name: 'Silver plus', resolution_time_threshold: 7200.0)

      delete "#{base_path}/sla_policies/#{created.id}", headers: admin.create_new_auth_token, as: :json
      expect(SlaPolicy.exists?(created.id)).to be(false)
    end

    it 'rejects invalid input and writes by agents' do
      post "#{base_path}/sla_policies", params: { name: '', first_response_time_threshold: -5 }, headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)

      post "#{base_path}/sla_policies", params: { name: 'Nope' }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'detaches conversations when a policy is deleted' do
      policy = create(:sla_policy, account: account)
      conversation = create(:conversation, account: account, inbox: inbox)
      conversation.update!(sla_policy: policy)

      delete "#{base_path}/sla_policies/#{policy.id}", headers: admin.create_new_auth_token, as: :json

      expect(conversation.reload.sla_policy_id).to be_nil
      expect(AppliedSla.where(conversation: conversation)).to be_empty
    end
  end

  describe 'report' do
    let(:policy) { create(:sla_policy, account: account, name: 'Gold') }
    let(:other_policy) { create(:sla_policy, account: account, name: 'Bronze') }
    let(:assignee) { create(:user, account: account, role: :agent) }

    def applied_sla_for(sla_policy, status, **conversation_attributes)
      conversation = create(:conversation, account: account, inbox: inbox, **conversation_attributes)
      conversation.update!(sla_policy: sla_policy)
      conversation.applied_sla.update!(sla_status: status)
      conversation.applied_sla
    end

    before do
      applied_sla_for(policy, :hit, assignee: assignee)
      missed = applied_sla_for(policy, :missed)
      missed.sla_events.create!(event_type: :frt, account: account, conversation: missed.conversation, inbox: inbox, sla_policy: policy)
      applied_sla_for(other_policy, :active)
    end

    it 'lists applied SLAs with conversation, events and paging meta' do
      get "#{base_path}/applied_slas", headers: admin.create_new_auth_token, as: :json

      body = response.parsed_body
      expect(body['meta']).to eq('count' => 3, 'current_page' => 1)
      row = body['payload'].find { |item| item['applied_sla']['sla_status'] == 'missed' }
      expect(row['applied_sla']).to include('sla_name' => 'Gold')
      expect(row['sla_events'].pluck('event_type')).to eq(['frt'])
      expect(row['conversation']).to include('id', 'labels', 'contact')
    end

    it 'filters by policy, assignee and labels' do
      get "#{base_path}/applied_slas", params: { sla_policy_id: other_policy.id }, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['payload'].size).to eq(1)

      get "#{base_path}/applied_slas", params: { assigned_agent_id: assignee.id }, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['payload'].size).to eq(1)

      Conversation.last.update!(label_list: ['vip'])
      get "#{base_path}/applied_slas", params: { label_list: ['vip'] }, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['payload'].size).to eq(1)
    end

    it 'filters by date range' do
      get "#{base_path}/applied_slas", params: { since: 1.day.from_now.to_i, until: 2.days.from_now.to_i },
                                       headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['payload']).to be_empty
    end

    it 'reports totals, misses and hit rate' do
      get "#{base_path}/applied_slas/metrics", headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body).to eq('total_applied_slas' => 3, 'number_of_sla_misses' => 1, 'hit_rate' => '66.7%')
    end

    it 'downloads a CSV' do
      get "#{base_path}/applied_slas/download", headers: admin.create_new_auth_token

      expect(response.media_type).to eq('text/csv')
      expect(response.body.lines.first).to include('Conversation', 'SLA policy')
      expect(response.body.lines.size).to eq(4)
    end

    it 'is open to custom roles with report_manage but not to plain agents' do
      get "#{base_path}/applied_slas/metrics", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)

      role = create(:custom_role, account: account, permissions: ['report_manage'])
      agent.account_users.find_by(account: account).update!(custom_role: role)
      get "#{base_path}/applied_slas/metrics", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:ok)
    end
  end
end
