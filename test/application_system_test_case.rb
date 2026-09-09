require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    # Every test logs in with the fixture password "password", which Chrome's
    # password manager flags as breached. Chrome's headless mode now runs the
    # full browser UI, so a moment after the login navigation it opens a modal
    # "Change your password" dialog — and while that dialog is up the page
    # silently drops keyboard and mouse input. Fills and clicks vanish without
    # Selenium noticing, which surfaced as a form that was never submitted.
    # Turn the password manager and its leak detection off for the test profile.
    options.add_preference("credentials_enable_service", false)
    options.add_preference("profile.password_manager_enabled", false)
    options.add_preference("profile.password_manager_leak_detection", false)
  end

  # The first page hit of a run can still be warming up (Vite test bundle,
  # app boot); the 2s Capybara default is tight enough to flake on it.
  Capybara.default_max_wait_time = 5
end
