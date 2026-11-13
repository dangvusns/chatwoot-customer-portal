require 'rails_helper'

RSpec.describe 'Custom roles API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:roles_path) { "/api/v1/accounts/#{account.id}/custom_roles" }

  describe 'GET /custom_roles' do
    it 'lists the account roles as a plain array for administrators' do
      role = create(:custom_role, account: account, permissions: ['report_manage'])
      create(:custom_role, account: create(:account))

      get roles_path, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck('id')).to eq([role.id])
      expect(response.parsed_body.first).to include('name' => role.name, 'permissions' => ['report_manage'])
    end

    it 'is not available to agents' do
      get roles_path, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /custom_roles' do
    it 'creates a role' do
      params = { name: 'Billing', description: 'Billing team', permissions: %w[report_manage contact_manage] }

      expect { post roles_path, params: params, headers: admin.create_new_auth_token, as: :json }.to change(CustomRole, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['permissions']).to eq(%w[report_manage contact_manage])
    end

    it 'rejects unknown permissions' do
      params = { name: 'Bad', permissions: ['delete_everything'] }

      expect { post roles_path, params: params, headers: admin.create_new_auth_token, as: :json }.not_to change(CustomRole, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH and DELETE /custom_roles/:id' do
    let!(:role) { create(:custom_role, account: account, permissions: ['report_manage']) }

    it 'updates a role' do
      patch "#{roles_path}/#{role.id}", params: { name: 'Renamed' }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(role.reload.name).to eq('Renamed')
    end

    it 'deletes a role and detaches its agents' do
      account_user = agent.account_users.find_by(account: account)
      account_user.update!(custom_role: role)

      delete "#{roles_path}/#{role.id}", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(account_user.reload.custom_role_id).to be_nil
    end

    it 'does not touch roles from another account' do
      other_role = create(:custom_role, account: create(:account))

      delete "#{roles_path}/#{other_role.id}", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'assigning a role through the agents API' do
    let(:role) { create(:custom_role, account: account, permissions: ['report_manage']) }
    let(:agent_path) { "/api/v1/accounts/#{account.id}/agents/#{agent.id}" }

    it 'gives the agent the role permissions' do
      patch agent_path, params: { custom_role_id: role.id }, headers: admin.create_new_auth_token, as: :json

      account_user = agent.account_users.find_by(account: account)
      expect(account_user.custom_role).to eq(role)
      expect(account_user.permissions).to eq(['report_manage'])
      expect(response.parsed_body['custom_role_id']).to eq(role.id)
    end

    it 'turns an administrator into a role-restricted agent' do
      other_admin = create(:user, account: account, role: :administrator)

      patch "/api/v1/accounts/#{account.id}/agents/#{other_admin.id}", params: { custom_role_id: role.id },
                                                                       headers: admin.create_new_auth_token, as: :json

      expect(other_admin.account_users.find_by(account: account)).to be_agent
    end

    it 'clears the role when custom_role_id is null' do
      agent.account_users.find_by(account: account).update!(custom_role: role)

      patch agent_path, params: { custom_role_id: nil }, headers: admin.create_new_auth_token, as: :json

      account_user = agent.account_users.find_by(account: account)
      expect(account_user.custom_role).to be_nil
      expect(account_user.permissions).to eq(['agent'])
    end

    it 'rejects a role from another account' do
      foreign_role = create(:custom_role, account: create(:account))

      patch agent_path, params: { custom_role_id: foreign_role.id }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
