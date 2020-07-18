class BackgroundReport < ActiveRecord::Base
  include ApplicationHelper
  include ActionView::Helpers::DateHelper
  include ActionView::Helpers::TextHelper
  include MaintenancesHelper

  REPORT_TYPES = %w{group_trip stops speeding idle maintenance location sensors state_mileage}
  LIMIT_PER_USER = 20

  belongs_to :user

  serialize :report_params

  delegate :time_zone, to: :user, prefix: false, allow_nil: true

  after_save :enqueue_scheduled_report, if: :scheduled_for_changed?

  validates_presence_of :report_name
  validate :one_time_range
  validate :user_over_limit

  scope :not_report_type, ->(report_type_value) { where('report_type != ?', report_type_value) }

  def user_over_limit
    if self.new_record? && self.user.pending_reports.count >= LIMIT_PER_USER
      self.errors.add(:base, "Each user may have at most #{LIMIT_PER_USER} pending scheduled reports")
    end
  end

  def enqueue_scheduled_report
    ScheduledReportsWorker.perform_in(self.delay_in_seconds.seconds, { id: self.id })
  end

  def delay_in_seconds
    (scheduled_for - DateTime.now).to_i
  end

  def one_time_range
    if !to.nil? && (to < from)
      self.errors.add(:base, "Report To must occur on or after Report From")
    end
  end
end
