FactoryGirl.define do
  factory :placemark do
    association :account, factory: :test_account

    factory :placemark_1 do
      name 'Dallas'
      latitude 32.8029550000
      longitude -96.7699230000
      address "32.8029550000,-96.7699230000"
    end
    factory :placemark_2 do
      name 'Waco'
      latitude 31.5493330000
      longitude -97.1466695000
      address "31.5493330000,-97.1466695000"
    end
  end
end
