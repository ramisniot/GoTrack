FactoryGirl.define do
  factory :one_time_report do
    association :user
    report_type 'state_mileage'
    created_at '2012-03-01 12:00:13'
    scheduled_for '2012-03-02 12:00:00'
    updated_at '2012-03-01 12:00:13'
    recur "0"
    type "OneTimeReport"

    factory :one_time_report_uncompleted do
      completed false
      report_name 'Live State Mileage Report Incomplete'
    end

    factory :one_time_report_completed do
      completed true
      report_name 'Live State Mileage Report Complete'
    end
  end
end
