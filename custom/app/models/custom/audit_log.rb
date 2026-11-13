class Custom::AuditLog < Audited::Audit
  # Audits have no account column. Rows belong to an account through the audited record's `associated` link,
  # or are about the account itself.
  scope :for_account, lambda { |account|
    where(associated_type: 'Account', associated_id: account.id).or(where(auditable_type: 'Account', auditable_id: account.id))
  }

  def self.record_sign_in(user)
    user.account_users.includes(:account).find_each do |account_user|
      create!(auditable: user, associated: account_user.account, user: user, action: 'sign_in',
              audited_changes: {}, remote_address: Audited.store[:current_remote_address])
    end
  end

  def location
    [city, country].compact_blank.join(', ').presence
  end
end
