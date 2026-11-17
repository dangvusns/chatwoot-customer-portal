class PremiumSupport::AttachmentsController < PremiumSupport::BaseController
  include ActiveStorage::Streaming

  def show
    conversation = customer_tickets.find_by!(display_id: params[:ticket_id])
    attachment = conversation.attachments.joins(:message)
                             .where(messages: { private: false, message_type: %w[incoming outgoing] }).find(params[:id])
    raise ActiveRecord::RecordNotFound unless attachment.file.attached?

    preview = params[:preview] == '1'
    raise ActiveRecord::RecordNotFound if preview && !Tickets::Portal.previewable_image?(attachment)

    send_blob_stream attachment.file.blob, disposition: preview ? 'inline' : 'attachment'
  end
end
