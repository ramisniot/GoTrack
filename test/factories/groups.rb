FactoryGirl.define do
  sequence :group_name do |n|
    "Group#{n}"
  end

  factory :group do
    image_value 1
    name { FactoryGirl.generate(:group_name) }
    account { |account| account.association(:account) }

    factory :group1 do
      name 'group1'
    end
  end
end