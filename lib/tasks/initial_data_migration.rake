$logger = ActiveSupport::Logger.new(File.join(Rails.root, 'log', 'data_migration.log'))

FILEPATH = '/disk2/export_data'
TARGET_DB = "rsccomm_production"

# Process for RSC migrations.
#
# A mounted disk will be attached to rsc-prod-db1 named disk2.  If some other name is chosen, update the FILEPATH constant
#
# On rsc2-production-ap1 run the rake tasks:
#
# rake db:mysqldump_statements[OLDPRODDBPASSWORD] - copy the output and paste them in rsc-prod-db1 to create a sql file on FILEPATH
# - ublip_prod.sql:  data only dump from tables that do not require any schema changes
# (3m47.194s)
#
# select id, created_at from readings order by id asc limit 20; --this helps you find the right minimum ID
# select max(id) from readings;
#
# rake db:outfiles[554501086,773979594] - outputs a series of select into outfile statements that write to FILEPATH.  requires that the min(id) and max(id) of the production ublip_prod.readings table be passed as params.  The statements can either be pasted directly into the ublip_prod db or output into a outfile.sql file and run from the rsc-prod-db1 server
#
# Idles (3 min 45.63 sec)
# Stops (5 min 49.76 sec)
# Trips (5 min 13.61 sec)
# Reading chunks (4 min 14.90 sec each)
#
# the disk2 mounted disk will be moved from rsc-prod-db1 to rsc2-prod-db1
# replication to ds1 should be turned off, as well as binlogging on db1
#
# on rsc2-prod-db1:
# mysql -uroot -p rsc_fast < /disk2/upblip_prod.sql
# 42m27.666s
#
# on rsc2-prod-ap1
# rake db:migration_insert - this will insert from the infiles into the rsc_fast db and run the cleanup methods for backfilling data.
# 28m28s
#
# rake db:load_readings[554501086,773979594]
# 22 slices took 6:50 hour
# roughly 19 minutes per slice.
#
# rake db:data_backfills

namespace :db do
  desc 'Get the mysqldump statements'
  task :mysqldump_statements do
    #do tables with no datetime fields
    puts "mysqldump --no-create-db --no-create-info --complete-insert ublip_prod devices_users geofence_polypoints locales roles roles_users > #{FILEPATH}/ublip_prod.sql"
  end

  desc 'Create the outfile statements'
  task :outfiles, [:min_reading_id, :max_reading_id] => :environment do |t, args|
    start_time = (Time.now.beginning_of_month - 6.months).to_s(:db)

    #Accounts
    puts %[SELECT id, company, address, city, state, zip, subdomain, CONVERT_TZ(updated_at, "US/PACIFIC", "UTC"), CONVERT_TZ(created_at, "US/PACIFIC", "UTC"), is_verified, IF(is_deleted, #{ProvisionStatus::STATUS_DELETED}, #{ProvisionStatus::STATUS_ACTIVE}), show_runtime, show_statistics, show_maintenance, max_speed, working_hours, notify_on_working_hours, time_zone INTO OUTFILE '#{FILEPATH}/accounts.csv' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\\n' FROM ublip_prod.accounts;]

    #Device Profiles
    puts %[SELECT id, name, speeds, stops, idles, trips, watch_gpio1, watch_gpio2, gpio1_labels, gpio2_labels, runs INTO OUTFILE '#{FILEPATH}/device_profiles.csv' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\\n' FROM ublip_prod.device_profiles;]

    #Devices
    puts %[SELECT id, name, imei, phone_number, recent_reading_id, CONVERT_TZ(created_at, "US/PACIFIC", "UTC"), CONVERT_TZ(updated_at, "US/PACIFIC", "UTC"), provision_status_id, IF(account_id = 0, NULL, account_id), CONVERT_TZ(last_online_time, "US/PACIFIC", "UTC"), online_threshold, icon_id, group_id, is_public, profile_id, last_gpio1, last_gpio2, (CASE gateway_name WHEN 'xirgo' THEN 'xirgo_xt2000' WHEN 'xirgo-wired' THEN 'xirgo_xt2100' ELSE gateway_name END), CONVERT_TZ(speeding_at, "US/PACIFIC", "UTC"), transient, CONVERT_TZ(most_recent_first_movement, "US/PACIFIC", "UTC"), notify_on_first_movement, has_notified_working_hours_violation, total_mileage, latest_gps_reading_id, latest_speed_reading_id, latest_mileage_reading_id, latest_data_reading_id INTO OUTFILE '#{FILEPATH}/devices.csv' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\\n' FROM ublip_prod.devices;]

    #Geofence Violations
    puts %[SELECT device_id, geofence_id, CONVERT_TZ(violation_time, 'US/PACIFIC', 'UTC') INTO OUTFILE '#{FILEPATH}/geofence_violations.csv' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\\n' FROM ublip_prod.geofence_violations;]

    #Geofences
    puts %[SELECT id, name, device_id, CONVERT_TZ(created_at, "US/PACIFIC", "UTC"), CONVERT_TZ(updated_at, "US/PACIFIC", "UTC"), address, fence_num, latitude, longitude, radius, account_id, notify_enter_exit, polygonal, color, area INTO OUTFILE '#{FILEPATH}/geofences.csv' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\\n' FROM ublip_prod.geofences;]

    #Group Devices
    puts %[SELECT id, device_id, group_id, account_id, CONVERT_TZ(created_at, "US/PACIFIC", "UTC") INTO OUTFILE '#{FILEPATH}/group_devices.csv' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\\n' FROM ublip_prod.group_devices;]

    #Group Notifications
    puts %[SELECT id, user_id, group_id, CONVERT_TZ(created_at, "US/PACIFIC", "UTC"), CONVERT_TZ(updated_at, "US/PACIFIC", "UTC") INTO OUTFILE '#{FILEPATH}/group_notifications.csv' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\\n' FROM ublip_prod.group_notifications;]

    #Groups
    puts %[SELECT id, name, image_value, account_id, CONVERT_TZ(created_at, "US/PACIFIC", "UTC"), max_speed INTO OUTFILE '#{FILEPATH}/groups.csv' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\\n' FROM ublip_prod.groups;]

    #Login Messages
    puts %[SELECT id, message, is_active, CONVERT_TZ(created_at, "US/PACIFIC", "UTC"), CONVERT_TZ(updated_at, "US/PACIFIC", "UTC") INTO OUTFILE '#{FILEPATH}/login_messages.csv' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\\n' FROM ublip_prod.login_messages;]

    #Maintenances
    puts %[SELECT id, type_task, device_id, description_task, scheduled_time, mileage, CONVERT_TZ(created_at, "US/PACIFIC", "UTC"), CONVERT_TZ(updated_at, "US/PACIFIC", "UTC"), CONVERT_TZ(alerted_at, "US/PACIFIC", "UTC"), CONVERT_TZ(completed_at, "US/PACIFIC", "UTC"), device_mileage, target_mileage INTO OUTFILE '#{FILEPATH}/maintenances.csv' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\\n' FROM ublip_prod.maintenances;]

    #Movement Alerts
    puts %[SELECT id, device_id, user_id, latitude, longitude, violating_reading_id, CONVERT_TZ(user_notified, "US/PACIFIC", "UTC"), CONVERT_TZ(created_at, "US/PACIFIC", "UTC"), CONVERT_TZ(updated_at, "US/PACIFIC", "UTC") INTO OUTFILE '#{FILEPATH}/movement_alerts.csv' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\\n' FROM ublip_prod.movement_alerts;]

    #Scheduled Reports
    puts %[SELECT id, report_name, user_id, CONVERT_TZ(scheduled_for, "US/PACIFIC", "UTC"), report_span_value, report_span_units, completed, CONVERT_TZ(delivered_on, "US/PACIFIC", "UTC"), recur, recur_interval, report_type, report_params, report_data, CONVERT_TZ(created_at, "US/PACIFIC", "UTC"), CONVERT_TZ(updated_at, "US/PACIFIC", "UTC") INTO OUTFILE '#{FILEPATH}/scheduled_reports.csv' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\\n' FROM ublip_prod.scheduled_reports;]

    #Trip Legs
    puts %[SELECT id, trip_event_id, reading_start_id, reading_stop_id, duration, idle, distance, CONVERT_TZ(created_at, "US/PACIFIC", "UTC"), CONVERT_TZ(updated_at, "US/PACIFIC", "UTC") INTO OUTFILE '#{FILEPATH}/trip_legs.csv' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\\n' FROM ublip_prod.trip_legs WHERE id > 40163285 AND created_at >= '#{start_time}';]

    #Users
    #passwords and salts should just come right over using :clearance_sha1 for devise
    puts %[SELECT id, first_name, last_name, email, encrypted_password, password_salt, CONVERT_TZ(created_at, "US/PACIFIC", "UTC"), CONVERT_TZ(updated_at, "US/PACIFIC", "UTC"), remember_token, account_id, is_master, CONVERT_TZ(last_sign_in_at, "US/PACIFIC", "UTC"), enotify, access_key, default_home_action, default_home_selection, default_map_type, (view_placemarks * 1 + view_geofences * 2) AS view_overlays, reset_password_token, CONVERT_TZ(remember_created_at, "US/PACIFIC", "UTC"), sign_in_count,  CONVERT_TZ(current_sign_in_at, "US/PACIFIC", "UTC"), last_sign_in_ip, current_sign_in_ip, username, domain INTO OUTFILE '#{FILEPATH}/users.csv' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\\n' FROM ublip_prod.users;]

    puts %[SELECT #{generic_events_out_fields('idle_events')} INTO OUTFILE '#{FILEPATH}/idle_events.csv' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\\n' FROM ublip_prod.idle_events WHERE id > 42952137 AND (suspect IS NULL OR suspect = false) AND idle_events.created_at >= '#{start_time}' AND idle_events.device_id IN (SELECT id FROM ublip_prod.devices WHERE provision_status_id = #{ProvisionStatus::STATUS_ACTIVE});]

    puts %[SELECT #{generic_events_out_fields('stop_events')} INTO OUTFILE '#{FILEPATH}/stop_events.csv' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\\n' FROM ublip_prod.stop_events WHERE id > 45817848 AND (suspect IS NULL OR suspect = false) AND stop_events.created_at >= '#{start_time}' AND stop_events.device_id IN (SELECT id FROM ublip_prod.devices WHERE provision_status_id = #{ProvisionStatus::STATUS_ACTIVE});]

    puts %[SELECT trip_events.id, trip_events.device_id, trip_events.reading_start_id AS start_reading_id, trip_events.reading_stop_id AS end_reading_id, (trip_events.duration * 60) AS duration, trip_events.distance, (trip_events.idle * 60) AS idle_duration, trip_events.suspect INTO OUTFILE '#{FILEPATH}/trip_events.csv' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\\n' FROM ublip_prod.trip_events WHERE id > 34579406 AND (trip_events.suspect IS NULL OR trip_events.suspect = false) AND trip_events.created_at >= '#{start_time}' AND trip_events.device_id IN (SELECT id FROM ublip_prod.devices WHERE provision_status_id = #{ProvisionStatus::STATUS_ACTIVE});]

    STEP = 10000000
    min_id = args[:min_reading_id].to_i
    max_id = args[:max_reading_id].to_i
    (min_id..max_id).step(STEP) do |id|
      puts %[SELECT #{readings_out_fields} INTO OUTFILE '#{FILEPATH}/readings_#{id}.csv' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\\n' FROM ublip_prod.readings WHERE readings.id >= #{id} AND readings.id < #{id + STEP} AND readings.device_id IN (SELECT id FROM ublip_prod.devices WHERE provision_status_id = #{ProvisionStatus::STATUS_ACTIVE});]
    end
  end

  desc 'Compress all table schemas'
  task compress_all: :environment do
    [
      "ALTER TABLE accounts ROW_FORMAT=COMPRESSED",
      "ALTER TABLE device_profiles ROW_FORMAT=COMPRESSED",
      "ALTER TABLE devices ROW_FORMAT=COMPRESSED",
      "ALTER TABLE devices_users ROW_FORMAT=COMPRESSED",
      "ALTER TABLE geofence_polypoints ROW_FORMAT=COMPRESSED",
      "ALTER TABLE geofence_violations ROW_FORMAT=COMPRESSED",
      "ALTER TABLE geofences ROW_FORMAT=COMPRESSED",
      "ALTER TABLE group_devices ROW_FORMAT=COMPRESSED",
      "ALTER TABLE group_notifications ROW_FORMAT=COMPRESSED",
      "ALTER TABLE groups ROW_FORMAT=COMPRESSED",
      "ALTER TABLE idle_events ROW_FORMAT=COMPRESSED",
      "ALTER TABLE locales ROW_FORMAT=COMPRESSED",
      "ALTER TABLE locations ROW_FORMAT=COMPRESSED",
      "ALTER TABLE login_messages ROW_FORMAT=COMPRESSED",
      "ALTER TABLE maintenances ROW_FORMAT=COMPRESSED",
      "ALTER TABLE movement_alerts ROW_FORMAT=COMPRESSED",
      "ALTER TABLE offline_events ROW_FORMAT=COMPRESSED",
      "ALTER TABLE readings ROW_FORMAT=COMPRESSED",
      "ALTER TABLE roles ROW_FORMAT=COMPRESSED",
      "ALTER TABLE roles_users ROW_FORMAT=COMPRESSED",
      "ALTER TABLE scheduled_reports ROW_FORMAT=COMPRESSED",
      "ALTER TABLE schema_migrations ROW_FORMAT=COMPRESSED",
      "ALTER TABLE sessions ROW_FORMAT=COMPRESSED",
      "ALTER TABLE stop_events ROW_FORMAT=COMPRESSED",
      "ALTER TABLE trip_events ROW_FORMAT=COMPRESSED",
      "ALTER TABLE trip_legs ROW_FORMAT=COMPRESSED",
      "ALTER TABLE users ROW_FORMAT=COMPRESSED"
    ].each do |cmd|
      run_sql_command('All Tables') do
        cmd
      end
    end
  end

  desc 'Read in infiles and do backfill and other cleanup'
  task migration_insert: :environment do |t, args|
    #Accounts
    run_sql_command("Accounts") do
      %[LOAD DATA INFILE '#{FILEPATH}/accounts.csv' INTO TABLE #{TARGET_DB}.accounts FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' (id, company, address, city, state, zip, subdomain, updated_at, created_at, is_verified, provision_status_id, show_runtime, show_statistics, show_maintenance, max_speed, working_hours, notify_on_working_hours, time_zone)]
    end

    #Device Profiles
    run_sql_command("DeviceProfiles") do
      %[LOAD DATA INFILE '#{FILEPATH}/device_profiles.csv' INTO TABLE #{TARGET_DB}.device_profiles FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' (id, name, speeds, stops, idles, trips, watch_gpio1, watch_gpio2, gpio1_labels, gpio2_labels, runs)]
    end

    #Devices
    run_sql_command("Devices") do
      %[LOAD DATA INFILE '#{FILEPATH}/devices.csv' INTO TABLE #{TARGET_DB}.devices FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' (id, name, imei, phone_number, last_reading_id, created_at, updated_at, provision_status_id, account_id, last_online_time, offline_threshold, icon_id, group_id, is_public, profile_id, last_gpio1, last_gpio2, gateway_name, speeding_at, transient, most_recent_first_movement, notify_on_first_movement, has_notified_working_hours_violation, total_mileage, last_gps_reading_id, last_speed_reading_id, last_mileage_reading_id, last_data_reading_id)]
    end

    #Geofence Violations
    run_sql_command("Geofence Violations") do
      %[LOAD DATA INFILE '#{FILEPATH}/geofence_violations.csv' INTO TABLE #{TARGET_DB}.geofence_violations FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' (device_id, geofence_id, violation_time)]
    end

    #Geofences
    run_sql_command("Geofences") do
      %[LOAD DATA INFILE '#{FILEPATH}/geofences.csv' INTO TABLE #{TARGET_DB}.geofences FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' (id, name, device_id, created_at, updated_at, address, fence_num, latitude, longitude, radius, account_id, notify_enter_exit, polygonal, color, area)]
    end

    #Group Devices
    run_sql_command("Group Devices") do
      %[LOAD DATA INFILE '#{FILEPATH}/group_devices.csv' INTO TABLE #{TARGET_DB}.group_devices FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' (id, device_id, group_id, account_id, created_at)]
    end

    #Group Notifications
    run_sql_command("Group Notifications") do
      %[LOAD DATA INFILE '#{FILEPATH}/group_notifications.csv' INTO TABLE #{TARGET_DB}.group_notifications FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' (id, user_id, group_id, created_at, updated_at)]
    end

    #Groups
    run_sql_command("Groups") do
      %[LOAD DATA INFILE '#{FILEPATH}/groups.csv' INTO TABLE #{TARGET_DB}.groups FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' (id, name, image_value, account_id, created_at, max_speed)]
    end

    #Login Messages
    run_sql_command("Login Messages") do
      %[LOAD DATA INFILE '#{FILEPATH}/login_messages.csv' INTO TABLE #{TARGET_DB}.login_messages FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' (id, message, is_active, created_at, updated_at)]
    end

    #Maintenances
    run_sql_command("Maintenances") do
      %[LOAD DATA INFILE '#{FILEPATH}/maintenances.csv' INTO TABLE #{TARGET_DB}.maintenances FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' (id, type_task, device_id, description_task, scheduled_time, mileage, created_at, updated_at, alerted_at, completed_at, device_mileage, target_mileage)]
    end

    #Movement Alerts
    run_sql_command("Movement Alerts") do
      %[LOAD DATA INFILE '#{FILEPATH}/movement_alerts.csv' INTO TABLE #{TARGET_DB}.movement_alerts FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' (id, device_id, user_id, latitude, longitude, violating_reading_id, user_notified, created_at, updated_at)]
    end

    #Scheduled Reports
    run_sql_command("Scheduled Reports") do
      %[LOAD DATA INFILE '#{FILEPATH}/scheduled_reports.csv' INTO TABLE #{TARGET_DB}.scheduled_reports FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' (id, report_name, user_id, scheduled_for, report_span_value, report_span_units, completed, delivered_on, recur, recur_interval, report_type, report_params, report_data, created_at, updated_at)]
    end

    #Trip Legs
    run_sql_command("Trip Legs") do
      %[LOAD DATA INFILE '#{FILEPATH}/trip_legs.csv' INTO TABLE #{TARGET_DB}.trip_legs FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' (id, trip_event_id, reading_start_id, reading_stop_id, duration, idle, distance, created_at, updated_at)]
    end

    #Users
    #passwords and salts should just come right over using :clearance_sha1 for devise
    run_sql_command("Users") do
      %[LOAD DATA INFILE '#{FILEPATH}/users.csv' INTO TABLE #{TARGET_DB}.users FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' (id, first_name, last_name, email, encrypted_password, password_salt, created_at, updated_at, remember_token, account_id, is_master, last_sign_in_at, enotify, access_key, default_home_action, default_home_selection, default_map_type, view_overlays, reset_password_token, remember_created_at, sign_in_count, current_sign_in_at, last_sign_in_ip, current_sign_in_ip, username, domain)]
    end

    ["idle_events", "stop_events"].each do |tablename|
      run_sql_command("INFILE #{tablename}") do
        %[LOAD DATA INFILE '#{FILEPATH}/#{tablename}.csv' INTO TABLE #{TARGET_DB}.#{tablename}  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' (#{generic_events_in_fields(tablename)})]
      end
    end
    run_sql_command("INFILE trip_events") do
      %[LOAD DATA INFILE '#{FILEPATH}/trip_events.csv' INTO TABLE #{TARGET_DB}.trip_events  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' (id, device_id, start_reading_id, end_reading_id, duration, distance, idle_duration, suspect, started_at, ended_at, start_latitude, start_longitude, end_latitude, end_longitude)]
    end
  end

  desc 'load the readings'
  task :load_readings, [:min_reading_id, :max_reading_id] => :environment do |t, args|
    STEP = 10000000
    min_id = args[:min_reading_id].to_i
    max_id = args[:max_reading_id].to_i
    (min_id..max_id).step(STEP) do |id|
      run_sql_command("Infile Reading #{id}") do
        %[LOAD DATA INFILE '#{FILEPATH}/readings_#{id}.csv' INTO TABLE #{TARGET_DB}.readings  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n' (#{readings_in_fields})]
      end
    end
  end

  desc 'backfill the data'
  task data_backfills: :environment do
    run_sql_command("Set radius to minimum for geofences") do
      "UPDATE #{TARGET_DB}.geofences SET radius = 0.25 WHERE radius IS NULL"
    end

    run_sql_command("Update shape type for geofences") do
      "UPDATE #{TARGET_DB}.geofences SET shape_type = 1 WHERE polygonal = 1"
    end

    run_sql_command("Set trip_events.idle_duration to null where negative") do
      "UPDATE #{TARGET_DB}.trip_events SET idle_duration = NULL WHERE idle_duration < 0"
    end

    update_spanning_events

    update_trip_events_calculated_values

    backfill_events_in_devices
  end

  def backfill_events_in_devices
    start = Time.now

    stops = StopEvent.where('duration IS NULL').order('started_at DESC')
    trips = TripEvent.where('duration IS NULL').order('started_at DESC')
    idles = IdleEvent.where('duration IS NULL').order('started_at DESC')

    Device.provisioned.find_each do |device|
      device.open_trip_event = trips.detect { |trip| trip.device_id == device.id }
      device.open_stop_event = stops.detect { |stop| stop.device_id == device.id }
      device.open_idle_event = idles.detect { |idle| idle.device_id == device.id }
      device.save! validate: false if device.changed?
    end

    #Device.provisioned.find_each do |device|
    #  device.open_trip_event = device.trip_events.where('duration IS NULL').order("started_at DESC").first
    #  device.open_stop_event = device.stop_events.where('duration IS NULL').order("started_at DESC").first
    #  device.open_idle_event = device.idle_events.where('duration IS NULL').order("started_at DESC").first
    #  device.save! validate: false
    #end
    $logger.info "Events in Devices: #{Time.now - start}"
  end

  #this is to backfill the trip_events and total_mileage values.
  def update_trip_events_calculated_values
    start = Time.now
    TripEvent.where("distance is null AND duration is null and id > 34579406").find_each do |trip|
      if trip.start_reading.nil?
        trip.delete
        next
      end

      trip.idle_duration = trip.idle_events.sum(:duration)

      trip.distance = 0.0
      previous_r = trip.start_reading
      trip.intermediate_readings.each do |r|
        trip.distance += previous_r.distance_to(r)
        previous_r = r
      end
      trip.distance += previous_r.distance_to(trip.end_reading) if trip.end_reading

      trip.save!

      device = trip.device

      # apply this mileage to the device
      device.update_attributes(total_mileage: (device.total_mileage.to_f + trip.distance))
    end
    $logger.info "TripEvents Calculated Values: #{Time.now - start}"
  end

  def update_spanning_events
    #Update the events
    start = Time.now
    ActiveRecord::Base.connection.execute "UPDATE #{TARGET_DB}.trip_events,#{TARGET_DB}.readings SET started_at=recorded_at, start_latitude = latitude, start_longitude = longitude WHERE start_reading_id = readings.id AND start_latitude IS NULL and #{TARGET_DB}.trip_events.id > 34579406"
    $logger.info "Xtra TE: #{Time.now - start}"
    #["idle_events", "stop_events", "trip_events"].each do |tablename|
    #  start = Time.now
    #  ActiveRecord::Base.connection.execute "UPDATE #{TARGET_DB}.#{tablename},#{TARGET_DB}.readings SET ended_at = recorded_at, end_latitude = latitude, end_longitude = longitude WHERE end_reading_id = readings.id AND ended_at IS NULL"
    #  $logger.info "#{tablename}: #{Time.now - start}"
    #end
    start = Time.now
    ActiveRecord::Base.connection.execute "UPDATE #{TARGET_DB}.idle_events,#{TARGET_DB}.readings SET ended_at = recorded_at, end_latitude = latitude, end_longitude = longitude WHERE end_reading_id = readings.id AND ended_at IS NULL and #{TARGET_DB}.idle_events.id > 42952137"
    $logger.info "idle_events: #{Time.now - start}"
    start = Time.now
    ActiveRecord::Base.connection.execute "UPDATE #{TARGET_DB}.stop_events,#{TARGET_DB}.readings SET ended_at = recorded_at, end_latitude = latitude, end_longitude = longitude WHERE end_reading_id = readings.id AND ended_at IS NULL and #{TARGET_DB}.stop_events.id > 45817848"
    $logger.info "stop_events: #{Time.now - start}"
    start = Time.now
    ActiveRecord::Base.connection.execute "UPDATE #{TARGET_DB}.trip_events,#{TARGET_DB}.readings SET ended_at = recorded_at, end_latitude = latitude, end_longitude = longitude WHERE end_reading_id = readings.id AND ended_at IS NULL and #{TARGET_DB}.trip_events.id > 34579406"
    $logger.info "trip_events: #{Time.now - start}"
  end

  def generic_events_in_fields(table)
    "id, started_at, device_id, duration, suspect, start_reading_id, end_reading_id, start_latitude, end_latitude, start_longitude, end_longitude"
  end

  def generic_events_out_fields(table)
    "#{table}.id, CONVERT_TZ(#{table}.created_at, 'US/PACIFIC', 'UTC') AS started_at, #{table}.device_id, (#{table}.duration * 60) AS duration, #{table}.suspect, #{table}.reading_id AS start_reading_id, IF(#{table}.duration IS NULL, NULL, reading_id) AS end_reading_id, #{table}.latitude AS start_latitude, IF(#{table}.duration IS NULL, NULL, latitude) AS end_latitude, #{table}.longitude AS start_longitude, IF(#{table}.duration IS NULL, NULL, longitude) AS end_longitude"
  end

  def readings_in_fields
    "id, recorded_at, updated_at, altitude, device_id, direction, geofence_event_type, geofence_id, ignition, latitude, longitude, speed, gateway_event_type, event_type, gpio1, gpio2, admin_name1, power_up, note"
  end

  def readings_out_fields
    "readings.id, CONVERT_TZ(readings.created_at, 'US/PACIFIC', 'UTC') AS recorded_at, CONVERT_TZ(readings.updated_at, 'US/PACIFIC', 'UTC'), readings.altitude, readings.device_id, readings.direction, IF(readings.geofence_event_type = '', NULL, readings.geofence_event_type), IF(readings.geofence_id = 0, NULL, readings.geofence_id), readings.ignition, readings.latitude, readings.longitude, readings.speed, readings.event_type AS gateway_event_type, (CASE readings.event_type WHEN 'Battery Low' THEN #{EventTypes::LowBattery} WHEN 'delayed Battery Low' THEN #{EventTypes::LowBattery} WHEN 'delayed Heartbeat' THEN #{EventTypes::Heartbeat} WHEN 'Heartbeat' THEN #{EventTypes::Heartbeat} WHEN 'delayed Speed Alert' THEN #{EventTypes::Speed} WHEN 'Speed Alert' THEN #{EventTypes::Speed} WHEN 'engine off' THEN #{EventTypes::EngineOff} WHEN 'engine on' THEN #{EventTypes::EngineOn} WHEN 'Low Battery Set' THEN #{EventTypes::LowBattery} WHEN 'delayed speeding' THEN #{EventTypes::Speed} WHEN 'speeding' THEN #{EventTypes::Speed} WHEN 'Ignition On' THEN #{EventTypes::Ignition} WHEN 'stop' THEN #{EventTypes::Stop} WHEN 'idle' THEN #{EventTypes::Idling} WHEN 'GPS Lock' THEN #{EventTypes::PlugIn} WHEN 'Requested Position' THEN #{EventTypes::Requested} ELSE NULL END) AS event_type, readings.gpio1, readings.gpio2, readings.admin_name1, readings.power_up, readings.note"
  end

  def run_sql_command(model)
    @config ||= Rails.configuration.database_configuration[Rails.env].merge("username" => "root")

    sql = yield

    $logger.info "#{model} started at #{Time.now.utc}"

    ActiveRecord::Base.establish_connection(@config).connection.execute(sql)

    $logger.info "#{model} ended at #{Time.now.utc}"
  end
end
