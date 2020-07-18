class StopEvent < ActiveRecord::Base
  include EventBehavior

  self.primary_key = :id

  belongs_to :reading
  belongs_to :device

  scope :by_started_at, -> { reorder('started_at ASC') }
  scope :not_suspect, -> { where('suspect is null or suspect = false') }
  scope :between_dates, lambda { |start_dt, end_dt| where(started_at: start_dt..end_dt) }
end
