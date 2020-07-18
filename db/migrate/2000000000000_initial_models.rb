class InitialModels < ActiveRecord::Migration
  def self.up
    create_table :accounts, force: true do |t|
      t.string   :company,                   limit: 75
      t.string   :address,                   limit: 50
      t.string   :city,                      limit: 50
      t.string   :state,                     limit: 25
      t.string   :zip,                       limit: 15
      t.string   :subdomain,                 limit: 100
      t.datetime :updated_at
      t.datetime :created_at
      t.boolean  :is_verified,               default: false
      t.boolean  :show_runtime,              default: false
      t.boolean  :show_statistics,           default: false
      t.boolean  :show_maintenance,          default: false
      t.integer  :max_speed
      t.integer  :speed_threshold
      t.integer  :provision_status_id,       default: 1
      t.text     :working_hours
      t.boolean  :notify_on_working_hours
      t.string   :time_zone
      t.boolean  :show_state_mileage_report, default: false
    end

    create_table :background_reports, force: true do |t|
      t.string   :report_name
      t.integer  :user_id
      t.datetime :scheduled_for
      t.integer  :report_span_value
      t.string   :report_span_units
      t.integer  :report_span
      t.boolean  :completed,                 default: false
      t.datetime :delivered_on
      t.boolean  :recur
      t.string   :recur_interval
      t.string   :report_type
      t.string   :report_params
      t.text     :report_data,              limit: 16777215
      t.datetime :created_at
      t.datetime :updated_at
      t.datetime :from
      t.datetime :to
      t.string   :type
    end

    add_index :background_reports, [:completed, :scheduled_for], name: :scheduled_reports_by_due_date, using: :btree

    create_table :device_profiles, force: true do |t|
      t.string  :name,                         null: false
      t.boolean :speeds,       default: false, null: false
      t.boolean :stops,        default: false, null: false
      t.boolean :idles,        default: false, null: false
      t.boolean :runs,         default: false, null: false
      t.boolean :watch_gpio1,  default: false, null: false
      t.boolean :watch_gpio2,  default: false, null: false
      t.string  :gpio1_labels
      t.string  :gpio2_labels
      t.boolean :trips,        default: false, null: false
    end

    create_table :devices, force: true do |t|
      t.string   :name,                                 limit: 75
      t.string   :imei,                                 limit: 30
      t.string   :phone_number,                         limit: 20
      t.integer  :recent_reading_id,                               default: 0
      t.datetime :created_at
      t.datetime :updated_at
      t.integer  :provision_status_id,                  limit: 2,  default: 0
      t.integer  :account_id,                                      default: 0
      t.datetime :last_online_time
      t.integer  :icon_id,                                         default: 1
      t.integer  :group_id
      t.integer  :is_public,                                       default: 0
      t.integer  :profile_id,                                      default: 1,     null: false
      t.boolean  :last_gpio1
      t.boolean  :last_gpio2
      t.string   :gateway_name
      t.datetime :speeding_at
      t.boolean  :transient
      t.datetime :most_recent_first_movement
      t.boolean  :notify_on_first_movement
      t.boolean  :has_notified_working_hours_violation,            default: false
      t.float    :total_mileage,                        limit: 24, default: 0.0
      t.integer  :last_gps_reading_id
      t.integer  :last_speed_reading_id
      t.integer  :last_geofence_reading_id
      t.integer  :last_rg_reading_id
      t.integer  :last_reading_id
      t.integer  :last_data_reading_id
      t.integer  :last_mileage_reading_id
      t.float    :battery_level_threshold,              limit: 24
      t.integer  :last_battery_level_reading_id
      t.integer  :open_trip_event_id
      t.integer  :open_stop_event_id
      t.integer  :open_idle_event_id
      t.integer  :last_trip_event_id
      t.integer  :last_stop_event_id
      t.integer  :last_idle_event_id
      t.boolean  :last_ignition_state
      t.integer  :offline_threshold,                               default: 6480
      t.string   :device_type
      t.datetime :last_offline_event_at
      t.boolean  :notify_on_gps_unit_power_events,                 default: true
      t.integer  :idle_threshold
    end

    add_index :devices, [:account_id], name: :index_devices_account_id, using: :btree
    add_index :devices, [:imei], name: :imei, unique: true, using: :btree

    create_table :devices_users, force: true do |t|
      t.integer :device_id
      t.integer :user_id
    end

    create_table :digital_sensor_readings, force: true do |t|
      t.integer  :reading_id
      t.integer  :digital_sensor_id
      t.boolean  :value
      t.datetime :recorded_at
      t.datetime :received_at
      t.datetime :created_at
      t.datetime :updated_at
    end

    create_table :digital_sensors, force: true do |t|
      t.integer  :address
      t.string   :name
      t.string   :high_label
      t.string   :low_label
      t.integer  :notification_type
      t.integer  :device_id
      t.datetime :created_at
      t.datetime :updated_at
      t.integer  :last_digital_sensor_reading_id
    end

    create_table :geofence_polypoints, force: true do |t|
      t.integer :geofence_id
      t.decimal :latitude,    precision: 15, scale: 10
      t.decimal :longitude,   precision: 15, scale: 10
      t.integer :order,                                 default: 1
    end

    create_table :geofence_violations, force: true do |t|
      t.integer  :device_id,      null: false
      t.integer  :geofence_id,    null: false
      t.datetime :violation_time
    end

    create_table :geofences, force: true do |t|
      t.string   :name,              limit: 30
      t.integer  :device_id
      t.datetime :created_at
      t.datetime :updated_at
      t.string   :address
      t.integer  :fence_num
      t.decimal  :latitude,                     precision: 15, scale: 10
      t.decimal  :longitude,                    precision: 15, scale: 10
      t.float    :radius,            limit: 24
      t.integer  :account_id
      t.boolean  :notify_enter_exit,                                      default: false,  null: false
      t.boolean  :polygonal,                                              default: false
      t.string   :color,                                                  default: "blue"
      t.float    :area,              limit: 24
      t.integer  :shape_type,                                             default: 0,      null: false
      t.decimal  :tl_lat,                       precision: 15, scale: 10
      t.decimal  :tl_lng,                       precision: 15, scale: 10
      t.decimal  :br_lat,                       precision: 15, scale: 10
      t.decimal  :br_lng,                       precision: 15, scale: 10
      t.integer  :group_id
    end

    add_index :geofences, [:account_id], name: :index_geofences_on_account_id, using: :btree
    add_index :geofences, [:device_id], name: :index_geofences_on_device_id, using: :btree

    create_table :group_devices, force: true do |t|
      t.integer  :device_id
      t.integer  :group_id
      t.integer  :account_id
      t.datetime :created_at
    end

    create_table :group_notifications, force: true do |t|
      t.integer  :user_id
      t.integer  :group_id
      t.datetime :created_at
      t.datetime :updated_at
    end

    create_table :groups, force: true do |t|
      t.string   :name
      t.integer  :image_value
      t.integer  :account_id
      t.datetime :created_at
      t.integer  :max_speed
    end

    create_table :idle_events,force: true do |t|
      t.integer  :start_reading_id
      t.integer  :end_reading_id
      t.integer  :duration
      t.integer  :device_id
      t.datetime :created_at
      t.datetime :updated_at
      t.datetime :started_at,                                             null: false
      t.datetime :ended_at
      t.boolean  :suspect
      t.decimal  :start_latitude,               precision: 15, scale: 10
      t.decimal  :start_longitude,              precision: 15, scale: 10
      t.decimal  :end_latitude,                 precision: 15, scale: 10
      t.decimal  :end_longitude,                precision: 15, scale: 10
      t.integer  :start_location_id
      t.integer  :end_location_id
      t.float    :average_speed,     limit: 24
      t.float    :max_speed,         limit: 24
    end

    add_index :idle_events, [:device_id, :created_at, :suspect], name: :index_idle_events_on_device_id_and_created_at_and_suspect, using: :btree
    add_index :idle_events, [:device_id, :started_at], name: :index_idle_events_on_device_id_and_started_at, using: :btree

    create_table :locales, force: true do |t|
      t.string :code
      t.string :name
    end

    create_table :locations, force: true do |t|
      t.decimal  :latitude,                precision: 15, scale: 10
      t.decimal  :longitude,               precision: 15, scale: 10
      t.string   :street
      t.string   :city
      t.string   :state_name
      t.string   :zip
      t.string   :country
      t.string   :full_address
      t.string   :district
      t.string   :province
      t.string   :county
      t.string   :dir_prefix
      t.string   :dir_suffix
      t.string   :house_number
      t.string   :street_type
      t.string   :street_number
      t.string   :state_abbr
      t.datetime :created_at,                                        null: false
      t.datetime :updated_at
    end

    create_table :login_messages, force: true do |t|
      t.text     :message
      t.boolean  :is_active
      t.datetime :created_at
      t.datetime :updated_at
    end

    create_table :maintenances, force: true do |t|
      t.integer  :type_task
      t.integer  :device_id
      t.string   :description_task
      t.date     :scheduled_time
      t.integer  :mileage
      t.datetime :created_at
      t.datetime :updated_at
      t.datetime :alerted_at
      t.datetime :completed_at
      t.decimal  :device_mileage,   precision: 10, scale: 0, default: 0
      t.decimal  :target_mileage,   precision: 10, scale: 0, default: 0
      t.datetime :notified_at
    end

    create_table :movement_alerts, force: true do |t|
      t.integer  :device_id
      t.integer  :user_id
      t.decimal  :latitude,             precision: 15, scale: 10
      t.decimal  :longitude,            precision: 15, scale: 10
      t.integer  :violating_reading_id
      t.datetime :user_notified
      t.datetime :created_at
      t.datetime :updated_at
    end

    add_index :movement_alerts, [:user_id, :device_id, :violating_reading_id], name: :movement_alerts_validation, unique: true, using: :btree
    add_index :movement_alerts, [:user_notified, :violating_reading_id], name: :index_movement_alerts_on_user_notified_and_violating_reading_id, using: :btree

    create_table :offline_events, force: true do |t|
      t.integer  :device_id
      t.datetime :created_at
      t.datetime :started_at,           null: false
      t.datetime :updated_at
    end

    add_index :offline_events, [:device_id, :started_at], name: :index_offline_events_on_device_id_and_started_at, using: :btree

    create_table :readings, force: true do |t|
      t.decimal  :latitude,                             precision: 20, scale: 16
      t.decimal  :longitude,                            precision: 20, scale: 16
      t.decimal  :altitude,                             precision: 20, scale: 16
      t.float    :speed,                   limit: 24
      t.float    :direction,               limit: 24
      t.integer  :device_id
      t.datetime :created_at
      t.datetime :updated_at
      t.integer  :event_type
      t.string   :note
      t.string   :address,                 limit: 1024
      t.boolean  :notified,                                                       default: false
      t.boolean  :ignition
      t.boolean  :gpio1
      t.boolean  :gpio2
      t.boolean  :geocoded,                                                       default: false, null: false
      t.string   :street_number
      t.string   :street
      t.string   :place_name
      t.string   :admin_name1
      t.boolean  :power_up,                                                       default: false
      t.integer  :geofence_id,                                                    default: 0
      t.string   :geofence_event_type,                                            default: ""
      t.float    :battery_voltage,         limit: 24
      t.float    :mileage,                 limit: 24
      t.float    :mpg,                     limit: 24
      t.float    :rpm,                     limit: 24
      t.integer  :location_id
      t.integer  :acceleration
      t.integer  :deceleration
      t.integer  :rssi
      t.float    :fuel_level,              limit: 24
      t.string   :gateway_event_type,      limit: 64
      t.integer  :gateway_sequence_number
      t.datetime :recorded_at,                                                                    null: false
      t.datetime :received_at
      t.boolean  :in_motion
    end

    add_index :readings, [:address], name: :readings_address, length: {:address=>255}, using: :btree
    add_index :readings, [:device_id, :recorded_at], name: :index_readings_on_device_id_and_recorded_at, using: :btree
    add_index :readings, [:device_id], name: :readings_device_id, using: :btree
    add_index :readings, [:notified, :event_type], name: :readings_notified_event_type, using: :btree
    add_index :readings, [:recorded_at], name: :readings_recorded_at, using: :btree

    create_table :sensor_templates, force: true do |t|
      t.integer  :address
      t.string   :name
      t.string   :high_label
      t.string   :low_label
      t.integer  :notification_type
      t.integer  :account_id
      t.datetime :created_at
      t.datetime :updated_at
    end

    create_table :sessions, force: true do |t|
      t.string   :session_id
      t.text     :data
      t.datetime :updated_at
    end

    add_index :sessions, [:session_id], name: :index_sessions_on_session_id, using: :btree
    add_index :sessions, [:updated_at], name: :index_sessions_on_updated_at, using: :btree

    create_table :stop_events, force: true do |t|
      t.integer  :duration
      t.integer  :device_id
      t.datetime :started_at,                                                            null: false
      t.datetime :ended_at
      t.boolean  :suspect,                                               default: false
      t.integer  :start_reading_id
      t.integer  :end_reading_id
      t.decimal  :start_latitude,              precision: 15, scale: 10
      t.decimal  :start_longitude,             precision: 15, scale: 10
      t.decimal  :end_latitude,                precision: 15, scale: 10
      t.decimal  :end_longitude,               precision: 15, scale: 10
      t.integer  :start_location_id
      t.integer  :end_location_id
      t.datetime :created_at
      t.datetime :updated_at
    end

    add_index :stop_events, [:device_id, :created_at, :suspect], name: :index_stop_events_on_device_id_and_created_at_and_suspect, using: :btree
    add_index :stop_events, [:device_id, :started_at], name: :index_stop_events_on_device_id_and_started_at, using: :btree

    create_table :trip_events, force: true do |t|
      t.integer  :device_id
      t.integer  :duration
      t.datetime :created_at
      t.datetime :started_at,                                                                null: false
      t.datetime :ended_at
      t.float    :distance,             limit: 24
      t.boolean  :suspect,                                                   default: false
      t.boolean  :has_gps
      t.integer  :speeds_quantity,                                           default: 0
      t.integer  :speeds_sum,                                                default: 0
      t.integer  :start_reading_id
      t.integer  :end_reading_id
      t.decimal  :start_latitude,                  precision: 15, scale: 10
      t.decimal  :start_longitude,                 precision: 15, scale: 10
      t.decimal  :end_latitude,                    precision: 15, scale: 10
      t.decimal  :end_longitude,                   precision: 15, scale: 10
      t.float    :speed,                limit: 24
      t.integer  :start_location_id
      t.integer  :end_location_id
      t.float    :average_speed,        limit: 24
      t.float    :max_speed,            limit: 24
      t.integer  :idle_events_quantity
      t.integer  :idle_duration
      t.datetime :updated_at
    end

    add_index :trip_events, [:device_id, :created_at, :suspect], name: :index_trip_events_on_device_id_and_created_at_and_suspect, using: :btree
    add_index :trip_events, [:device_id, :started_at], name: :index_trip_events_on_device_id_and_started_at, using: :btree

    create_table :trip_legs, force: true do |t|
      t.integer  :trip_event_id
      t.integer  :reading_start_id
      t.integer  :reading_stop_id
      t.integer  :duration
      t.integer  :idle
      t.float    :distance,         limit: 24
      t.datetime :created_at
      t.datetime :updated_at
    end

    add_index :trip_legs, [:trip_event_id], name: :index_trip_event_id_on_trip_legs, using: :btree

    create_table :users, force: true do |t|
      t.string   :first_name,               limit: 30
      t.string   :last_name,                limit: 30
      t.string   :email
      t.string   :encrypted_password,       limit: 128, default: "",    null: false
      t.string   :password_salt,            limit: 128, default: "",    null: false
      t.datetime :created_at
      t.datetime :updated_at
      t.string   :remember_token
      t.integer  :account_id
      t.boolean  :is_master,                            default: false
      t.datetime :last_sign_in_at
      t.integer  :enotify,                  limit: 2,   default: 1
      t.string   :access_key
      t.string   :default_home_action
      t.string   :default_home_selection
      t.string   :default_map_type
      t.integer  :view_overlays,                        default: 0,     null: false
      t.string   :reset_password_token
      t.datetime :remember_created_at
      t.string   :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string   :unconfirmed_email
      t.integer  :sign_in_count,                        default: 0
      t.datetime :current_sign_in_at
      t.string   :last_sign_in_ip
      t.string   :current_sign_in_ip
      t.string   :username
      t.string   :domain
      t.datetime :reset_password_sent_at
      t.string   :authentication_token
      t.integer  :roles,                                                null: false
      t.integer  :subscribed_notifications,             default: 1023,  null: false
    end
  end

  def self.down
    drop_table :accounts
    drop_table :background_reports
    drop_table :device_profiles
    drop_table :devices
    drop_table :devices_users
    drop_table :digital_sensor_readings
    drop_table :digital_sensors
    drop_table :geofence_polypoints
    drop_table :geofence_violations
    drop_table :geofences
    drop_table :group_devices
    drop_table :group_notifications
    drop_table :groups
    drop_table :idle_events
    drop_table :locales
    drop_table :locations
    drop_table :login_messages
    drop_table :maintenances
    drop_table :movement_alerts
    drop_table :offline_events
    drop_table :readings
    drop_table :sensor_templates
    drop_table :sessions
    drop_table :stop_events
    drop_table :trip_events
    drop_table :trip_legs
    drop_table :users
  end
end
