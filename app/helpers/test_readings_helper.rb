module TestReadingsHelper
  def event_type_options
    options_for_select(
      [
        ['Normal', 'normal'],
        ['Start Motion', 'motion'],
        ['In Motion', 'moving'],
        ['Stop Motion', 'motion_cleared'],
        ['Asset Stopped', 'event_normal'],
        ['Asset Start Motion', 'event_motion'],
        ['Asset Moving', 'event_moving'],
        ['Asset Stop Motion', 'event_stopped'],
        ['Asset GPS Unit Battery Low', 'event_backup_power_low'],
        ['Input Low', 'input_low_'],
        ['Input High', 'input_high_']
      ]
    )
  end
end
