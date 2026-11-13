class Tickets::TicketsController < Tickets::BaseController
  def show
    @token = params[:token]
    @conversation = Tickets::Portal.find_conversation!(@token)
    # Private notes and activity messages are internal and never shown to the customer
    @messages = @conversation.messages
                             .where(private: false, message_type: %w[incoming outgoing])
                             .includes(:sender, :attachments)
                             .order(:created_at)
    @reply = Tickets::Reply.new
  end
end
