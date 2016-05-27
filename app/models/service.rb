class Service < ActiveRecord::Base
	include Authorizable

	belongs_to :coordinator, class_name: 'User'
	belongs_to :administrator, class_name: 'User'
	belongs_to :representative
	belongs_to :reservation
	belongs_to :table
	belongs_to :organization

	validates :quantity, numericality: { greater_than_or_equal_to: 1 }
	validates :date, :quantity, :client, :administrator, :coordinator, :table, presence: true
	validate :administrator_clearance, :schedule_uniqueness, :ensure_reservation_integrity, :organization_equality
	validates :organization, presence: true

	after_destroy :set_reservation_status_pending!

	enum status: [:incomplete, :seated, :complete]

	# Receives a reservation object and copies its 
	# attributes into the service, also uses the 
	# reservation's id for the services' association.
	def self.build_from_reservation(reservation, administrator = nil, table = nil)
		Service.new(client: reservation.client, coordinator: reservation.user,
						representative_id: reservation.representative.id, quantity: reservation.quantity,
						date: reservation.date, reservation_id: reservation.id,
						administrator: administrator, table: table)
	end

	# Builds the object and creates it after having the received administrator assigned to ti
	def self.create_from_reservation(reservation, administrator, table)
		service = Service.build_from_reservation reservation, administrator, table
		service.save
		service
	end

	# Will return all services on that day
	def self.by_date(date)
		Service.where(date: date.beginning_of_day..date.end_of_day)
	end


	# Receives a user object and updates the
	# calling service to have the user as its coordinator.
	def coordinated_by!(user)
		self.update(coordinator: user)
	end

	# Returns true if the user is the 
	# services' coordinator.
	def coordinated_by?(user)
		return self.coordinator == user ? true : false
	end

	# Receives a user object and updates the
	# calling service to have the user as its administrator.
	def administered_by!(user)
		self.update(administrator: user)
	end

	# Returns true if the user is the 
	# services' administrator.
	def administered_by?(user)
		return self.administrator == user ? true : false
	end

	# Checks the administering user for the appropiate clearance.
	def administrator_clearance
		errors.add(:administrator, "User doesn't have administrator clearance.") unless
												 has_clearance?(administrator, "administrator") if 
												 administrator.present?
	end

	# There must not be two services using the same table at the same time
	def schedule_uniqueness
		errors.add(:date, "Table is already occupied for that date.") if
											 Service.by_date(date).where(table_id: table.id, status: "incomplete").where.not(id: id).any? if
											 date.present? && table.present?
	end

	# if the service has a reservation, it must not change the values
	# set by the reservation (it does not check for values that can't be changed)
	def ensure_reservation_integrity
		if reservation.present?
			errors.add(:date, "Service's date has been set by the reservation.") unless date == reservation.date
		end
	end

	# will change the reservation to pending if the service was destroyed
	def set_reservation_status_pending!
		reservation.pending! if reservation.present? && !reservation.pending?
	end

	def organization_equality
		if administrator && organization != administrator.organization
			errors.add(:organization, "Must be the same organization as the creating administrator's.")
		end
	end
end
