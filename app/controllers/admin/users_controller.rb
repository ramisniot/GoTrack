class Admin::UsersController < ApplicationController
  unloadable # making unloadable per http://dev.rubyonrails.org/ticket/6001
  before_filter :authorize_super_admin
  layout 'admin'

  def index
    scope = params[:subdomain].blank? ? User : User.where(account_id: Account.where('subdomain ilike ?',"%#{params[:subdomain]}%").collect(&:id))
    @users = scope.search_for_users(params[:search], params[:page]).includes(:account)
    @accounts = Account.active.by_subdomain
  end

  def new
    @user = User.new
    @user.roles = [:admin]
    set_accounts
  end

  def edit
    @user = User.find(params[:id])
    set_accounts
  end

  def create
    @user = User.new(user_params)
    @users = User.where(account_id: @user.account_id)

    # If this is the first user for this account make them the master
    @user.is_master = 1 if @users.empty?

    if params[:user][:password] == params[:user][:password_confirmation]
      @user.roles = [get_role_from_params]

      if @user.save
        flash[:success] = "#{@user.email} was created successfully"
        redirect_to admin_users_path
      else
        flash.now[:error] = @user.errors.to_a.uniq.join('<br />')
        set_accounts

        render :new
      end
    else
      flash.now[:error] = 'Your new password and confirmation must match'
      set_accounts

      render :new
    end
  end

  def update
    @user = User.find(params[:id])
    @user.attributes = user_params
    @user.roles = [get_role_from_params] if params[:user] && params[:id].to_i != current_user.id

    if @user.save
      flash[:success] = "#{@user.email} updated successfully"
      redirect_to admin_users_path
    else
      flash.now[:error] = @user.errors.to_a.uniq.join('<br />')
      set_accounts

      render :edit
    end
  end

  def destroy
    user = User.find(params[:id])
    user.destroy
    flash[:success] = "#{user.email} deleted successfully"
    redirect_to action: "index"
  end

  private

  def set_accounts
    @accounts = Account.active.order('company')
  end

  def get_role_from_params
    User::ROLES_BY_PRIVILEGE.detect { |role| role.to_s == params[:user][:role] }
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation, :account_id)
  end
end
