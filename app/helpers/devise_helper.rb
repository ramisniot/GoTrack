module DeviseHelper
  def devise_error_messages!
    return "" if resource.errors.empty?

    messages = resource.errors.full_messages.map { |msg| content_tag(:li, msg) }.join

    html = <<-HTML
      <div id="error_message" class='login_flash_message login_flash_message--error'>#{messages}</div>
    HTML

    html.html_safe
  end
end
