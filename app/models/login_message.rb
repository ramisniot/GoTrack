class LoginMessage < ActiveRecord::Base
  def self.instance
    @@markdown ||= Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, space_after_headers: true)
    last || new
  end

  def to_html
    @@markdown ||= Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, space_after_headers: true)
    @@markdown.render(self.message.to_s).html_safe
  end
end
