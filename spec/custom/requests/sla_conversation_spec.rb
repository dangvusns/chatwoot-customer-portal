require 'rails_helper'

RSpec.describe 'Conversation SLA tracking', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:policy) do
    create(:sla_policy, account: account, first_response_time_threshold: 600, next_response_time_threshold: nil, resolution_time_threshold: 3600)
  end

  before { account.enable_features!('sla') }

  describe 'applying a policy' do
    it 'starts tracking when a policy is set' do
      conversation.update!(sla_policy: policy)

      expect(conversation.reload.applied_sla).to have_attributes(sla_policy_id: policy.id, account_id: account.id)
      expect(conversation.applied_sla).to be_active
    end

    it 'restarts tracking when the policy changes and stops when it is removed' do
      conversation.update!(sla_policy: policy)
      first_applied_sla = conversation.reload.applied_sla
      other_policy = create(:sla_policy, account: account)

      conversation.update!(sla_policy: other_policy)
      expect(conversation.reload.applied_sla.id).not_to eq(first_applied_sla.id)
      expect(AppliedSla.exists?(first_applied_sla.id)).to be(false)

      conversation.update!(sla_policy: nil)
      expect(conversation.reload.applied_sla).to be_nil
    end
  end

  describe 'automation action add_sla' do
    it 'attaches the policy sent as a one element array' do
      ActionService.new(conversation).add_sla([policy.id])

      expect(conversation.reload.sla_policy).to eq(policy)
    end

    it 'ignores policies from other accounts and accounts without the feature' do
      foreign_policy = create(:sla_policy, account: create(:account))
      ActionService.new(conversation).add_sla([foreign_policy.id])
      expect(conversation.reload.sla_policy).to be_nil

      account.disable_features!('sla')
      ActionService.new(conversation).add_sla([policy.id])
      expect(conversation.reload.sla_policy).to be_nil
    end
  end

  describe 'conversation JSON' do
    let(:conversation_path) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}" }

    it 'includes the applied SLA with deadlines and events' do
      conversation.update!(sla_policy: policy)
      conversation.applied_sla.sla_events.create!(event_type: :frt, account: account, conversation: conversation, inbox: inbox, sla_policy: policy)

      get conversation_path, headers: admin.create_new_auth_token, as: :json

      body = response.parsed_body
      expect(body['sla_policy_id']).to eq(policy.id)
      expect(body['applied_sla']).to include('id' => conversation.applied_sla.id, 'sla_status' => 'active',
                                             'sla_frt_due_at' => conversation.created_at.to_i + 600,
                                             'sla_rt_due_at' => conversation.created_at.to_i + 3600)
      expect(body['sla_events'].pluck('event_type')).to eq(['frt'])
    end

    it 'sends an empty object when no SLA applies' do
      get conversation_path, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['applied_sla']).to eq({})
      expect(response.parsed_body['sla_events']).to eq([])
    end
  end

  describe Custom::Sla::ProcessAppliedSlasJob do
    it 'records misses for overdue SLAs and keeps going when one record fails' do
      conversation.update!(sla_policy: policy)
      broken = create(:conversation, account: account, inbox: inbox)
      broken.update!(sla_policy: policy)
      allow(Custom::Sla::Evaluator).to receive(:new).and_wrap_original do |original, applied_sla, **options|
        raise StandardError, 'boom' if applied_sla.conversation_id == broken.id

        original.call(applied_sla, **options)
      end
      allow(ChatwootExceptionTracker).to receive(:new).and_return(instance_double(ChatwootExceptionTracker, capture_exception: nil))

      travel_to(conversation.created_at + 2.hours) { described_class.perform_now }

      expect(conversation.applied_sla.sla_events.pluck(:event_type)).to contain_exactly('frt', 'rt')
      expect(ChatwootExceptionTracker).to have_received(:new).once
    end
  end
end
