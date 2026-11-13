require 'rails_helper'

RSpec.describe Custom::Sla::DueTime do
  let(:inbox) { create(:inbox, working_hours_enabled: true, timezone: 'UTC') }
  let(:friday_afternoon) { Time.utc(2026, 11, 13, 16, 0) }

  before do
    inbox.working_hours.destroy_all
    (1..5).each do |day|
      create(:working_hour, inbox: inbox, day_of_week: day, open_hour: 9, open_minutes: 0, close_hour: 17, close_minutes: 0)
    end
    # the association was loaded (empty) by destroy_all above, so reload it to see the new rows
    inbox.working_hours.reset
  end

  it 'adds plain time when business hours are not required' do
    expect(described_class.after(friday_afternoon, 7200, inbox: inbox, business_hours_only: false)).to eq(friday_afternoon + 2.hours)
  end

  it 'adds plain time when the inbox does not use working hours' do
    inbox.update!(working_hours_enabled: false)

    expect(described_class.after(friday_afternoon, 7200, inbox: inbox, business_hours_only: true)).to eq(friday_afternoon + 2.hours)
  end

  it 'stays inside the day when the whole duration fits before closing' do
    expect(described_class.after(friday_afternoon, 1800, inbox: inbox, business_hours_only: true)).to eq(Time.utc(2026, 11, 13, 16, 30))
  end

  it 'skips the weekend and continues on the next open day' do
    due = described_class.after(friday_afternoon, 2.hours.to_i, inbox: inbox, business_hours_only: true)

    expect(due).to eq(Time.utc(2026, 11, 16, 10, 0))
  end

  it 'starts counting at opening time when the clock starts outside working hours' do
    saturday_noon = Time.utc(2026, 11, 14, 12, 0)

    expect(described_class.after(saturday_noon, 1.hour.to_i, inbox: inbox, business_hours_only: true)).to eq(Time.utc(2026, 11, 16, 10, 0))
  end

  it 'respects the inbox timezone' do
    inbox.update!(timezone: 'Asia/Ho_Chi_Minh')
    # 02:00 UTC on Monday is 09:00 in Ho Chi Minh, the moment the office opens
    monday_opening = Time.utc(2026, 11, 16, 2, 0)

    expect(described_class.after(monday_opening, 1.hour.to_i, inbox: inbox, business_hours_only: true)).to eq(Time.utc(2026, 11, 16, 3, 0))
  end
end
