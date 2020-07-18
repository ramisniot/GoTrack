class Admin::AccountsController < ApplicationController
  unloadable # making unloadable per http://dev.rubyonrails.org/ticket/6001
  before_filter :authorize_super_admin
  layout 'admin'

  helper_method :encode_account_options

  def encode_account_options(account)
    (account.show_runtime ? "R" : "-") + (account.show_statistics ? "S" : "-") + (account.show_maintenance ? "M" : "-")
  end

  def index
    @keyword_search = params[:keyword_search] || ""
    @accounts = Account.active.by_subdomain.paginate(per_page: RESULT_COUNT, page: params[:page])
  end

  def search
    @keyword_search = params[:keyword_search] || ""
    @accounts = Account.active
                       .by_subdomain
                       .where(["company ILIKE ? OR subdomain ILIKE ?"] + ["%#{@keyword_search}%"] * 2)
                       .paginate(per_page: RESULT_COUNT, page: params[:page])

    render action: :index
  end

  def new
    @account = Account.new
  end

  def edit
    @account = Account.find(params[:id])
  end

  def create
    @account = Account.new(account_params)
    apply_options_to_account(params, @account)
    @account.is_verified = 1

    errors = @account.sync_and_save(account_params[:company])
    if errors.empty?
      flash[:success] = "#{@account.company} created successfully"
      redirect_to action: 'index' and return
    else
      flash.now[:error] = errors.uniq.join('<br/>')
      render 'new'
    end
  end

  def update
    @account = Account.find(params[:id])
    apply_options_to_account(params, @account)

    errors = @account.sync_and_update(account_params)
    if errors.empty?
      flash[:success] = "#{@account.subdomain} updated successfully"
      redirect_to admin_accounts_path
    else
      flash.now[:error] = errors.to_a.uniq.join('<br />')
      render 'edit'
    end
  end

  def destroy
    account = Account.find(params[:id])

    errors = account.sync_and_delete
    if errors.empty?
      flash[:success] = "#{account.subdomain} deleted successfully"
    else
      flash[:error] = errors.to_a.uniq.join('<br />')
    end
    redirect_to action: 'index'
  end

  private

  def apply_options_to_account(params, account)
    update_attributes_with_checkboxes(account, %i(show_runtime show_statistics show_maintenance show_state_mileage_report), params[:options])
  end

  def account_params
    params.require(:account).permit(:subdomain, :company, :contact_name, :contact_email, :contact_phone, :max_speed, :default_map_latitude, :default_map_longitude)
  end
end
