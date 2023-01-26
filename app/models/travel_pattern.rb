class TravelPattern < ApplicationRecord
  scope :ordered, -> {joins(:agency).order("agencies.name, travel_patterns.name")}
  scope :for_superuser, -> {all}
  scope :for_oversight_user, -> (user) {where(agency: user.current_agency.agency_oversight_agency.pluck(:transportation_agency_id).concat([user.current_agency.id]))}
  scope :for_current_transport_user, -> (user) {where(agency: user.current_agency)}
  scope :for_transport_user, -> (user) {where(agency: user.staff_agency)}

  ## 
  # This scope returns only Travel Patterns related to the +Agency+ provided.
  # 
  # @param [Agency] agency The +Agency+ used to select Travel Patterns.
  scope :with_agency, -> (agency) do
    raise TypeError.new("#{agency.class} can't be coerced into Agency") unless agency.is_a?(Agency)
    TravelPattern.where(agency_id: agency.id)
  end

  ## 
  # This scope returns only Travel Patterns related to the +Service+ provided.
  # 
  # @param [Service] service The +Service+ used to select Travel Patterns.
  scope :with_service, -> (service) do
    raise TypeError.new("#{service.class} can't be coerced into Service") unless service.is_a?(Service)
    joins(:travel_pattern_services).where(travel_pattern_services: {service_id: service.id}).distinct
  end

  ## 
  # This scope returns only Travel Patterns where the provided +origin+ is a valid starting point
  # for trips as determined by the Travel Pattern's +origin_zone+ and +destination_zone+. The
  # +destination_zone+ is considered a valid starting point if +allow_reverse_sequence_trips+ is
  # set to +true+ for that Travel Pattern.
  # 
  # @param [Hash] origin A Hash containing the latitude and longitude of a trip's starting point.
  # @option origin [Number] :lat The latitude of the trip's starting point.
  # @option origin [Number] :lng The longitude of the trip's starting point.
  scope :with_origin, -> (origin) {
    raise ArgumentError.new("origin must contain :lat and :lng") unless origin[:lat].present? && origin[:lng].present?
    
    travel_patterns = TravelPattern.arel_table
    origin_zone_ids = OdZone.joins(:region).where(region: Region.containing_point(origin[:lng], origin[:lat])).pluck(:id)

    where(
      travel_patterns[:origin_zone_id].in(origin_zone_ids).or(
        travel_patterns[:destination_zone_id].in(origin_zone_ids).and(
          travel_patterns[:allow_reverse_sequence_trips].eq(true)
        )
      )
    )
  }

  ##
  # This scope returns only Travel Patterns where the provided +destination+ is a valid ending 
  # point for trips as determined by the Travel Pattern's +origin_zone+ and +destination_zone+.
  # The +origin_zone+ is considered a valid ending point if +allow_reverse_sequence_trips+ is
  # set to +true+ for that Travel Pattern.
  # 
  # @param [Hash] destination A Hash containing the latitude and longitude of a trip's ending point.
  # @option destination [Number] :lat The latitude of the trip's ending point.
  # @option destination [Number] :lng The longitude of the trip's ending point.
  scope :with_destination, -> (destination) {
    raise ArgumentError.new("destination must contain :lat and :lng") unless destination[:lat].present? && destination[:lng].present?

    travel_patterns = TravelPattern.arel_table
    destination_zone_ids = OdZone.joins(:region).where(region: Region.containing_point(destination[:lng], destination[:lat])).pluck(:id)

    where(
      travel_patterns[:destination_zone_id].in(destination_zone_ids).or(
        travel_patterns[:origin_zone_id].in(destination_zone_ids).and(
          travel_patterns[:allow_reverse_sequence_trips].eq(true)
        )
      )
    )
  }

  ##
  # This scope returns only Travel Patterns where the provided +Purpose+ is included in the Travel
  # Pattern's list of associated purposes.
  # 
  # @param [Purpose] purpose The +Purpose+ used to select Travel Patterns.
  scope :with_purpose, -> (purpose) do
    raise TypeError.new("#{purpose.class} can't be coerced into Purpose") unless purpose.is_a?(Purpose)
    joins(:travel_pattern_purposes).where(travel_pattern_purposes: {purpose_id: purpose.id}).distinct
  end

  ##
  # This scope returns only Travel Patterns where the provided +purpose_id+ is included in the
  # Travel Pattern's list of associated purposes.
  # 
  # @param [Number] purpose_id The +Purpose+ used to select Travel Patterns.
  scope :with_purpose_id, -> (purpose_id) do
    raise TypeError.new("#{purpose_id.class} can't be coerced into Integer") unless purpose_id.is_a?(Integer)
    joins(:travel_pattern_purposes).where(travel_pattern_purposes: {purpose_id: purpose_id}).distinct
  end

  ##
  # This scope returns only Travel Patterns where at least one provided +FundingSource+ is included
  # in the Travel Pattern's list of associated funding sources.
  # 
  # @param funding_sources [ActiveRecord::Relation<FundingSource>] The +FundingSource+s used to
  # select Travel Patterns.
  scope :with_funding_sources, -> (funding_sources) do
    unless funding_sources.is_a?(ActiveRecord::Relation) && funding_sources.model == FundingSource
      raise TypeError.new("#{funding_sources.class} can't be coerced into ActiveRecord::Relation<FundingSource>")
    end

    joins(:travel_pattern_funding_sources).where(travel_pattern_funding_sources: {funding_source: funding_sources}).distinct
  end

  ##
  # This scope returns only Travel Patterns where at least one provided +funding_source_id+ is
  # included in the Travel Pattern's list of associated funding sources.
  # 
  # @param funding_source_ids [Array<Number>] The +Id+s of +FundingSources+s.
  scope :with_funding_source_ids, -> (funding_source_ids) do
    unless funding_source_ids.is_a?(Array) && funding_source_ids.all? { |fsi| fsi.class == Integer }
      raise TypeError.new("#{funding_source_ids.class} can't be coerced into Array<Integer>")
    end

    joins(:travel_pattern_funding_sources).where(travel_pattern_funding_sources: {funding_source_id: funding_source_ids}).distinct
  end

  ##
  # This scope returns only Travel Patterns where the provided +date+ occurs within both the Travel
  # Pattern's accociated Service Schedules and Booking Window.
  # 
  # @param [Date] date The date to use.
  scope :with_date, -> (date) do
    raise TypeError.new("#{date.class} can't be coerced into Date") unless date.is_a?(Date) 

    joins(:travel_pattern_service_schedules, :booking_window)
      .where(travel_pattern_service_schedules: {service_schedule: ServiceSchedule.for_date(date)})
      .where(booking_window: BookingWindow.for_date(date)).distinct
  end

  belongs_to :agency
  belongs_to :booking_window
  belongs_to :origin_zone, class_name: 'OdZone'
  belongs_to :destination_zone, class_name: 'OdZone'

  has_many :travel_pattern_services, dependent: :destroy
  has_many :services, through: :travel_pattern_services, dependent: :restrict_with_error
  has_many :travel_pattern_service_schedules, dependent: :destroy
  has_many :service_schedules, through: :travel_pattern_service_schedules
  has_many :travel_pattern_purposes, dependent: :destroy
  has_many :purposes, through: :travel_pattern_purposes
  has_many :travel_pattern_funding_sources, dependent: :destroy
  has_many :funding_sources, through: :travel_pattern_funding_sources

  accepts_nested_attributes_for :travel_pattern_service_schedules, allow_destroy: true, reject_if: proc { |attr| attr[:service_schedule_id].blank? }
  accepts_nested_attributes_for :travel_pattern_purposes, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :travel_pattern_funding_sources, allow_destroy: true, reject_if: :all_blank

  validates :name, uniqueness: {scope: :agency_id}
  # TODO: verify whether the presence of a service schedule is good enough, or if it has to be a specific kind of schedule.
  validates_presence_of :name, :booking_window, :agency, :origin_zone, :destination_zone, :travel_pattern_funding_sources, :travel_pattern_purposes, :travel_pattern_service_schedules

  def to_api_response
    travel_pattern_opts = { 
      only: [:id, :agency_id, :name, :description],
      methods: :to_calendar
    }

    self.as_json(travel_pattern_opts)
  end

  def self.for_user(user)
    if user.superuser?
      for_superuser.ordered
    elsif user.currently_oversight?
      for_oversight_user(user).ordered
    elsif user.currently_transportation?
      for_current_transport_user(user).order("name desc")
    elsif user.transportation_user?
      for_transport_user(user).order("name desc")
    else
      nil
    end
  end

  def schedules_by_type
    pre_loaded = self.association(:travel_pattern_service_schedules).loaded?

    # Prepping the return value
    schedules_by_type = {
      weekly_schedules: [],
      extra_service_schedules: [],
      reduced_service_schedules: [],
    }

    # Get all associated schedules (in reverse alphabetical order)
    service_schedules = pre_loaded ? 
                          self.travel_pattern_service_schedules.to_a :
                          self.travel_pattern_service_schedules
                            .eager_load(service_schedule: [:service_schedule_type, :service_sub_schedules])
                            .joins(:service_schedule)
                            .merge(ServiceSchedule.order(name: :desc))
                            .to_a
    
    # Sort Schedules by type
    # This also reverses the order, so now they're sorted alphabetically
    while service_schedules.length > 0 do
      schedule = service_schedules.pop

      schedules_by_type[:weekly_schedules].push(schedule) if schedule.is_a_weekly_schedule?
      schedules_by_type[:extra_service_schedules].push(schedule) if schedule.is_an_extra_service_schedule?
      schedules_by_type[:reduced_service_schedules].push(schedule) if schedule.is_a_reduced_service_schedule?
    end

    return schedules_by_type
  end

  def to_calendar
    travel_pattern_service_schedules = schedules_by_type

    weekly_schedules = travel_pattern_service_schedules[:weekly_schedules].map(&:service_schedule)
    extra_service_schedules = travel_pattern_service_schedules[:extra_service_schedules].map(&:service_schedule)
    reduced_service_schedules = travel_pattern_service_schedules[:reduced_service_schedules].map(&:service_schedule)

    calendar = {}
    date = booking_window.earliest_booking.to_date
    end_date = booking_window.latest_booking.to_date
    
    while date <= end_date
      date_string = date.strftime('%Y-%m-%d')
      calendar[date_string] = {}

      reduced_sub_schedule = reduced_service_schedules.reduce(nil) do |sub_schedule, service_schedule|
        valid_start = service_schedule.start_date == nil || service_schedule.start_date < date
        valid_end = service_schedule.end_date == nil || service_schedule.end_date < date
        next unless valid_start && valid_end
        
        sub_schedule = service_schedule.service_sub_schedules.find do |sub_schedule|
          sub_schedule.calendar_date == date
        end

        break(sub_schedule) if sub_schedule
      end

      # Reduced schedules overwrite all other schedules so we can skip the rest of this iteration
      if reduced_sub_schedule
        calendar[date_string][:start_time] = reduced_sub_schedule.start_time
        calendar[date_string][:end_time] = reduced_sub_schedule.end_time
        date += 1.day
        next
      end

      weekly_schedules = weekly_schedules.select do |service_schedule|
        valid_start = service_schedule.start_date == nil || service_schedule.start_date < date
        valid_end = service_schedule.end_date == nil || service_schedule.end_date < date
        valid_start && valid_end
      end

      weekly_sub_schedules = weekly_schedules.map(&:service_sub_schedules).flatten.select do |sub_schedule|
        sub_schedule.day == date.wday
      end

      extra_service_schedules = extra_service_schedules.select do |service_schedule|
        valid_start = service_schedule.start_date == nil || service_schedule.start_date < date
        valid_end = service_schedule.end_date == nil || service_schedule.end_date < date
        valid_start && valid_end
      end

      extra_service_sub_schedules = extra_service_schedules.map(&:service_sub_schedules).flatten.select do |sub_schedule|
        sub_schedule.calendar_date == date
      end

      sub_schedules = weekly_sub_schedules + extra_service_sub_schedules
      calendar[date_string][:start_time] = sub_schedules.min_by(&:start_time)&.start_time
      calendar[date_string][:end_time] = sub_schedules.max_by(&:end_time)&.end_time
      date += 1.day
    end

    return calendar
  end

  # Class Methods

  ##
  # A method for quickly filtering through Travel Patterns based on a param hash passed in as an
  # arguemnt. All params are optional. Any params not included in the hash will not be used to
  # filter with.
  #
  # @param [Hash] query_params The params hash used to select Travel Patterns.
  # @option query_params [Agency] :agency The *Agency* that the Travel Patterns should belong to.
  # @option query_params [Service] :service A *Service* that the Travel Patterns should be associated with.
  # @option query_params [Hash] :origin A hash representing a starting point for a potential Trip. 
  # @option origin [Number] :lat
  # @option origin [Number] :lng
  # @option query_params [Hash] :destination A hash representing an ending point for a potential Trip. 
  # @option destination [Number] :lat
  # @option destination [Number] :lng
  # @option query_params [Purpose] :purpose A *Purpose* that the Travel Pattern should be associated with.
  # @option query_params [FundingSource] :funding_source A *FundingSource* that the Travel Pattern should be associated with.
  # @option query_params [Date] :date A *Date* that the Travel Pattern should be able to book a trip for.
  # @option query_params [String, Integer] :start_time The starting time of a potential trip represented  as number of seconds since midnight.
  # @option query_params [String, Integer] :end_time The ending time of a potential trip represented  as number of seconds since midnight.
  def self.available_for(query_params)
    filters = [
      :agency, 
      :service, 
      :origin,
      :destination,
      :purpose, :purpose_id, 
      :funding_sources, :funding_source_ids, 
      :date
    ]
    query = self.all

    # First filter by all provided params
    filters.each do |filter|
      method_name = ("with_" + filter.to_s).to_sym
      param = query_params[filter]

      query = query.send(method_name, param) unless param.nil?
    end

    travel_patterns = self.filter_by_time(query.distinct, query_params[:start_time], query_params[:end_time])
  end

  def self.to_api_response(travel_patterns)
    # Filter out any patterns with no bookable dates. This can happen prior to selecting a date and time
    # if a travel pattern has only calendar date schedules and the dates are outside of the booking window.
    travel_patterns.map(&:to_api_response)
                    .select { |travel_pattern|
                      dates = travel_pattern['to_calendar'].values
                      dates.detect { |date|
                        (date[:start_time] || -1) >= 0 && (date[:end_time] || -1) >= 1
                      }
                    }
  end

  # This method should be the first time we call the database, before this we were only constructing the query
  def self.filter_by_time(travel_pattern_query, trip_start, trip_end)
    return travel_pattern_query unless trip_start
    trip_start = trip_start.to_i
    trip_end = (trip_end || trip_start).to_i

    Rails.logger.info("Filtering through Travel Patterns that have a Service Schedule running from: #{trip_start/1.hour}:#{trip_start%1.hour/1.minute}, to: #{trip_end/1.hour}:#{trip_end%1.hour/1.minute}")
    # Eager loading will ensure that all the previous filters will still apply to the nested relations
    travel_patterns = travel_pattern_query.eager_load(travel_pattern_service_schedules: {service_schedule: [:service_schedule_type, :service_sub_schedules]})
    travel_patterns.select do |travel_pattern|
      schedules = travel_pattern.schedules_by_type

      # If there are reduced schedules, then we don't need to check any other schedules
      if schedules[:reduced_service_schedules].present?
        Rails.logger.info("Travel Pattern ##{travel_pattern.id} has matching reduced service schedules")
        schedules = schedules[:reduced_service_schedules]
      else
        Rails.logger.info("Travel Pattern ##{travel_pattern.id} does not have maching calendar date schedules, checking other schedule types")
        schedules = schedules[:weekly_schedules] + schedules[:extra_service_schedules]
      end

      # Grab any valid schedules
      schedules.any? do |travel_pattern_service_schedule|
        service_schedule = travel_pattern_service_schedule.service_schedule
        service_schedule.service_sub_schedules.any? do |sub_schedule|
          valid_start_time = sub_schedule.start_time <= trip_start
          valid_end_time = sub_schedule.end_time >= trip_end

          valid_start_time && valid_end_time
        end
      end
    end # end travel_patterns.select
  end # end filter_by_time

end
