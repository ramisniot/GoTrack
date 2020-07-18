FactoryGirl.define do
  sequence :user_name do |n|
    "John#{n}"
  end

  factory :user do
    first_name { FactoryGirl.generate(:user_name) }
    last_name 'Smith'
    password 'testing'
    email       { "#{first_name}@gotrack.com".downcase }
    association :account, factory: :test_account
    roles       [:superadmin]

    factory :test_superadmin do
      first_name    'test_superadmin'
    end

    factory :test_admin do
      first_name    'test_admin'
      time_zone "Central Time (US & Canada)"
    end


    factory :test_user do
      first_name    'test_user'
    end

    factory :test_master do
      first_name    'test_master'
    end

    factory :test_manager do
      first_name    'test_manager'
    end

    factory :emp_admin do
      first_name    'emp_admin'
    end

    factory :emp_master_dist do
      first_name    'emp_master_dist'
    end
  end

end
