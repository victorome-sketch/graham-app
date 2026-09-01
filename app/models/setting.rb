class Setting < ApplicationRecord
  validates :revenue_threshold_millions, presence: true, numericality: { greater_than: 0 }

  # Single-row table: app-wide configurable values live on one lazily-created
  # row whose initial values come from the column defaults.
  def self.instance
    first_or_create!
  end
end
