class Tickets::RepliesController < Tickets::BaseController
  def create
    @token = params[:token]
    @conversation = Tickets::Portal.find_conversation!(@token)
    @reply = Tickets::Reply.new(reply_params)

    if @reply.save(@conversation)
      redirect_to ticket_path(@token), notice: t('tickets.flash.replied')
    else
      @messages = @conversation.messages.where(private: false, message_type: %w[incoming outgoing]).includes(:sender, :attachments).order(:created_at)
      render 'tickets/tickets/show', status: :unprocessable_entity
    end
  end

  private

  def reply_params
    params.require(:tickets_reply).permit(:content, attachments: [])
  end
end
