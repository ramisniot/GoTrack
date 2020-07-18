FactoryGirl.define do
  factory :group_notification do |gn|
    gn.group { |group| group.association(:group) }
    gn.user { |user| user.association(:user) }
  end
end