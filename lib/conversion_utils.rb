module ConversionUtils
  KM_TO_MILES = 0.621
  FOOT_METER = 0.3408

  MeasureUnit = Struct.new(:label, :value)
  MPH_VALUE = 0
  KPH_VALUE = 1
  MEASURE_UNITS = [MeasureUnit.new('english_units', MPH_VALUE), MeasureUnit.new('metric_units', KPH_VALUE)]
  CONVERT_MPH_TO_KPH = 1.609344
  CONVERT_MILES_TO_KM = 1.609344

  def self.meter_to_foot(value)
    (value || 0) / FOOT_METER
  end

  def self.foot_to_meter(value)
    (value || 0) * FOOT_METER
  end

  def self.km_to_miles(km)
    km.nil? ? nil : km * KM_TO_MILES
  end

  def self.miles_to_km(miles)
    miles.nil? ? nil : miles / KM_TO_MILES
  end
end
