class Tickets::SupportController < Tickets::BaseController
  def new
    @submission = Tickets::Submission.new
  end

  def create
    @submission = Tickets::Submission.new(submission_params)
    # Bots fill the hidden field. Pretend it worked without creating anything.
    return redirect_to ticket_support_path if @submission.spam?

    if @submission.save
      conversation = @submission.conversation
      TicketMailer.with(account: conversation.account).received(conversation).deliver_later
      redirect_to ticket_path(Tickets::Portal.token_for(conversation)), notice: t('tickets.flash.submitted', number: conversation.display_id)
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def submission_params
    params.require(:tickets_submission).permit(:name, :email, :issue_type, :message, :website, attachments: [])
  end
end
