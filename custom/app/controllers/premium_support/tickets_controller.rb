class PremiumSupport::TicketsController < PremiumSupport::BaseController
  before_action :find_ticket, only: [:show, :update, :reply]

  def show
    @reply = Tickets::Reply.new
    load_messages
  end

  def new
    @submission = Tickets::Submission.new
  end

  def create
    @submission = Tickets::Submission.new(submission_params)
    @submission.assign_attributes(name: current_customer.contact.name, email: current_customer.contact.email, portal_customer: current_customer)
    if @submission.save
      conversation = @submission.conversation
      TicketMailer.with(account: conversation.account).received(conversation).deliver_later
      redirect_to premium_support_ticket_path(conversation.display_id), notice: t('premium_support.ticket_created')
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    status = params.permit(:status).require(:status)
    return head :unprocessable_entity unless %w[open resolved].include?(status)

    @conversation.update!(status: status)
    redirect_to premium_support_ticket_path(@conversation.display_id), notice: t('premium_support.status_updated')
  end

  def reply
    @reply = Tickets::Reply.new(params.require(:tickets_reply).permit(:content, attachments: []))
    if @reply.save(@conversation)
      redirect_to premium_support_ticket_path(@conversation.display_id), notice: t('premium_support.reply_sent')
    else
      load_messages
      render :show, status: :unprocessable_entity
    end
  end

  private

  def find_ticket
    @conversation = customer_tickets.find_by!(display_id: params[:id])
  end

  def load_messages
    @messages = @conversation.messages.where(private: false, message_type: %w[incoming outgoing])
                             .includes(:sender, attachments: { file_attachment: :blob }).reorder(created_at: :desc, id: :desc)
                             .page(params.fetch(:message_page, 1)).per(50)
  end

  def submission_params
    params.require(:tickets_submission).permit(:subject, :product, :issue_type, :priority, :message, attachments: [])
  end
end
