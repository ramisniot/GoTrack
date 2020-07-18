FactoryGirl.define do
  factory :location do
    full_address 'Full Address'
    city 'Dallas'
    country 'USA'
    street 'NW Chipman Rd'
    street_number '20'
    state_abbr 'TX'

    factory :location1 do
      latitude 36.1623674119938
      longitude -86.80320477978977
      full_address '2594 Charlotte Ave, Nashville-Davidson Metropolitan Government (balance) TN'
      street 'Charlotte'
      city 'Nashville-Davidson Metropolitan Government (balance)'
      country 'USA'
      dir_suffix 'Ave'
      house_number '2594'
      state_abbr 'TN'
    end
  end
end