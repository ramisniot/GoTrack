module ScheduledReportsHelper
  def my_hour_select(field_name = '', value = 0)
    str = "<select name='#{field_name.sub(']', '(4i)]')}'>" +
    (0..23).to_a.collect do |x|
      open_tag = "<option value='#{x}'" + (value == x ? ' selected="selected"' : '') + ">"
      body = ""
      if x == 0
        body = "12 am"
      elsif x == 12
        body = "12 pm"
      elsif x < 12
        body = "#{x} am"
      else
        body = "#{x - 12} pm"
      end
      close_tag = "</option>"
      open_tag + body + close_tag
    end.join("\n\t") +
    "</select>"
    str.html_safe
  end

  def report_span_options(report)
    options = ScheduledReport::REPORT_SPANS.collect { |x| ["1 #{x.singularize}", "1.#{x}"] }
    options << ['3 Months', '3.Months'] if report.report_type == 'state_mileage'
    options
  end

  def report_span_selected_option(report)
    "#{report.report_span_value}.#{report.report_span_units}"
  end

  def report_type_options(show_state_mileage_report)
    options = BackgroundReport::REPORT_TYPES.reject { |x| x == 'state_mileage' && !show_state_mileage_report }
    options.collect { |x| [x.gsub('_', ' ').gsub('group', 'fleet').gsub('trip', 'Start/Stop').titleize, x] }
  end
end
