class User
  include Mongoid::Document
  has_many :user_roles
end