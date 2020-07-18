module UsersHelper
  def role_description(role)
    case role
      when :superadmin then 'Super Admin'
      when :admin      then 'Admin'
      when :read_write then 'User-R/W'
      when :view_only  then 'User-ViewOnly'
    end
  end

  def options_for_roles(roles)
    roles.map { |role| [role_description(role), role] }
  end
end
