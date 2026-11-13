module Tickets::AttachmentValidation
  extend ActiveSupport::Concern

  included do
    attr_reader :attachments

    validate :attachments_within_limits
  end

  def attachments=(files)
    @attachments = Array(files).compact_blank
  end

  private

  def attachments_within_limits
    return if attachments.blank?

    errors.add(:attachments, :too_many, count: Tickets::Portal::MAX_ATTACHMENTS) if attachments.size > Tickets::Portal::MAX_ATTACHMENTS
    errors.add(:attachments, :too_large) if attachments.any? { |file| file.size > Tickets::Portal::MAX_ATTACHMENT_SIZE }
  end
end
