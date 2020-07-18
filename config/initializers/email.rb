email_config =  YAML.load(File.read('config/email.yml'))[Rails.env] if File.exist?('config/email.yml')
email_config ||= {}

ActionMailer::Base.smtp_settings = {
  port:           ENV['SMTP_PORT']     || email_config['SMTP_PORT']      || 587,
  address:        ENV['SMTP_HOST']     || email_config['SMTP_HOST']      || 'smtp.sparkpostmail.com',
  user_name:      ENV['SMTP_USERNAME'] || email_config['SMTP_USERNAME']  || 'SMTP_Injection',
  password:       ENV['SMTP_PASSWORD'] || email_config['SMTP_PASSWORD'],
  domain:         ENV['SMTP_DOMAIN']   || email_config['SMTP_DOMAIN']    || 'quantumiot.com',
  tls:            ENV['SMTP_TLS']      || email_config['SMTP_TLS']       || false,
  authentication: :plain
}
