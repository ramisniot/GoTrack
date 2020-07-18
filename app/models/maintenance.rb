class Maintenance < ActiveRecord::Base
  # Types of maintenances
  SCHEDULED_TYPE = 0
  MILEAGE_TYPE = 1

  TYPE_HASH = {
    SCHEDULED_TYPE => 'Scheduled',
    MILEAGE_TYPE => 'Mileage'
  }.freeze

  MAX_LENGTH = {
    description_task: 40
  }.freeze

  include ApplicationHelper

  belongs_to :device

  validates_presence_of :device_id, :type_task, :description_task
  validates_numericality_of :mileage, if: proc { |m| !m.mileage.nil? }
  validates_length_of :description_task, maximum: MAX_LENGTH[:description_task]

  scope :completed, -> { where('completed_at is not null') }
  scope :not_completed, -> { where(completed_at: nil) }
  scope :mileage, -> { where(type_task: MILEAGE_TYPE) }
  scope :with_an_active_device, -> { joins(:device).merge(Device.provisioned) }

  # Status values
  STATUS_OK = 0
  STATUS_PENDING = 1
  STATUS_DUE = 2
  STATUS_PDUE = 3
  STATUS_COMPLETED = 4

  def is_scheduled?
    type_task == SCHEDULED_TYPE
  end

  def is_mileage?
    type_task == MILEAGE_TYPE
  end

  def type
    self.type_task
  end

  def type_string
    TYPE_HASH[type_task]
  end

  def target_string
    case type_task
    when SCHEDULED_TYPE
      scheduled_time.try :strftime, '%d-%b-%Y'
    when MILEAGE_TYPE
      "#{target_mileage} miles"
    end
  end

  def actual_string
    case type_task
    when SCHEDULED_TYPE
      standard_date(completed_at)
    when MILEAGE_TYPE
      "#{device_mileage} miles"
    end
  end

  def is_completed?
    !completed_at.blank?
  end

  def status
    return STATUS_COMPLETED if self.is_completed?
    days = (scheduled_time - Date.today) if self.is_scheduled?
    mileage_to_target = remaining_miles

    days ||= -1
    mileage_to_target ||= -1

    if days > 10 || mileage_to_target > 100
      STATUS_OK
    elsif (days <= 10 && days > 1) || (mileage_to_target <= 100 && mileage_to_target > 25)
      STATUS_PENDING
    elsif (days <= 1 && days >= 0) || (mileage_to_target <= 25 && mileage_to_target > 1)
      STATUS_DUE
    else
      STATUS_PDUE
    end
  end

  def alert_status(check_time = Time.now)
    case status
    when STATUS_PENDING
      self.alerted_at = check_time unless alerted_at
      return self.is_mileage? ? "Reminder: Maintenance task '#{description_task}' will be due in #{remaining_miles.round(1)} miles" : "Reminder: Maintenance task '#{description_task}' will be due on #{scheduled_time.strftime('%Y-%m-%d')}"
    when STATUS_DUE
      self.alerted_at = check_time unless alerted_at
      return self.is_mileage? ? "Due: Maintenance task '#{description_task}' will be due in #{remaining_miles.round(1)} miles" : "Due: Maintenance task '#{description_task}' will be due Today"
    when STATUS_PDUE
      self.alerted_at = check_time unless alerted_at
      return self.is_mileage? ? "Past Due: Maintenance task '#{description_task}' was due #{remaining_miles.round(1).abs} miles ago" : "Past Due: Maintenance task '#{description_task}' was due on #{scheduled_time.strftime('%Y-%m-%d')}"
    end
    nil
  end

  def remaining_miles
    return nil unless self.is_mileage?
    device.update_mileage!
    target_mileage - device.total_mileage
  end
end
