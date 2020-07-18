class OneTimeReport < BackgroundReport
  before_save :adjust_parameters

  def adjust_parameters
    self.scheduled_for = DateTime.now
    self.recur = 0
  end
end
