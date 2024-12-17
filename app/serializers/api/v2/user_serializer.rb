module Api
  module V2

    class UserSerializer < ApiSerializer
      
      attributes  :first_name, 
                  :last_name, 
                  :email,
                  :preferred_locale,
                  :trip_types,
                  :age,
                  :county,
                  :paratransit_id,
                  :counties
      
      has_many :eligibilities
      has_many :accommodations
      has_many :trip_types
      has_many :counties
    
      def trip_types
        Trip::TRIP_TYPES.map do |trip_type|
          {
            code: trip_type,
            name: SimpleTranslationEngine.translate(locale, "mode_#{trip_type}_name"),
            value: (trip_type.to_s.in? (object.preferred_trip_types || []))
          }
        end
        
      def preferred_locale
        object.locale.try(:name)
      end

    end
    
  end
end
