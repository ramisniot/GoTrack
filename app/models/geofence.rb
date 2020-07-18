class Geofence < ActiveRecord::Base
  include Overlay

  DEFAULT_ADDRESS_TEXT = 'Street Address OR Latitude, Longitude'
  SHAPE_CIRCULAR    = 0
  SHAPE_POLYGONAL   = 1
  SHAPE_RECTANGULAR = 2

  FUDGE_FACTOR = 1.0001

  COLORS = {
      blue: '#0093D9',
      red: '#8B0000',
      green: '#008000',
      yellow: '#FFFF00',
      purple: '#800080',
      dark_blue: '#001E5D',
      gray: '#C0C0C0',
      orange: '#FF6D24',
      light_red: '#FF0000',
      dark_green: '#003200',
      dark_yellow: '#B2B200',
      dark_purple: '#400040',
      dark_gray: '#545454',
      pink: '#FFC0CB',
      brown: '#8B4513'
  }

  RADII = [0.1,0.25,0.5,1,5,10,25,50,100]

  M_TO_KM = {
      0.1   => 0.15,
      0.25  => 0.4,
      0.5   => 0.8,
      1.0   => 1.5,
      5.0   => 8.0,
      10.0  => 15.0,
      25.0  => 40.0,
      50.0  => 80.0,
      100.0 => 150.0
  }

  MAX_LENGTH = {
    name: 30
  }

  belongs_to :device
  belongs_to :account
  belongs_to :group
  has_many :geofence_violations, dependent: :destroy
  has_many :polypoints, -> { order(%(geofence_polypoints."order" ASC)) }, class_name: 'GeofencePolypoint', dependent: :destroy

  scope :by_area, -> { order('area ASC') }
  scope :by_updated_at, -> { order('updated_at DESC') }

  validates_presence_of :name

  validates_presence_of :latitude, :longitude

  validates :name, length: { maximum: MAX_LENGTH[:name] }

  validate :coordinates_between_limits

  before_save :normalize_data
  before_save :set_center_and_radius

  after_create :update_data
  after_create :set_center_and_radius_and_save

  before_destroy :clean_up_violations

  scope :not_null, -> (attribute) { where(self.arel_table[attribute].not_eq(nil)) }

  def self.location_from_address(address)
    if address =~ /^\s*(-?[\d.]+),\s*(-?[\d.]+)\s*$/
      [$1, $2]
    end
  end

  def self.relevant_geofences_for_device(device)
    no_device = 'device_id is NULL'
    no_group = 'group_id is NULL'

    geofences = self.with_latitude_and_longitude.where(account_id: device.account_id)
    geofences = geofences.where("(#{no_group} AND (device_id = ? OR #{no_device}) OR (group_id = ? AND #{no_device}))", device.id, device.group_id)
    geofences.by_area
  end

  def self.within_latitudes(min_latitude, max_latitude, sql = nil)
    super(min_latitude, max_latitude, "latitude >= (? - (#{Overlay::MILES_TO_DEGREES * 2} * radius)) AND latitude <= (? + (#{Overlay::MILES_TO_DEGREES * 2} * radius))")
  end

  def self.within_longitudes(min_longitude, max_longitude, sql = nil)
    super(min_longitude, max_longitude, "(longitude >= (? - (#{Overlay::MILES_TO_DEGREES * 2} * radius)) AND longitude <= (? + (#{Overlay::MILES_TO_DEGREES * 2} * radius)))")
  end

  def self.change_vertical_axis(lng, relative = true)
    if relative
      (lng > 0) ? lng - Overlay::MAX_LONGITUDE : Overlay::MAX_LONGITUDE + lng
    else
      (lng <= 0) ? Overlay::MAX_LONGITUDE + lng : - (Overlay::MAX_LONGITUDE - lng)
    end
  end

  # Verify if the longitude is between the bounds
  # It considers normal cases and cases when the antimeridian (180 degrees) is between the bounds
  #
  # @param lng [Float] the longitude to verify if is between given bounds
  # @param left_bound [Float] the leftmost longitude
  # @param right_bound [Float] the rightmost longitude
  # @return [Boolean] returns true if the longitude is between the given bounds, false otherwise
  #
  def self.between_bounds?(lng, left_bound, right_bound)
    if left_bound < right_bound
      lng.between?(left_bound, right_bound)
    else
      lng.between?(left_bound, Overlay::MAX_LONGITUDE) || lng.between?(Overlay::MIN_LONGITUDE, right_bound)
    end
  end

  def clean_up_violations
    GeofenceViolation.delete_all(geofence_id: self.id)
  end

  def set_center_and_radius
    return if self.new_record?

    if self.polygonal?
      self.latitude = self.polypoints.average(:latitude)
      self.longitude = self.polypoints.average(:longitude)
      self.radius = self.polypoints.map { |p| p.distance_to(self) }.max
    else
      self.polypoints = []
      self.area = self.radius * self.radius * Math::PI
    end
  end

  def set_center_and_radius_and_save
    self.save #with implied before_save :set_center_and_radius
  end


  def polygonal?
    self.shape_type != SHAPE_CIRCULAR
  end

  def bounds
    latitude.to_s + "," + longitude.to_s + "," + radius.to_s
  end

  def square_bounds
    case self.shape_type
      when SHAPE_CIRCULAR
        self.square_bounds_for_circular_shape
      when SHAPE_POLYGONAL, SHAPE_RECTANGULAR
        self.square_bounds_for_polygonal_or_rectangular_shape
    end
  end

  def square_bounds_for_circular_shape
    radius = self.radius * FUDGE_FACTOR

    sw = [latitude - (radius * Overlay::MILES_TO_DEGREES), longitude - (radius * Overlay::MILES_TO_DEGREES)]
    ne = [latitude + (radius * Overlay::MILES_TO_DEGREES), longitude + (radius * Overlay::MILES_TO_DEGREES)]

    sw[1] = Overlay::TOTAL_EARTH_DEGREES + sw[1]     if sw[1] < Overlay::MIN_LONGITUDE
    ne[1] = - (Overlay::TOTAL_EARTH_DEGREES - ne[1]) if ne[1] > Overlay::MAX_LONGITUDE

    sw.concat(ne)
  end

  def square_bounds_for_polygonal_or_rectangular_shape
    points = self.effective_polypoints
    polyX = points.collect(&:longitude)
    polyY = points.collect(&:latitude)

    n = polyY.max
    s = polyY.min

    unless self.geofence_across_antimeridian?
      e = polyX.max
      w = polyX.min
    else
      right_most_points = polyX.select{ |x| x <= 0 }
      e = right_most_points.max
      left_most_points = polyX.select{ |x| x > 0 }
      w = left_most_points.min
    end

    [s, w, n, e]
  end

  def address_or_coords
    if self.address !~ /[a-zA-Z]/
      return sprintf("%0.5f, %0.5f", self.latitude.to_f, self.longitude.to_f)
    else
      return self.address
    end
  end

  def normalize_data
    case self.shape_type
      when SHAPE_CIRCULAR

        self.polypoints = []
        self.area = self.radius.to_f * self.radius.to_f * Math::PI

      when SHAPE_POLYGONAL

        self.latitude, self.longitude = calculate_geofence_center
        self.radius = self.polypoints.map{|x| self.distance_to(x)}.max
        self.area = self.radius.to_f * self.radius.to_f * Math::PI

      when SHAPE_RECTANGULAR

        if (points = effective_polypoints).any?
          first_point = points.first
          self.tl_lat,self.tl_lng,self.br_lat,self.br_lng = first_point.latitude,first_point.longitude,first_point.latitude,first_point.longitude
          points.each do |point|
            self.tl_lat = point.latitude if self.tl_lat < point.latitude
            self.br_lat = point.latitude if self.br_lat > point.latitude
            self.tl_lng = point.longitude if self.tl_lng > point.longitude
            self.br_lng = point.longitude if self.br_lng < point.longitude
          end
          self.latitude = (self.tl_lat + self.br_lat) / 2.0
          self.longitude = (self.tl_lng + self.br_lng) / 2.0
          self.radius = self.distance_to(::GeofencePolypoint.new(latitude: self.tl_lat,longitude: self.tl_lng).freeze)
        end

        self.polypoints = []
        self.area = self.calculate_rectangle_area
    end
  end

  def effective_polypoints
    case self.shape_type
      when SHAPE_CIRCULAR
        []
      when SHAPE_POLYGONAL
        self.polypoints
      when SHAPE_RECTANGULAR
        if self.polypoints.any?
          self.polypoints.to_a
        elsif self.tl_lat and self.tl_lng and self.br_lat and self.br_lng
          [
              ::GeofencePolypoint.new(latitude: self.tl_lat,longitude: self.tl_lng).freeze,
              ::GeofencePolypoint.new(latitude: self.br_lat,longitude: self.tl_lng).freeze,
              ::GeofencePolypoint.new(latitude: self.br_lat,longitude: self.br_lng).freeze,
              ::GeofencePolypoint.new(latitude: self.tl_lat,longitude: self.br_lng).freeze,
          ]
        else
          []
        end
    end
  end

  def update_data
    self.save # force center/radius recalc.
  end

  def polypoint_string
    self.polypoints.map { |x| "[#{x.latitude},#{x.longitude}]" }.join(':')
  end

  def polypoint_string=(polypoint_string)
    self.polypoints = []
    pp_a = polypoint_string.split(/:/).map{|x| x.gsub(/[\[\]]/,'').split(/,/).map(&:to_f)}

    pp_a.pop if pp_a.last == pp_a.first

    pp_a.each_with_index do |pp, i|
      self.polypoints << ::GeofencePolypoint.new(latitude: pp[0].to_f, longitude: pp[1].to_f, order: i + 1)
    end

    polypoint_string
  end

  def encloses?(*args)
    return false unless (lat_lng = args.first.kind_of?(::Reading) ? args.first.to_lat_lng : Geokit::LatLng.new(*args)).valid?

    case shape_type
      when SHAPE_CIRCULAR

        self.distance_to(lat_lng) <= self.radius

      when SHAPE_POLYGONAL

        if self.inside_geofence_bounds?(lat_lng)
          points = self.effective_polypoints
          polySides = points.size
          polyX = points.collect(&:longitude)
          polyY = points.collect(&:latitude)

          # In case geofence is placed across antimeridian,
          # it's needed move the geofence temporarily to relative axis
          # to verify the point's inclusion properly
          if self.geofence_across_antimeridian?
            lat_lng.lng = ::Geofence.change_vertical_axis(lat_lng.lng)
            polyX = polyX.map{ |lng| ::Geofence.change_vertical_axis(lng) }
          end

          oddNodes = false
          j = polySides - 1
          (0..polySides-1).each do |i|
            if ((polyY[i] < lat_lng.lat && polyY[j] >= lat_lng.lat) ||  (polyY[j] < lat_lng.lat && polyY[i] >= lat_lng.lat))
              if ((polyX[i] + (lat_lng.lat - polyY[i]) / (polyY[j] - polyY[i]) * (polyX[j] - polyX[i])) < lat_lng.lng)
                oddNodes = !oddNodes
              end
            end
            j=i
          end
          oddNodes

        else
          false
        end

      when SHAPE_RECTANGULAR
        lat_lng.lat.between?(self.br_lat,self.tl_lat) && lat_lng.lng.between?(self.tl_lng,self.br_lng)

      else
        false
    end
  end


  def calculate_geofence_center
    return [nil, nil] if (lat_polypoints = self.effective_polypoints.collect(&:latitude)).empty? || (lng_polypoints = self.effective_polypoints.collect(&:longitude)).empty?

    lat = (lat_polypoints.max + lat_polypoints.min) / 2

    unless geofence_across_antimeridian?
      lng = (lng_polypoints.max + lng_polypoints.min) / 2
    else
      # Temporarily change axis to properly calculate the average
      lng_polypoints_rel = lng_polypoints.map{ |lng| ::Geofence.change_vertical_axis(lng) }
      avg_rel_lng = (lng_polypoints_rel.max + lng_polypoints_rel.min) / 2
      lng = ::Geofence.change_vertical_axis(avg_rel_lng, false)
    end

    [lat, lng]
  end

  def geofence_across_antimeridian?
    lng_polypoints = self.effective_polypoints.collect(&:longitude)
    (lng_polypoints.max - lng_polypoints.min) > Overlay::TOTAL_EARTH_DEGREES - (lng_polypoints.max - lng_polypoints.min)
  end

  def inside_geofence_bounds?(point)
    s, w, n, e = self.square_bounds

    rectangular_bounds = Geokit::Bounds.new(Geokit::LatLng.new(s, w), Geokit::LatLng.new(n, e))
    rectangular_bounds.contains?(point)
  end

  def calculate_rectangle_area
    s, w, n, e = self.square_bounds

    unless self.geofence_across_antimeridian?
      up_left_point = Geokit::LatLng.new(n, w)
      down_left_point = Geokit::LatLng.new(s, w)
      down_right_point = Geokit::LatLng.new(s, e)
    else
      w = ::Geofence.change_vertical_axis(w)
      e = ::Geofence.change_vertical_axis(e)

      up_left_point = Geokit::LatLng.new(n, w)
      down_left_point = Geokit::LatLng.new(s, w)
      down_right_point = Geokit::LatLng.new(s, e)
    end

    down_left_point.distance_to(up_left_point) * down_left_point.distance_to(down_right_point)
  end

  def coordinate_between_limit(latitude, longitude)
    return !(latitude.nil? ^ longitude.nil?) if latitude.nil? || longitude.nil?

    Overlay::MIN_LATITUDE <= latitude && latitude <= Overlay::MAX_LATITUDE &&
        Overlay::MIN_LONGITUDE <= longitude && longitude <= Overlay::MAX_LONGITUDE
  end

  def coordinates_between_limits
    invalid =
        case self.shape_type
          when SHAPE_CIRCULAR
            !coordinate_between_limit(latitude, longitude)
          when SHAPE_POLYGONAL
            self.polypoints.detect { |x| !coordinate_between_limit(x.latitude, x.longitude) }
          when SHAPE_RECTANGULAR
            effective_polypoints.detect { |x| !coordinate_between_limit(x.latitude, x.longitude) }
        end

    errors.add(:base, 'Invalid location') if invalid
  end

end
