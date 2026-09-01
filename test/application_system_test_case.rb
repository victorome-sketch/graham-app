require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # The first page hit of a run can still be warming up (Vite test bundle,
  # app boot); the 2s Capybara default is tight enough to flake on it.
  Capybara.default_max_wait_time = 5
end
