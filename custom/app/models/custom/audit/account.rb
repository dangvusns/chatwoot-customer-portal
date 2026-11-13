module Custom::Audit::Account
  extend ActiveSupport::Concern

  included do
    audited only: %i[name locale domain support_email status]
  end
end
