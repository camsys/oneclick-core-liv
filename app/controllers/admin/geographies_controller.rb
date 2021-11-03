class Admin::GeographiesController < Admin::AdminController
  authorize_resource :geography_record, parent: false

  def index
    @counties = County.all.order(:state, :name)
    @cities = City.all.order(:state, :name)
    @zipcodes = Zipcode.all.order(:name)
    @custom_geographies = get_geographies_for_user
    @agencies = current_user.get_transportation_agencies_for_user.order(:name)

    check_for_missing_geometries(@counties, @cities, @zipcodes, @custom_geographies)
  end

  def upload_counties
    uploader = ShapefileUploader.new(params[:geographies][:file], geo_type: :county)
    uploader.load
    present_error_messages(uploader)
    redirect_to admin_geographies_path
  end

  def upload_cities
    uploader = ShapefileUploader.new(params[:geographies][:file], geo_type: :city)
    uploader.load
    present_error_messages(uploader)
    redirect_to admin_geographies_path
  end

  def upload_zipcodes
    uploader = ShapefileUploader.new(params[:geographies][:file],
      geo_type: :zipcode,
      column_mappings: {name: 'ZCTA5CE10'})
    uploader.load
    present_error_messages(uploader)
    redirect_to admin_geographies_path
  end

  def upload_custom_geographies
    agency = Agency.find_by(id: params[:agency][:agency])
    uploader = ShapefileUploader.new(params[:geographies][:file],
      geo_type: :custom_geography,
      column_mappings: {name: 'NAME'})
    uploader.load
    uploader.update_model_agency(agency)
    present_error_messages(uploader)
    redirect_to admin_geographies_path
  end
  
  # Serves JSON responses to geography searches to enable autocomplete
  def autocomplete
    respond_to do |format|
      format.json do
        @counties = County.search(params[:term]).limit(10).map {|g| {label: g.to_geo.to_s, value: g.to_geo.to_h}}
        @zipcodes = Zipcode.search(params[:term]).limit(10).map {|g| {label: g.to_geo.to_s, value: g.to_geo.to_h}}
        @cities = City.search(params[:term]).limit(10).map {|g| {label: g.to_geo.to_s, value: g.to_geo.to_h}}
        @custom_geographies = CustomGeography.search(params[:term]).limit(10).map {|g| {label: g.to_geo.to_s, value: g.to_geo.to_h}}
        json_response = @counties + @zipcodes + @cities + @custom_geographies
        render json: json_response
      end
    end
  end

  private

  def custom_geography_params
    params.require(:custom_geography).permit(
    :agency,
    :id
    )
  end

  def get_geographies_for_user
    if current_user.superuser?
      CustomGeography.all.order(:name)
    elsif current_user.transportation_staff? || current_user.transportation_admin?
      CustomGeography.where(agency_id: current_user.staff_agency.id).order(:name)
    elsif current_user.currently_oversight? || current_user.currently_transportation?
      CustomGeography.where(agency_id: current_user.current_agency.id).order(:name)
    elsif current_user.staff_agency.oversight? && current_user.current_agency.nil?
      CustomGeography.where(agency_id: nil).order(:name)
    end
  end

  protected

  def check_for_missing_geometries(*collections)
    messages = []
    collections.each do |collection|
      missing_geoms = collection.where(geom: nil)
      if missing_geoms.count > 0
        messages << "The following #{collection.klass.name.titleize.pluralize} are missing geometry data and should be re-uploaded: #{missing_geoms.pluck(:name).join(', ')}"
      end
    end
    flash[:warning] = messages.join("<br/>").html_safe unless messages.empty?
  end

end
