# Inheritable class for writing records to CSV files
class CSVWriter
  
  ### HOW TO USE ###
  # 1. Create a model-specific CSV Writer that inherits from this class.
  # 2. Configure it using the class config methods below: list the columns,
  #    associated tables, and custom header names.
  # 3. Write methods for any columns that aren't simple record attributes.
  #    These methods should have the same name as the column name defined
  #    in the columns method. They may access the current record using the
  #    @record instance variable, which is set for each new row to be written.
  #    E.g. `def method_name { return @record.some_logic }`
  # 4. In the model, configure it to use the CSV Writer by adding:
  #    `write_to_csv with: MyModelCSVWriter`
  #    This will allow the model to respond to `to_csv`
  # 5. In the controller's respond_to block, download the CSV with something like:
  #    `format.csv { send_data @records.to_csv }`
  ##################

  # Set a standard reference quantity for records written when using the write_file_with_limit method
  DEFAULT_RECORD_LIMIT = 50000

  #################
  # CLASS METHODS #
  #################
  
  class << self
    attr_reader :headers, :associated_tables # Sets class variables on the inheriting class
  end
  
  ### CLASS CONFIGURATION METHODS ###
  # Configure inheriting classes by calling these methods in the class definition.
  # columns: This method is required. Must list all columns to include in the CSV.
  # associations: Optional. This will improve performance for columns that require table joins.
  #               Use the name of the association as defined in the model.
  # header_names: Optional. Overwrite column headers with custom text.
  #               Use key-value pairs, like `ugly_col_name: "Pretty Column Name"`
  ###################################
  
  # Config method for setting the columns to write to the file
  def self.columns(*cols)
    
    # For each column, check if a method is already defined. If not,
    # define a default one that calls that method on the passed record.
    cols.each do |col_name|
      unless method_defined?(col_name)
        define_method(col_name) do
          @record.send(col_name)
        end
      end
    end

    # Define default header names
    @headers ||= {} # initialize @headers if not done so already
    cols.each do |col_name|
      @headers[col_name] = col_name.to_s unless @headers[col_name]
    end
      
  end
  
  # Config method for identifying belongs_to tables to include in the query
  # Optional but highly recommended to improve performance--otherwise tables
  # are joined for each record in the collection
  def self.associations(*tables)
    @associated_tables = tables 
  end
  
  # Config method for overwriting default header names with custom text
  def self.header_names(dictionary={})
    @headers ||= {} # initialize @headers if not done so already
    dictionary.each { |k,v| @headers[k] = v }
  end
  
  
  ####################
  # INSTANCE METHODS #
  ####################
  
  attr_reader :records # Sets an instance variable on instances of the inheriting class
  
  # Initialize with a collection of the appropriate record type
  def initialize(records)
    @records = scope(records).includes(:origin, :destination, :user, :selected_itinerary).to_a
  end
  
  # Writes an entire CSV file
  def write_file(opts={})
<<<<<<< Updated upstream
  batches_of = opts[:batches_of] || 10000
  start_time = Time.now
  Rails.logger.info "Starting CSV streaming with batch size of #{batches_of} at #{start_time}"

  CSV.generate(headers: true) do |csv|
    csv << headers.values # Header row
    header_time = Time.now
    Rails.logger.info "Header written at #{header_time}. Time elapsed: #{header_time - start_time} seconds"

    # Stream rows directly from the database
    self.records.find_each(batch_size: batches_of).with_index(1) do |record, index|
      row_start_time = Time.now
      @record = record
      csv << write_row
      row_end_time = Time.now

      if index % 1000 == 0
        Rails.logger.info "Processed #{index} records so far. Time for last 1000: #{row_end_time - row_start_time} seconds"
=======
    batches_of = opts[:batches_of] || 1000

    CSV.generate(headers: true) do |csv|
      csv << headers.values # Header row

      self.records.in_batches(of: batches_of) do |batch|
        batch.each do |record|
          @record = record
          @booking_snapshot_cache = @record.ecolane_booking_snapshot # Cache the booking snapshot for reuse
          csv << self.write_row
        end
>>>>>>> Stashed changes
      end

      Rails.logger.debug "Processed record #{index} in #{row_end_time - row_start_time} seconds"
    end
<<<<<<< Updated upstream

    end_time = Time.now
    Rails.logger.info "Completed CSV streaming at #{end_time}. Total time: #{end_time - start_time} seconds"
=======
>>>>>>> Stashed changes
  end
end

<<<<<<< Updated upstream
def write_file_with_limit(opts={})
  batches_of = opts[:batches_of] || 10000
  limit = opts[:limit] || DEFAULT_RECORD_LIMIT
  start_time = Time.now
  Rails.logger.info "Starting CSV streaming with limit of #{limit} and batch size of #{batches_of} at #{start_time}"
=======
  def booking_snapshot
    @booking_snapshot_cache ||= @record.ecolane_booking_snapshot
  end


  # Writes a CSV file with a limited number of rows
  def write_file_with_limit(opts={})
    batches_of = opts[:batches_of] || 1000
>>>>>>> Stashed changes

  CSV.generate(headers: true) do |csv|
    csv << headers.values # Header row
    header_time = Time.now
    Rails.logger.info "Header written at #{header_time}. Time elapsed: #{header_time - start_time} seconds"

    row_count = 0

    # Stream rows directly from the database with a limit
    self.records.find_each(batch_size: batches_of).with_index(1) do |record, index|
      break if row_count >= limit

      row_start_time = Time.now
      @record = record
      csv << write_row
      row_count += 1
      row_end_time = Time.now

      if row_count % 1000 == 0
        Rails.logger.info "Processed #{row_count} records so far. Time for last 1000: #{row_end_time - row_start_time} seconds"
      end

      Rails.logger.debug "Processed record #{row_count} in #{row_end_time - row_start_time} seconds"
    end

    if row_count == limit
      csv << ["Records have been limited to #{limit}."]
      Rails.logger.info "Reached record limit of #{limit}. Streaming stopped."
    end

    end_time = Time.now
    Rails.logger.info "Completed CSV streaming at #{end_time}. Total time: #{end_time - start_time} seconds"
  end
end




  
  protected
  
  # Wrapper method for returning the list of column header names
  def headers
    self.class.headers
  end
  
  # Method scoping the records and joining to appropriate tables
  def scope(records)
    records.all.includes(self.class.associated_tables)
  end
    
  # Builds a CSV row for the current record
  def write_row
    [
      trip_id,
      trip_time,
      traveler,
      user_type,
      traveler_county,
      traveler_paratransit_id,
      arrive_by,
      disposition_status,
      purpose,
      orig_addr,
      orig_county,
      orig_lat,
      orig_lng,
      dest_addr,
      dest_county,
      dest_lat,
      dest_lng,
      traveler_age,
      traveler_ip,
      traveler_accommodations,
      traveler_eligibilities,
      agency_name,
      service_name,
      booking_id,
      booking_client_id,
      is_round_trip,
      booking_timestamp,
      funding_source,
      sponsor,
      companions,
      trip_note,
      ecolane_error_message,
      pca
    ]
  end
  
  
end
