module ReportsHelper
  def minutes_to_hours(min)
    if min < 60
      (min % 60).to_s + " min"
    else
      hr = min / 60
      hr.to_s + (hr == 1 ? " hr" : " hrs") + ", " + (min % 60).to_s + " min"
    end
  end

  def link_to_report(name, class_modifier, controller, *actions)
    options = {
      controller: controller,
      action: actions.first,
      id: @device.nil? ? nil : @device.id,
      start_date: params['start_date'].nil? ? nil : @start_date,
      end_date: params['end_date'].nil? ? nil : @end_date
    }

    class_name = is_tab_selected?(controller, actions) ? "current-tab #{class_modifier}" : class_modifier.to_s
    label = content_tag(:span, name)
    link_to(label, options, class: class_name)
  end

  def is_tab_selected?(controller, actions)
    current_action = params[:action]
    current_controller = params[:controller]

    actions.include?(current_action) && current_controller == controller || actions.include?(current_controller)
  end

  def calculate_grid_classes
    return 'ui-grid-c', 'ui-block-c'
  end

  def report_actions(scheduled_report)
    actions = []

    if scheduled_report.is_a?(ScheduledReport)
      if scheduled_report.completed? and scheduled_report.report_data.present?
        html = '<i class="fa fa-eye link-icon"></i>'.html_safe
        actions << link_to(html, scheduled_report_path(scheduled_report), title: 'View')
        html = '<i class="fa fa-download link-icon"></i>'.html_safe
        actions << link_to(html, download_scheduled_report_path(scheduled_report), download: true, title: 'Download')
      else
        html = '<i class="fa fa-pencil link-icon"></i>'.html_safe
        actions << link_to(html, edit_scheduled_report_path(scheduled_report), title: 'Edit')
      end
      html = '<i class="fa fa-trash link-icon"></i>'.html_safe
      actions << link_to(html, scheduled_report_path(scheduled_report), data: { confirm: 'Are you sure you want to delete this scheduled report?' }, method: :delete, title: 'Delete')
    elsif scheduled_report.completed?
      html = '<i class="fa fa-download link-icon"></i>'.html_safe
      link_to(html, download_scheduled_report_path(scheduled_report), download: true, title: 'Download')
    end
    raw(actions.join(''))
  end

  def report_name(scheduled_report)
    completed_name = '<i class="fa fa-check scheduled_report__icon scheduled_report__icon--green" aria-hidden="true"></i> &nbsp&nbsp&nbsp'.html_safe + scheduled_report.report_name
    uncompleted_name = '<i class="fa fa-clock-o scheduled_report__icon" aria-hidden="true"></i> &nbsp&nbsp&nbsp'.html_safe + scheduled_report.report_name

    completed = scheduled_report.completed? &&
      (!scheduled_report.is_a?(ScheduledReport) || scheduled_report.report_data.present?)

    name = completed ? completed_name : uncompleted_name
    raw(name)
  end

  def for_hours
    hours = []
    (1..24).each do |x|
      hours << ["for #{pluralize(x, 'hour')}", x]
    end
    hours
  end

  def show_map(controller, action)
    !(['reports_index', 'reports_maintenance', 'reports_scheduled_reports', 'reports_trip', 'reports_all_events'].include?("#{controller}_#{action}") ||
    ['one_time_reports', 'scheduled_reports'].include?(controller.to_s))
  end

  def select_date_with_arrow(date, options, html_options)
    html = select_date(date, options, html_options)
    html.gsub!('</select>', '</select><i class="fa fa-caret-down form-select__arrow"></i>')
    html.html_safe
  end

  def time_select_with_arrow(object_name, method, options, html_options)
    html = time_select(object_name, method, options, html_options)
    html.gsub!('</select>', '</select><i class="fa fa-caret-down form-select__arrow"></i>')
    html.html_safe
  end

  def geofence_name(reading)
    reading.geofence ? reading.geofence.name : 'location'
  end
end
