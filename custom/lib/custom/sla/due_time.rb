# Adds a duration to a start time. With business hours the clock only runs while the inbox is open.
module Custom::Sla::DueTime
  MAX_DAYS_AHEAD = 60

  module_function

  def after(start_time, seconds, inbox:, business_hours_only:)
    return start_time + seconds unless business_hours_only && inbox.working_hours_enabled? && inbox.working_hours.exists?

    Time.use_zone(inbox.timezone) { add_business_seconds(start_time.in_time_zone, seconds, inbox) } || (start_time + seconds)
  end

  # Walks day by day through the open windows. Returns nil if the deadline is further than MAX_DAYS_AHEAD days away.
  def add_business_seconds(start_time, seconds, inbox)
    remaining = seconds
    hours_by_day = inbox.working_hours.index_by(&:day_of_week)

    MAX_DAYS_AHEAD.times do |offset|
      day = start_time.to_date + offset
      window = open_window(hours_by_day[day.wday], day)
      next if window.nil?

      window_start = [window.first, start_time].max
      available = window.last - window_start
      next unless available.positive?
      return window_start + remaining if remaining <= available

      remaining -= available
    end
    nil
  end

  def open_window(working_hour, day)
    return if working_hour.nil? || working_hour.closed_all_day?

    day_start = day.in_time_zone
    return [day_start, day_start + 1.day] if working_hour.open_all_day?

    [day_start.change(hour: working_hour.open_hour, min: working_hour.open_minutes),
     day_start.change(hour: working_hour.close_hour, min: working_hour.close_minutes)]
  end
end
