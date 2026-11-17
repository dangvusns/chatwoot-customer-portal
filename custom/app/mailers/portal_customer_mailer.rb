class PortalCustomerMailer < ApplicationMailer
  layout false

  def access_link(customer, purpose)
    @customer = customer
    @purpose = purpose.to_sym
    return unless @customer.eligible_for?(@purpose)

    I18n.with_locale(customer.locale) do
      @access_url = Rails.application.routes.url_helpers.premium_support_access_url(
        token: customer.generate_token_for(@purpose), purpose: purpose, locale: customer.locale, host: ENV.fetch('FRONTEND_URL')
      )
      mail(to: customer.contact.email, subject: t("premium_support.mailer.#{purpose}"))
    end
  end
end
