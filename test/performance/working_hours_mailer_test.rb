require 'test_helper'
require 'rails/performance_test_help'

class WorkingHoursMailerTest < ActionDispatch::PerformanceTest
  # TODO revisit when we can replace mysqlimport ...
  # self.profile_options = self.profile_options.merge({ runs: (self.profile_options ? 5 : 1), metrics: [:memory, :process_time] })
  #
  # def setup
  #   load_data(Account) unless Account.count == 2133
  #   load_data(Device) unless Device.count == 5508
  #   load_data(Reading) unless Reading.count == 144177
  #   load_data(User) unless User.count == 589
  #   if NotificationState.count == 0
  #     NotificationState.create(last_reading_id: 0)
  #   else
  #     NotificationState.first.update_attributes(last_reading_id: 0)
  #   end
  # end
  #
  # def test_working_hours
  #   logger = Rails.logger
  #   account = Account.find 6 # Use an account because iterating over all accounts takes too long
  #   while Reading.last.id > NotificationState.instance.last_reading_id
  #     NotificationState.instance.begin_reading_bounds
  #     puts 'Processing readings matching: ' + NotificationState.instance.reading_bounds_condition.to_s
  #     #Account.where(notify_on_working_hours: true).each do |account|
  #     Reading.where(NotificationState.instance.reading_bounds_condition).where(device_id: Device.where(account_id: account.id).collect(&:id)).each do |reading|
  #       reading.device.update_attribute(:recent_reading_id, reading.id)
  #     end
  #     begin
  #       last_readings = {}
  #       Time.zone = account.time_zone.blank? ? 'Central Time (US & Canada)' : account.time_zone
  #
  #       wh = account.working_hours
  #
  #       #only pull the devices who haven't already sent a non-working-hours violation
  #       devices = Device.where(account_id: account.id, has_notified_working_hours_violation: false)
  #       device_ids = devices.collect(&:id)
  #
  #       readings = Reading.where(NotificationState.instance.reading_bounds_condition).where(device_id: account.devices.collect(&:id)).order(:id)
  #       readings.each do |reading|
  #         last_time = reading.created_at.in_time_zone
  #         hour_minute = last_time.strftime('%H%M') # extract hour_minute
  #         if wh[last_time.wday].blank? || wh[last_time.wday + 7].blank? || hour_minute < wh[last_time.wday] || hour_minute > wh[last_time.wday + 7] # Test if last reading outisde batch is inside working hours
  #           if reading.speed > 0 && device_ids.include?(reading.device_id) # keep track of devices notified, so we only alert each one 1 time
  #             device_ids.delete(reading.device_id) #this device has been notified, don't do it again
  #             #Notification.create(device_id: reading.device_id, notification_type: "working_hours")
  #             devices.find { |d| d.id == reading.device_id }.update_attribute(:has_notified_working_hours_violation, true) #a flag to prevent re-sending
  #           end
  #           last_readings.delete(reading.device_id)
  #         else
  #           last_readings[reading.device_id] = true
  #         end
  #       end
  #
  #       # cleanup -  UNflag any device which is currently WITHIN working hours
  #       account.devices.where(id: last_readings.keys, has_notified_working_hours_violation: true).each do |device|
  #         device.update_attribute(:has_notified_working_hours_violation, false) # clear the flag in preparation for a future violation
  #       end
  #       last_readings = nil
  #     rescue
  #       logger.info "ERROR: #{$!}"
  #       $!.backtrace.each { |line| logger.info line }
  #     end
  #     #end
  #     NotificationState.instance.end_reading_bounds
  #   end
  # end
  #
  # def teardown
  #   NotificationState.forget # Reset notifier
  #   load_data(Device) # Reload previous state of Devices (All flags false)
  # end
  #
  # private
  #
  # def load_data(model)
  #   db = Rails.configuration.database_configuration[Rails.env]['database']
  #   user = Rails.configuration.database_configuration[Rails.env]['username']
  #   password = Rails.configuration.database_configuration[Rails.env]['password']
  #   puts 'Attempting to load test data to ' + model.table_name
  #   unless system("mysqlimport --delete --fields-optionally-enclosed-by=\"\\\"\" --fields-terminated-by=, --user=#{user} --password=#{password} --local #{db} #{Rails.root}/test/performance_fixtures/#{model.table_name}.csv")
  #     puts 'ERROR: mysqlimport command failed. Please make sure you have mysqlimport installed. The test would take too long trying to load the data otherwise'
  #   end
  # end
end
