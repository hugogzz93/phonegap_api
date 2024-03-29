class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
	devise :database_authenticatable, :registerable,
        	:recoverable, :rememberable, :trackable, :validatable

  validates :auth_token, uniqueness: true
	validates :organization, presence: true
  validate :organization_equality
	before_create :generate_authentication_token!

  belongs_to :organization
  belongs_to :supervisor, class_name: "User"

  has_many :representatives,  dependent: :destroy
  has_many :reservations,     dependent: :destroy
  has_many :subordinates, class_name: "User", foreign_key: "supervisor_id"
  has_many :administered_services, class_name: "Service", foreign_key: 'administrator_id'
  has_many :coordinated_services, class_name: "Service", foreign_key: 'coordinator_id', 
                                                                          dependent: :destroy


	enum credentials: [:coordinator, :administrator, :super]

	def generate_authentication_token!
    begin
      	self.auth_token = Devise.friendly_token
    end while self.class.exists?(auth_token: auth_token)
  end

  def can_create?(user)
    self.outranks?(user)
  end

  def outranks?(user)
    return true if user.class.credentials[user.credentials] < self.class.credentials[credentials]
    return false
  end

  def belongs_to?(user)
    return self.supervisor_id == user.id if self.supervisor.present?
    return false
  end

  def belongs_to!(user)
    self.update(supervisor_id: user.id)
  end

  def build_service(attributes)
    service = Service.new(attributes)
    service.administrator = self
    service.coordinator = self
    service
  end

  def organization_equality
    if supervisor && supervisor.organization != organization
      errors.add("organization", "User must be in the same organization as supervisor.")
    end
  end

end
