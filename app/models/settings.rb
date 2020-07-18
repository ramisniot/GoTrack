module Settings
  CONFIG_FILE = 'device.yml'

  def settings
    @@settings ||= load_settings
  end

  def load_settings
    file = File.join(Rails.root, 'config', CONFIG_FILE)
    if !File.exists?(file)
      file = File.join(File.dirname(__FILE__), '/../../../config', CONFIG_FILE)
    end
    YAML::load_file(file)[Rails.env]
  end

end
