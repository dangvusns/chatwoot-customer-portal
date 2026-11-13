namespace :tickets do
  desc 'Create the ticket portal inbox and issue type list. Optional env: ACCOUNT_ID, ISSUE_TYPES (comma separated)'
  task setup: :environment do
    account_id = ENV.fetch('ACCOUNT_ID', nil)
    account = account_id.present? ? Account.find(account_id) : Account.first!
    issue_types = ENV.fetch('ISSUE_TYPES', 'Service and support,Billing,Technical issue,Account access,Other').split(',').map(&:strip)

    inbox = account.inboxes.find_by(name: 'Support Portal')
    inbox ||= account.inboxes.create!(name: 'Support Portal', channel: Channel::Api.create!(account: account), enable_auto_assignment: false)

    definition = account.custom_attribute_definitions.find_or_initialize_by(
      attribute_key: Tickets::Portal::ISSUE_TYPE_KEY,
      attribute_model: :conversation_attribute
    )
    definition.update!(attribute_display_name: 'Issue type', attribute_display_type: :list, attribute_values: issue_types)

    puts "Set this in .env and restart: TICKET_PORTAL_INBOX_ID=#{inbox.id}"
  end
end
