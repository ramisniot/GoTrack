FactoryGirl.define do
  factory :scheduled_report do
    sequence(:report_name) { |n| "Report #{n}" }
    scheduled_for Time.now
    report_span_value 1
    report_span_units 'Days'
    delivered_on Time.now - 2.minutes
    report_type '1.day'
    association :user

    factory :scheduled_report_uncompleted do
      completed false
      report_type 'group_trip'
      association :user
      recur_interval '1.day'
      created_at '2012-03-01 11:00:10'
      recur "1"
      scheduled_for '2012-03-02 11:00:00'
      updated_at '2012-03-01 11:00:10'
      type "ScheduledReport"
      report_data "TITLE"
    end

    factory :scheduled_report_completed do
      completed true
      report_type 'speeding'
      report_name 'Speeding Reports Weekly'
      association :user
      recur_interval '1.week'
      created_at '2012-03-01 12:00:13'
      recur "1"
      scheduled_for '2012-03-02 12:00:00'
      updated_at '2012-03-01 12:00:13'
      type "ScheduledReport"
      report_data "TITLE"
    end
  end
end
