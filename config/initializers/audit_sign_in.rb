# Company fork: record dashboard sign-ins in the audit log (one row per account the user belongs to)
Warden::Manager.after_set_user event: :authentication do |user, _auth, _options|
  next unless user.is_a?(User)

  begin
    Custom::AuditLog.record_sign_in(user)
  rescue StandardError => e
    # A failure to write the audit row must never block someone from signing in
    Rails.logger.error("Audit sign-in logging failed: #{e.message}")
  end
end
