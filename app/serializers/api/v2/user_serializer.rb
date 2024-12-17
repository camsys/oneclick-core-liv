module Api
  module V2
    class UserSerializer < ApiSerializer
      attributes :id, :first_name, :last_name, :email, :preferred_locale,
                 :trip_types, :age, :county, :paratransit_id

      has_many :eligibilities
      has_many :accommodations

      def counties
        County.all.map { |county| { name: county.name } }
      end

      def preferred_locale
        object.locale&.name
      end

      def trip_types
        Trip::TRIP_TYPES.map do |trip_type|
          {
            code: trip_type,
            name: SimpleTranslationEngine.translate(locale, "mode_#{trip_type}_name"),
            value: object.preferred_trip_types&.include?(trip_type.to_s)
          }
        end
      end
    end
  end
end
