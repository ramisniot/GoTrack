FactoryGirl.define do
  sequence(:thing_token) { |n| "token-#{n}" }

  factory :device do
    sequence(:imei) { |n| (n + Time.now.to_i).to_s.ljust(15, '0') }
    sequence(:name) { |n| "Device_#{n}" }
    thing_token { FactoryGirl.generate(:thing_token) }
    last_online_time Time.now.utc.to_s(:db)
    offline_threshold 90
    provision_status_id ProvisionStatus::STATUS_ACTIVE
    association :account, factory: :paris

    factory :inactive_device do
      provision_status_id ProvisionStatus::STATUS_INACTIVE
    end

    factory :active_device do
      provision_status_id ProvisionStatus::STATUS_ACTIVE
    end

    factory :d_one do
      name 'd_one'
      provision_status_id ProvisionStatus::STATUS_INACTIVE
    end

    factory :d_two do
      name 'Device_two'
      provision_status_id ProvisionStatus::STATUS_ACTIVE
    end

    factory :d_three do
      provision_status_id ProvisionStatus::STATUS_INACTIVE
    end

    factory :d_four do
      provision_status_id ProvisionStatus::STATUS_ACTIVE
    end

    factory :d_five_deleted do
      provision_status_id ProvisionStatus::STATUS_DELETED
    end

    factory :d_stops do
      provision_status_id ProvisionStatus::STATUS_ACTIVE
      name 'stop_events_device'
    end

    factory :reading_mailer_device do
      name 'reading_mailer_device'
      provision_status_id ProvisionStatus::STATUS_INACTIVE
    end

    factory :device_a do
      name 'test device'
      imei '16561237'
      association :account, factory: :account_a
      provision_status_id ProvisionStatus::STATUS_ACTIVE
    end

    factory :device_two do
      association :account, factory: :account_a
      name 'Dev T 2'
      imei '897654165897534'
      provision_status_id ProvisionStatus::STATUS_ACTIVE
    end
  end
end
