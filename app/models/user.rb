class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :analyses, dependent: :destroy

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 7 }, allow_nil: true

  # `timezone` is a nullable IANA name; unknown or blank falls back to the app
  # zone. (ActiveSupport::TimeZone[nil] raises, hence the presence guard.)
  def time_zone = (timezone.present? && ActiveSupport::TimeZone[timezone]) || Time.zone
end
