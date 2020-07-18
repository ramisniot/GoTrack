require 'RedCloth'

module InitialMessage

  def self.get_text(locale)
    if File.exist?(message_file_path(locale))
      File.read(message_file_path(locale))
    else
      locale == 'en' ? '' : get_text('en')
    end
  end

  def self.get_text_as_html(locale)
    text = get_text(locale)
    RedCloth.new(text).to_html.html_safe
  end

  def self.save_text(text, locale)
    Dir.mkdir(message_dir_path) unless File.exists?(message_dir_path)
    File.open(message_file_path(locale), 'w') {|f| f.write(text) }
  end

  private
  def self.message_dir_path
    "#{Rails.root}/public/system/"
  end

  def self.message_file_path(locale)
    message_dir_path + "message_#{locale}.txt"
  end
end
