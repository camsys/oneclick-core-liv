class BookingWindow < ApplicationRecord
  belongs_to :agency
  has_many :travel_patterns, dependent: :restrict_with_error

  validates_presence_of :agency, :name, :minimum_days_notice, :maximum_days_notice, :minimum_notice_cutoff_hour
  validates :minimum_days_notice, numericality: { less_than_or_equal_to: :maximum_days_notice }
  validate :valid_booking_notice

  scope :for_superuser, -> {all}
  scope :for_oversight_user, -> (user) {where(agency: user.current_agency.agency_oversight_agency.pluck(:transportation_agency_id).concat([user.current_agency.id]))}
  scope :for_current_transport_user, -> (user) {where(agency: user.current_agency)}
  scope :for_transport_user, -> (user) {where(agency: user.staff_agency)}

  def self.active_service_days_up_to(end_date)
    # Find all service schedules active up to the given end_date
    ServiceSubSchedule
      .where("day <= ?", end_date.wday) # Ensure we're within the day range (Monday to Sunday)
      .or(ServiceSubSchedule.where(calendar_date: Date.current..end_date)) # Handle specific calendar dates
      .distinct
      .pluck(:day) # Get all relevant days with activity
      .size # Count unique active days
  end

  # Updated `for_date` scope
  scope :for_date, ->(date) do
    active_days_count = active_service_days_up_to(date) # Only count relevant days
    current_hour = Time.now.hour

    Rails.logger.info ">> Entering BookingWindow.for_date with date: #{date}, active days count: #{active_days_count}, current_hour: #{current_hour}"

    query = where(
      arel_table[:minimum_days_notice].eq(active_days_count)
                                      .and(arel_table[:minimum_notice_cutoff_hour].gt(current_hour))
                                      .or(arel_table[:minimum_days_notice].lt(active_days_count))
    ).where(
      arel_table[:maximum_days_notice].gteq(active_days_count)
    )

    Rails.logger.info "Generated BookingWindow SQL: #{query.to_sql}"
    results = query.to_a

    results.each do |window|
      Rails.logger.info "BookingWindow ID: #{window.id}, Min Days: #{window.minimum_days_notice}, Max Days: #{window.maximum_days_notice}, Cutoff Hour: #{window.minimum_notice_cutoff_hour}"
    end

    Rails.logger.info ">> Exiting BookingWindow.for_date with results: #{results.map(&:id)}"
    query
  end
  

  def earliest_booking
    present = DateTime.now
    additional_notice = minimum_notice_cutoff_hour <= present.hour ? 1 : 0
    (present + (minimum_days_notice + additional_notice).days).beginning_of_day
  end

  def latest_booking
    present = DateTime.now
    (present + maximum_days_notice.days).end_of_day
  end

  private

  def valid_booking_notice
    max_notice = Config.maximum_booking_notice
    [:minimum_days_notice, :maximum_days_notice].each do |attribute|
      if self[attribute].present?
        self.errors.add(attribute, "must be less than or equal to #{max_notice}") unless self[attribute] <= max_notice
        self.errors.add(attribute, "must be greater than or equal to 1") unless self[attribute] >= 1
      end
    end
  end

  def self.for_user(user)
    if user.superuser?
      for_superuser
    elsif user.currently_oversight?
      for_oversight_user(user)
    elsif user.currently_transportation?
      for_current_transport_user(user)
    elsif user.transportation_user?
      for_transport_user(user)
    else
      nil
    end
  end
end
