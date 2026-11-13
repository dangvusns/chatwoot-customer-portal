module Custom::Audit::Webhook
  extend ActiveSupport::Concern

  included do
    # The webhook secret is deliberately not audited
    audited only: %i[url subscriptions webhook_type], associated_with: :account
  end
end
