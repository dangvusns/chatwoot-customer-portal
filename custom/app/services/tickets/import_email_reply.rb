class Tickets::ImportEmailReply
  include MailboxHelper

  attr_reader :processed_mail

  def initialize(mail)
    @mail = mail
  end

  def perform
    return :ignored unless Tickets::EmailRouting.enabled?

    @conversation = Tickets::EmailRouting.conversation_for(@mail)
    return :ignored unless @conversation && eligible_sender?

    @processed_mail = MailPresenter.new(@mail, @conversation.account)
    return :ignored unless valid_reply?

    persist_reply
  rescue Mail::Field::ParseError, Mail::Field::IncompleteParseError
    :ignored
  end

  private

  def persist_reply
    @conversation.with_lock do
      return :ignored unless eligible_sender?
      return :duplicate if @conversation.messages.exists?(source_id: @mail.message_id)

      create_message
      add_attachments_to_message
    end
    :imported
  end

  def eligible_sender?
    customer = PortalCustomer.find_by(account_id: @conversation.account_id, contact_id: @conversation.contact_id)
    return false unless customer&.active? && !@conversation.account.suspended?
    return false if Array(@mail.from).any? { |sender| sender.casecmp?(Tickets::EmailRouting.address) }

    # Reply-To is controlled by the sender; it must never establish customer identity.
    Array(@mail.from).map(&:downcase) == [customer.contact.email.downcase]
  end

  def valid_reply?
    valid_message_id? && !processed_mail.auto_reply? && !processed_mail.bounced? && valid_attachments? &&
      mail_content.length <= Tickets::Portal::MAX_CONTENT_LENGTH &&
      (mail_content.present? || @mail.attachments.any?)
  end

  def valid_message_id?
    @mail.message_id.present? && @mail.message_id.bytesize <= 998 && @mail.message_id.exclude?("\u0000")
  end

  def valid_attachments?
    @mail.attachments.size <= Tickets::Portal::MAX_ATTACHMENTS &&
      @mail.attachments.all? { |attachment| attachment.decoded.bytesize <= Tickets::Portal::MAX_ATTACHMENT_SIZE }
  end

  def mail_content
    @mail_content ||= EmailReplyTrimmer.trim(
      processed_mail.text_content[:reply].presence ||
      ActionView::Base.full_sanitizer.sanitize(processed_mail.html_content[:reply].to_s)
    ).to_s.delete("\u0000")
  end
end
