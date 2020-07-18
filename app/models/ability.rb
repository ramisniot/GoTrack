class Ability
  def initialize(object)
    super(object)

    if object
      if object.is_a?(User)
        can :access, 'navigation.geofences'

        if object.is_super_admin?
          can :access, :initial_message
        end
      end
    end
  end
end
