require 'digest/sha1'
class User
  # Virtual attribute for the unencrypted password
  attr_accessor :password

  validates_presence_of     :login, :email
  validates_presence_of     :password,                   :if => :password_required?
  validates_presence_of     :password_confirmation,      :if => :password_required?
  validates_length_of       :password, :within => 4..40, :if => :password_required?
  validates_confirmation_of :password,                   :if => :password_required?
  validates_length_of       :login,    :within => 3..40
  validates_length_of       :email,    :within => 3..100
  validates_uniqueness_of   :login, :email, :scope => :group_id
  before_save :downcase_email_and_login
  before_save :encrypt_password
  before_create :set_first_user_as_admin

  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  attr_accessible :login, :email, :password, :password_confirmation, :bio

  def authenticated?(password)
    crypted_password == encrypt(password)
  end

protected    
  def password_required?
    crypted_password.blank? || !password.blank?
  end
  
  def set_first_user_as_admin
    self.admin = true if group and group.users.size.zero?
  end
  
  def downcase_email_and_login
    login.downcase!
    email.downcase!
  end
end