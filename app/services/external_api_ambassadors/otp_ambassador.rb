class OTPAmbassador
  include OTP

  attr_reader :otp, :trip, :trip_types, :http_request_bundler, :services

  # Translates 1-click trip_types into OTP mode requests
  TRIP_TYPE_DICTIONARY = {
    transit:      { label: :otp_transit, modes: "TRANSIT,WALK" },
    paratransit:  { label: :otp_paratransit, modes: "CAR" },
    car_park:     { label: :otp_car_park, modes: "" },
    taxi:         { label: :otp_car, modes: "CAR" },
    walk:         { label: :otp_walk, modes: "WALK" },
    car:          { label: :otp_car, modes: "CAR" },
    bicycle:      { label: :otp_bicycle, modes: "BICYCLE" },
    uber:         { label: :otp_car, modes: "CAR" },
    lyft:         { label: :otp_car, modes: "CAR" }
  }

  TRIP_TYPE_DICTIONARY_V2 = {
    transit:      { label: :otp_transit, modes: "TRANSIT,WALK" },
    paratransit:  { label: :otp_paratransit, modes: "TRANSIT,WALK,FLEX_ACCESS,FLEX_EGRESS,FLEX_DIRECT" },
    car_park:     { label: :otp_car_park, modes: "CAR_PARK,TRANSIT,WALK" },
    taxi:         { label: :otp_car, modes: "CAR" },
    walk:         { label: :otp_walk, modes: "WALK" },
    car:          { label: :otp_car, modes: "CAR" },
    bicycle:      { label: :otp_bicycle, modes: "BICYCLE" },
    uber:         { label: :otp_car, modes: "CAR" },
    lyft:         { label: :otp_car, modes: "CAR" }
  }

  # Initialize with a trip, an array of trip trips, an HTTP Request Bundler object, 
  # and a scope of available services
  def initialize(
      trip, 
      trip_types=TRIP_TYPE_DICTIONARY.keys, 
      http_request_bundler=HTTPRequestBundler.new, 
      services=Service.published
    )
    
    @trip = trip
    @trip_types = trip_types
    @http_request_bundler = http_request_bundler
    @services = services

    otp_version = Config.open_trip_planner_version
    @trip_type_dictionary = otp_version == 'v1' ? TRIP_TYPE_DICTIONARY : TRIP_TYPE_DICTIONARY_V2
    @request_types = @trip_types.map { |tt|
      @trip_type_dictionary[tt]
    }.compact.uniq
    @otp = OTPService.new(Config.open_trip_planner, otp_version)

    # add http calls to bundler based on trip and modes
    prepare_http_requests.each do |request|
      @http_request_bundler.add(
        request[:label],
        request[:url],
        :post,
        head: request[:headers],
        body: request[:body]
      )
    end
  end

  # Packages and returns any errors that came back with a given trip request
  def errors(trip_type)
    response = ensure_response(trip_type)
    if response
      response_error = response["error"]
    else
      response_error = "No response for #{trip_type}."
    end
    response_error.nil? ? nil : { error: {trip_type: trip_type, message: response_error} }
  end

  def get_gtfs_ids
    return [] if errors(trip_type)
    itineraries = ensure_response(:transit).itineraries
    return itineraries.map{|i| i.legs.pluck("agencyId")}
  end

  # Returns an array of 1-Click-ready itinerary hashes.
  def get_itineraries(trip_type)
    Rails.logger.info("Fetching itineraries for trip_type: #{trip_type}")
  
    if errors(trip_type)
      Rails.logger.error("Errors found for trip_type #{trip_type}: #{errors(trip_type).inspect}")
      return []
    end
  
    itineraries = ensure_response(trip_type)&.itineraries || []
    
    Rails.logger.info("Raw itineraries fetched for #{trip_type}: #{itineraries.inspect}")
    
    itineraries.map { |i| convert_itinerary(i, trip_type) }.compact
  end
  

  # Extracts a trip duration from the OTP response.
  def get_duration(trip_type)
    return 0 if errors(trip_type)
    itineraries = ensure_response(trip_type).itineraries
    return itineraries[0]["duration"] if itineraries[0]
    0
  end

  # Extracts a trip distance from the OTP response.
  def get_distance(trip_type)
    return 0 if errors(trip_type)
    itineraries = ensure_response(trip_type).itineraries
    return extract_distance(itineraries[0]) if itineraries[0]
    0
  end

  def max_itineraries(trip_type_label)
    quantity_config = {
      otp_car: Config.otp_itinerary_quantity,
      otp_walk: Config.otp_itinerary_quantity,
      otp_bicycle: Config.otp_itinerary_quantity,
      otp_car_park: Config.otp_car_park_quantity,
      otp_transit: Config.otp_transit_quantity,
      otp_paratransit: Config.otp_paratransit_quantity
    }

    quantity_config[trip_type_label]
  end

  # Dead Code? - Drew 02/16/2023
  # def get_request_url(request_type)
  #   @otp.plan_url(format_trip_as_otp_request(request_type))
  # end

  private

  # Prepares a list of HTTP requests for the HTTP Request Bundler, based on request types
  def prepare_http_requests
    @request_types.map do |request_type|
      # Transform the mode string into the GraphQL-compatible format
      transport_modes = request_type[:modes].split(',').map do |mode|
        { mode: mode.strip } # Basic structure for modes
      end
  
      # Return the GraphQL request structure
      {
        label: request_type[:label],
        url: "#{@otp.base_url}/otp/routers/default/index/graphql",
        body: @otp.build_graphql_body(
          [@trip.origin.lat, @trip.origin.lng],
          [@trip.destination.lat, @trip.destination.lng],
          @trip.trip_time,
          transport_modes
        ).to_json,
        headers: {
          'Content-Type' => 'application/json',
          'x-user-email' => '1-click@camsys.com',
          'x-user-token' => 'sRRTZ3BV3tmms1o4QNk2'
        }
      }
    end
  end  

  # Formats the trip as an OTP request based on trip_type
  def format_trip_as_otp_request(trip_type)
    num_itineraries = max_itineraries(trip_type[:label])
    {
      from: [@trip.origin.lat, @trip.origin.lng],
      to: [@trip.destination.lat, @trip.destination.lng],
      trip_time: @trip.trip_time,
      arrive_by: @trip.arrive_by,
      label: trip_type[:label],
      options: { 
        mode: trip_type[:modes],
        num_itineraries: num_itineraries
      }
    }
  end

  # Fetches responses from the HTTP Request Bundler, and packages
  # them in an OTPResponse object
  def ensure_response(trip_type)
    trip_type_label = @trip_type_dictionary[trip_type][:label]
    modes = @trip_type_dictionary[trip_type][:modes].split(',').map { |mode| { mode: mode.strip } }
  
    # Call the `plan` method from OTPService
    response = @otp.plan(
      [@trip.origin.lat, @trip.origin.lng],
      [@trip.destination.lat, @trip.destination.lng],
      @trip.trip_time,
      @trip.arrive_by,
      modes
    )

    Rails.logger.info("Response from OTPService for trip_type #{trip_type}: #{response.inspect}")
    Rails.logger.info("Validating OTP response for trip_type: #{trip_type}")
  
    if response['data'] && response['data']['plan'] && response['data']['plan']['itineraries']
      Rails.logger.info("Valid itineraries found: #{response['data']['plan']['itineraries']}")
      OTPResponse.new(response)
    else
      Rails.logger.warn("No valid itineraries in response: #{response.inspect}")
      { "error" => "No valid response from OTP GraphQL API" }
    end
  end  

  # Converts an OTP itinerary hash into a set of 1-Click itinerary attributes
  def convert_itinerary(otp_itin, trip_type)
    Rails.logger.info("OTP Itinerary: #{otp_itin.inspect}")
    Rails.logger.info("Trip Type: #{trip_type}")
    associate_legs_with_services(otp_itin)
    itin_has_invalid_leg = otp_itin.legs.detect{ |leg| 
      leg['serviceName'] && leg['serviceId'].nil?
    }
    return nil if itin_has_invalid_leg

    service_id = otp_itin.legs
                          .detect{ |leg| leg['serviceId'].present? }
                          &.fetch('serviceId', nil)

    return   {
      start_time: Time.at(otp_itin["startTime"].to_i / 1000).in_time_zone,
      end_time: Time.at(otp_itin["endTime"].to_i / 1000).in_time_zone,
      transit_time: calculate_transit_time(otp_itin) || 0,
      walk_time: otp_itin["walkTime"],
      wait_time: otp_itin["waitingTime"],
      walk_distance: otp_itin["walkDistance"],
      cost: calculate_cost(otp_itin),
      legs: otp_itin["legs"],
      trip_type: trip_type,
      service_id: service_id
    }
  end

  # Modifies OTP Itin's legs, inserting information about 1-Click services
  def associate_legs_with_services(otp_itin)
    otp_itin.legs ||= []
    otp_itin.legs = otp_itin.legs.map do |leg|
      svc = get_associated_service_for(leg)

      # double check if its paratransit but not set to that mode
      if !leg['mode'].include?('FLEX') && leg['boardRule'] == 'mustPhone'
        leg['mode'] = 'FLEX_ACCESS'
      end

      if svc
        leg['serviceId'] = svc.id
        leg['serviceName'] = svc.name
        leg['serviceFareInfo'] = svc.url  # Should point to service's fare_info_url, but we don't have that yet
        leg['serviceLogoUrl'] = svc.full_logo_url
        leg['serviceFullLogoUrl'] = svc.full_logo_url(nil) # actual size
      else
        leg['serviceName'] = (leg['agencyName'] || leg['agencyId'])
      end

      leg
    end
  end

  def get_associated_service_for(leg)
    svc = nil
    leg ||= {}
    gtfs_agency_id = leg['agencyId']
    gtfs_agency_name = leg['agencyName']
  
    # If gtfs_agency_id is not nil, first attempt to find the service by its GTFS agency ID.
    svc ||= Service.find_by(gtfs_agency_id: gtfs_agency_id) if gtfs_agency_id
  
    if svc
      # If a service is found by ID, we need to check if it's within the list of permitted services.
      return @services.detect { |s| s.id == svc.id }
    else
      # If we didn't find a service by its ID, and if gtfs_agency_name is not nil, then we try to find a service by its GTFS agency name.
      return @services.find_by(name: gtfs_agency_name) if gtfs_agency_name
    end
  end  

  # OTP Lists Car and Walk as having 0 transit time
  def get_transit_time(otp_itin, trip_type)
    otp_itin["duration"] - otp_itin["walkTime"] - otp_itin["waitingTime"]
  end

  # OTP returns car and bicycle time as walk time
  def get_walk_time otp_itin, trip_type
    if trip_type.in? [:car, :bicycle]
      return 0
    else
      return otp_itin["walkTime"]
    end
  end

  # Returns waiting time from an OTP itinerary
  def get_wait_time otp_itin
    return otp_itin["waitingTime"]
  end

  def get_walk_distance otp_itin
    return otp_itin["walkDistance"]
  end

  # Extracts cost from OTP itinerary
  def extract_cost(otp_itin, trip_type)
    case trip_type
    when [:walk, :bicycle]
      return 0.0
    when [:car]
      return nil
    end
  
    # Updated fare extraction logic
    if otp_itin["fares"].present?
      otp_itin["fares"].sum { |fare| fare["price"] || 0.0 }
    else
      0.0 
    end
  end  

  # Extracts total distance from OTP itinerary
  # default conversion factor is for converting meters to miles
  def extract_distance(otp_itin, trip_type=:car, conversion_factor=0.000621371)
    otp_itin.legs.sum_by(:distance) * conversion_factor
  end


end
