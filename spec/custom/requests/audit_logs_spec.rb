require 'rails_helper'

RSpec.describe 'Audit logs', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:audit_path) { "/api/v1/accounts/#{account.id}/audit_logs" }

  def logs_for(account)
    Custom::AuditLog.for_account(account)
  end

  describe 'recording changes' do
    it 'records creating, renaming and deleting a team against the account' do
      team = create(:team, account: account, name: 'Support')
      team.update!(name: 'Tier 2')
      team.destroy!

      actions = logs_for(account).where(auditable_type: 'Team').order(:id).pluck(:action)
      expect(actions).to eq(%w[create update destroy])
    end

    it 'records membership changes with the user id' do
      inbox = create(:inbox, account: account)
      create(:inbox_member, inbox: inbox, user: agent)

      log = logs_for(account).find_by(auditable_type: 'InboxMember', action: 'create')
      expect(log.audited_changes).to include('user_id' => agent.id, 'inbox_id' => inbox.id)
    end

    it 'records only the deletion of a conversation, with its display id' do
      conversation = create(:conversation, account: account)
      display_id = conversation.display_id
      conversation.destroy!

      logs = logs_for(account).where(auditable_type: 'Conversation')
      expect(logs.pluck(:action)).to eq(['destroy'])
      expect(logs.first.audited_changes['display_id']).to eq(display_id)
    end

    it 'never stores the webhook secret' do
      create(:webhook, account: account, url: 'https://example.com/hook')

      log = logs_for(account).find_by(auditable_type: 'Webhook')
      expect(log.audited_changes.keys).not_to include('secret')
    end

    it 'records a sign-in once per account the user belongs to' do
      other_account = create(:account)
      create(:account_user, account: other_account, user: admin)

      Custom::AuditLog.record_sign_in(admin)

      expect(logs_for(account).where(action: 'sign_in', user_id: admin.id).count).to eq(1)
      expect(logs_for(other_account).where(action: 'sign_in', user_id: admin.id).count).to eq(1)
    end
  end

  describe 'GET /audit_logs' do
    before do
      create(:team, account: account, name: 'Support')
      create(:inbox, account: account)
      create(:team, account: create(:account), name: 'Foreign')
    end

    it 'returns only this account entries in the shape the dashboard reads' do
      get audit_path, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body).to include('total_entries', 'per_page' => 25, 'current_page' => 1)
      expect(body['audit_logs'].pluck('auditable_type')).to all(satisfy { |type| %w[Team Inbox Account AccountUser].include?(type) })
      expect(body['audit_logs'].first).to include('id', 'action', 'audited_changes', 'created_at', 'auditable_type', 'auditable_id')
      expect(body['audit_logs'].map { |log| log['audited_changes']['name'] }).not_to include('Foreign')
    end

    it 'filters by type' do
      get audit_path, params: { types: ['Team'] }, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['audit_logs'].pluck('auditable_type').uniq).to eq(['Team'])
    end

    it 'searches by action text once the query has three characters' do
      get audit_path, params: { q: 'crea' }, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['audit_logs'].pluck('action').uniq).to eq(['create'])
    end

    it 'filters by date range' do
      get audit_path, params: { since: 1.day.from_now.to_i, until: 2.days.from_now.to_i }, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['audit_logs']).to be_empty
    end

    it 'pages and sorts' do
      get audit_path, params: { per_page: 1, page: 2, sort: 'asc' }, headers: admin.create_new_auth_token, as: :json

      body = response.parsed_body
      expect(body['audit_logs'].size).to eq(1)
      expect(body).to include('per_page' => 1, 'current_page' => 2)
    end

    it 'hides the IP address unless the account feature is on' do
      Custom::AuditLog.for_account(account).first.update!(remote_address: '203.0.113.9')

      get audit_path, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['audit_logs'].first).not_to have_key('remote_address')

      account.enable_features!('audit_log_ip_address')
      get audit_path, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['audit_logs'].pluck('remote_address')).to include('203.0.113.9')
    end

    it 'is not available to agents' do
      get audit_path, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
