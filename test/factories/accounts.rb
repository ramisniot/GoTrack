FactoryGirl.define do
  sequence :company_name do |n|
    "Company#{n}"
  end

  factory :account do
    company { FactoryGirl.generate(:company_name) }
    subdomain { company }

    is_verified true
    sequence(:zip) {|number| '%05d' % number}
    sequence(:address) {|n| "address#{n}"}
    provision_status_id ProvisionStatus::STATUS_ACTIVE

    factory :test_poc do
      company 'test_poc'
    end

    factory :test_account do
      company 'test_account'
    end

    factory :emporious do
      company 'emporious'
    end

    factory :paris do
      company 'paris'
    end

    factory :account_a do
      company 'test_A'
    end

    factory :monkey_account do
      company 'company-1'
      subdomain 'monkey'
      address '123 Foo St'
      zip 12345
      collection_token 'token-1'
    end
  end
end
