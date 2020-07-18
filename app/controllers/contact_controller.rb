class ContactController < ApplicationController
  before_filter :authorize

  def index
  end

  # Send feedback to support@gotrack.com
  def thanks
    Notifier.app_feedback(current_user.email, current_account.contact_email, current_account.subdomain, params[:feedback]).deliver_now
  end
end
