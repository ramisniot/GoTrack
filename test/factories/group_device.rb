FactoryGirl.define do
  factory :group_device do |gd|
    gd.group { |group| group.association(:group) }
    gd.device { |device| device.association(:device) }
  end
end