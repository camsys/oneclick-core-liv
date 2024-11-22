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
  
    Rails.logger.info("Converting itinerary: #{otp_itin.inspect}")
  
    service_id = otp_itin["legs"].detect { |leg| leg['serviceId'].present? }&.fetch('serviceId', nil)
    start_time = otp_itin["legs"].first["from"]["departureTime"]
    end_time = otp_itin["legs"].last["to"]["arrivalTime"]
  
    # Set startTime and endTime in the first and last legs for UI compatibility
    otp_itin["legs"].first["startTime"] = start_time
    otp_itin["legs"].last["endTime"] = end_time
  
    {
      start_time: Time.at(start_time.to_i / 1000).in_time_zone,
      end_time: Time.at(end_time.to_i / 1000).in_time_zone,
      transit_time: get_transit_time(otp_itin, trip_type),
      walk_time: otp_itin["walkTime"],
      wait_time: otp_itin["waitingTime"],
      walk_distance: otp_itin["walkDistance"],
      cost: extract_cost(otp_itin, trip_type),
      legs: otp_itin["legs"],
      trip_type: trip_type,
      service_id: service_id
    }
  end

  # Modifies OTP Itin's legs, inserting information about 1-Click services
  def associate_legs_with_services(otp_itin)
    Rails.logger.info "Inspecting OTP itinerary structure: #{otp_itin.inspect}"
  
    itinerary = otp_itin.is_a?(Hash) ? otp_itin['itinerary'] : otp_itin.itinerary
  
    unless itinerary
      Rails.logger.error("Error: Expected itinerary missing from otp_itin. Check structure.")
      return
    end
  
    otp_itin.legs ||= []
    otp_itin.legs = otp_itin.legs.map do |leg|
      svc = get_associated_service_for(leg)
  
      # Assign service details if a service is found
      if svc
        leg['serviceId'] = svc.id
        leg['serviceName'] = svc.name
        leg['serviceFareInfo'] = svc.url
        leg['serviceLogoUrl'] = svc.full_logo_url
      else
        leg['serviceName'] = leg['agencyName'] || leg['agencyId']
      end
  
      leg
    end
  end
  

  def get_associated_service_for(leg)
    leg ||= {}
    Rails.logger.info "Inspecting leg: #{leg.inspect}"
  
    # Extract GTFS agency ID and name from the route's agency field
    gtfs_agency_id = leg.dig('route', 'agency', 'gtfsId')
    gtfs_agency_name = leg.dig('route', 'agency', 'name')
  
    # Log extracted values
    Rails.logger.info "GTFS Agency ID: #{gtfs_agency_id}, Name: #{gtfs_agency_name}"
  
    svc = nil
  
    # Attempt to find service by GTFS ID
    if gtfs_agency_id
      svc = Service.find_by(gtfs_agency_id: gtfs_agency_id)
      Rails.logger.info "Service found by GTFS ID: #{svc.inspect}" if svc
    end
  
    # Fallback to find by GTFS Agency Name
    if svc.nil? && gtfs_agency_name
      svc = Service.find_by(name: gtfs_agency_name)
      Rails.logger.info "Service found by GTFS Name: #{svc.inspect}" if svc
    end
  
    # Ensure service is within permitted services
    if svc
      permitted_service = @services.detect { |s| s.id == svc.id }
      Rails.logger.info "Permitted service: #{permitted_service.inspect}"
      return permitted_service
    else
      Rails.logger.warn "No matching service found for leg."
      return nil
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
