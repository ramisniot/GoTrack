FactoryGirl.define do
  factory :maintenance do
    association :device
    mileage 10
    target_mileage 20
    description_task 'Maintenance Test'
    type_task 1

    factory :mileage_maintenance do
      type_task 1
    end

    factory :schedule_maintenance do
      type_task 0
    end

    factory :completed_maintenance do
      completed_at 1.day.ago
    end
  end
end
