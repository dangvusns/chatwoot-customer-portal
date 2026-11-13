module Custom::Audit::Macro
  extend ActiveSupport::Concern

  included do
    audited only: %i[name visibility actions], associated_with: :account
  end
end
