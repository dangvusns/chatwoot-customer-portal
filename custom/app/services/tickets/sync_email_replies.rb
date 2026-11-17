require 'net/imap'
require 'timeout'

class Tickets::SyncEmailReplies
  UID_WINDOW = 1000
  BATCH_SIZE = 20
  MAX_RAW_SIZE = 75.megabytes

  def perform
    return unless Tickets::EmailRouting.enabled?
    return if Tickets::Portal.inbox.account.suspended?

    Timeout.timeout(50) do
      @imap = Net::IMAP.new('imap.gmail.com', port: 993, ssl: true)
      @imap.login(ENV.fetch('SMTP_USERNAME'), ENV.fetch('SMTP_PASSWORD'))
      @imap.examine('INBOX')
      sync_window
    end
  ensure
    @imap&.disconnect unless @imap&.disconnected?
  end

  private

  def sync_window
    status = @imap.status('INBOX', %w[UIDVALIDITY UIDNEXT])
    key = "portal-email:#{Tickets::Portal.inbox.id}:#{Tickets::EmailRouting.address}:#{status.fetch('UIDVALIDITY')}"
    latest = status.fetch('UIDNEXT') - 1
    # shortcut: first activation considers only the last 1000 UIDs; use an explicit backfill for historical replies.
    cursor = Redis::Alfred.get(key)&.to_i || [latest - UID_WINDOW, 0].max
    return if cursor >= latest

    upper = [cursor + UID_WINDOW, latest].min
    uids = tagged_uids(cursor + 1, upper)
    results = uids.first(BATCH_SIZE).map { |uid| import_uid(uid) }
    Redis::Alfred.set(key, uids.size > BATCH_SIZE ? uids[BATCH_SIZE - 1] : upper)
    results.tally
  end

  def tagged_uids(lower, upper)
    prefix = Tickets::EmailRouting.recipient_prefix
    @imap.uid_search(['UID', "#{lower}:#{upper}", 'OR', 'TO', prefix, 'CC', prefix]).sort
  end

  def import_uid(uid)
    metadata = @imap.uid_fetch(uid, 'RFC822.SIZE')&.first
    return :missing unless metadata
    return :oversized if metadata.attr.fetch('RFC822.SIZE') > MAX_RAW_SIZE

    data = @imap.uid_fetch(uid, 'BODY.PEEK[]')&.first
    return :missing unless data

    Tickets::ImportEmailReply.new(Mail.read_from_string(data.attr.fetch('BODY[]'))).perform
  end
end
