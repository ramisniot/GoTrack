class UsersController < ApplicationController
  before_filter :authorize
  before_filter :authorize_user, except: [:index, :new, :create]
  before_filter :authorize_user_creation, only: [:new, :create]

  def index
    @users = current_account.users
  end

  def new
    @user = User.new
  end

  def edit
    @user = User.where(id: params[:id], account_id: current_account.id).first
  end

  def create
    @user = User.new(user_params)
    @user.roles = [get_role_from_params]
    @user.account_id = current_account.id
    @user.is_admin = 1 if params[:is_admin]

    # Check that passwords match
    if params[:user][:password] == params[:user][:password_confirmation] and not params[:user][:password].blank?
      @user.password = params[:user][:password]
      if @user.save
        flash[:success] = @user.email + ' was created successfully'
        redirect_to users_path
      else # Display errors from model validation
        flash.now[:error] = @user.errors.to_a.uniq.join('<br />')
        render :new
      end
    else
      flash.now[:error] = 'Your new password and confirmation must match'
      render :new
    end
  end

  def update
    @user = User.where(id: params[:id], account_id: current_account.id).first

    unless @user.id == current_user.id or current_user.is_admin?
      flash.now[:error] = 'Only administrators can edit a user other than himself'
      return render :edit
    end

    @user.assign_attributes(user_params)
    @user.roles = [get_role_from_params] if params[:user][:role]

    # Update the existing password
    if params[:new_password].present? || params[:confirm_new_password].present?
      validate_password(@user) ? save_user(@user) : render(:edit)
    else # Update when the password checkbox is not checked
      save_user(@user)
    end
  end

  def destroy
    unless current_user.is_admin?
      flash.now[:error] = 'Only administrators can delete users'
      return redirect_to users_path
    end

    user = User.find(params[:id])
    unless user.is_master
      user.destroy
      flash[:success] = user.email + ' was deleted successfully'
      redirect_to users_path
    else
      flash.now[:error] = 'Master user cannot be deleted'
      redirect_to users_path
    end
  end

  def current_home_selection
    @current_home_selection ||= build_home_selection(@user.default_home_selection)
  end

  private

  def authorize_user
    user = User.find(params[:id])
    unless user.account == current_account
      redirect_back_or_default "/user/sign_out"
    end
  end

  def get_role_from_params
    User::ROLES_BY_PRIVILEGE.detect { |role| role.to_s == params[:user][:role] } if params[:user]
  end

  private

  def validate_password(user)
    if user.valid_password?(params[:password])
      # Let's verify that the new password and confirmation match
      if params[:new_password] == params[:confirm_new_password] and !params[:new_password].blank? and !params[:confirm_new_password].blank?
        user.password = params[:new_password]
        # Try and save the updated password with the user info
        if params[:new_password].length > 5
          true
        else # Password can't be saved
          flash.now[:error] = 'Passwords must be between 6 and 30 characters'
          false
        end
      else
        flash.now[:error] = 'Your new password and confirmation must match'
        false
      end
    else # The existing password doesn't match what's in the system
      flash.now[:error] = 'Your existing password must match what\'s currently stored in our system'
      false
    end
  end

  def save_user(user)
    if user.save
      set_home_selection(user.default_home_selection) if user == current_user
      flash[:success] = user.first_name + ' ' + user.last_name + ' was updated successfully'
      redirect_to users_path
    else
      if params[:user][:email] != current_user.email
        flash.now[:error] = "Email address #{params[:user][:email]} already in use"
        render :edit
      else
        flash.now[:error] = "Unknown error occurred"
        render :edit
      end
    end
  end

  def authorize_user_creation
    unless current_user.is_admin?
      flash[:error] = 'Only administrators can create users'
      return redirect_to users_path
    end
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :default_home_action, :default_home_selection)
  end
end
