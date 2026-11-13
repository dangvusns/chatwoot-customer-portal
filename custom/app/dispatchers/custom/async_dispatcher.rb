module Custom::AsyncDispatcher
  def listeners
    super + [TicketNotificationListener.instance]
  end
end
