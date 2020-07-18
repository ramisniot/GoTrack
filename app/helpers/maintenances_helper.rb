module MaintenancesHelper
  def get_due(data)
    # TODO This is broken at the end of January it seems
    if data.is_a?(Date)
      #This is a scheduled task
      days = (data - Date.today).to_f

      if days.to_i == 0
        final = "Today"
      elsif days < 0
        final = "0"
      else
        months = days / 30
        years = days / 365

        string = "In "

        y_string = years >= 1 ? "##{pluralize(years.to_i, 'year')}" : ""
        m_string = months >= 1 ? "#{pluralize(months.to_i, 'month')}" : ""
        remaining_days = (days.to_i) - ((months.to_i * 30) + (years.to_i * 365))
        d_string = "#{pluralize(remaining_days.to_i, 'day')}"

        strings = []
        strings << y_string unless y_string.blank?
        strings << m_string unless m_string.blank?
        strings << d_string

        complete = strings.join(' and ')
        final = string + complete
      end

      final
    else
      data = 0 if data < 0
      pluralize(data, 'mile')
    end
  end

  def get_status(data, completed = false)
    return Maintenance::STATUS_COMPLETED if completed
    days = (data - Date.today) if data.is_a?(Date)
    mileage_to_target = data if data.is_a?(Integer) || data.is_a?(Float) || data.is_a?(Fixnum)

    days ||= -1
    mileage_to_target ||= -1

    if days > 10 or mileage_to_target > 100
      return Maintenance::STATUS_OK
    elsif (days <= 10 and days > 1) or (mileage_to_target <= 100 and mileage_to_target > 25)
      return Maintenance::STATUS_PENDING
    elsif (days <= 1 and days >= 0) or (mileage_to_target <= 25 and mileage_to_target > 1)
      return Maintenance::STATUS_DUE
    else
      return Maintenance::STATUS_PDUE
    end
  end

  def get_tooltip(status, type)
    case status.to_i
      when Maintenance::STATUS_COMPLETED
        'Task is Completed'
      when Maintenance::STATUS_OK
        type == Maintenance::MILEAGE_TYPE ? '> 100 miles from target' : "> 10 days from Target"
      when Maintenance::STATUS_PENDING
        type == Maintenance::MILEAGE_TYPE ? '100 miles from target' : "10 Days or fewer from Target"
      when Maintenance::STATUS_DUE
        type == Maintenance::MILEAGE_TYPE ? '25 miles from target' : "1 Days or fewer from Target"
      when Maintenance::STATUS_PDUE
        type == Maintenance::MILEAGE_TYPE ? '1 mile < than target' : "A day < than target"
      else
        'Please report this'
    end
  end

  def status_string(status)
    case status.to_i
      when Maintenance::STATUS_COMPLETED
        'Completed'
      when Maintenance::STATUS_OK
        'Ok'
      when Maintenance::STATUS_PENDING
        'Pending'
      when Maintenance::STATUS_DUE
        'Due'
      when Maintenance::STATUS_PDUE
        'Past Due'
      else
        'Invalid Status'
    end
  end
end
