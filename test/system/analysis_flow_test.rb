require "application_system_test_case"

class AnalysisFlowTest < ApplicationSystemTestCase
  SCREENSHOT_DIR = Rails.root.join("tmp/screenshots")

  EXAMPLE_A = {
    "Ticker" => "STL",
    "Share price ($)" => "24",
    "Annual revenue ($ millions)" => "900",
    "Current assets ($ millions)" => "500",
    "Current liabilities ($ millions)" => "200",
    "Latest year" => "2.00",
    "1 year ago" => "2.10",
    "2 years ago" => "1.90",
    "3 years ago" => "1.80",
    "4 years ago" => "1.70",
    "5 years ago" => "1.60",
    "6 years ago" => "1.50",
    "7 years ago" => "1.30",
    "8 years ago" => "1.25",
    "9 years ago" => "1.20",
    "Consecutive years of dividends paid" => "25",
    "Book value per share ($)" => "20"
  }.freeze

  setup do
    FileUtils.mkdir_p(SCREENSHOT_DIR)
    @user = users(:one)
  end

  test "worked example A end to end, then the financial-company N/A variant" do
    log_in

    resize_to(375, 812)
    shoot "analyses-new-mobile"
    resize_to(1400, 1400)

    fill_example_a
    shoot "analyses-new-desktop"

    click_on "Run checklist"

    assert_text "7 of 7 criteria met"
    assert_text "Graham Number $30.00 vs. price $24.00 — margin +20.0%"
    assert_selector ".badge", text: "Pass", count: 7
    assert_text "Nothing here is investment advice."
    shoot "results-all-pass"

    click_on "Edit inputs & re-run", match: :first
    assert_field "Ticker", with: "STL"

    check "This is a financial company (bank or insurer)"
    assert_field "Current assets ($ millions)", disabled: true
    click_on "Run checklist"

    assert_text "7 of 7 criteria met"
    assert_text "Includes 1 not-applicable rule"
    assert_selector ".badge", text: "N/A", count: 1
    shoot "results-financial-na"
  end

  test "changing the revenue threshold flips rule 1 to a fail" do
    log_in

    visit "/settings"
    fill_in "Revenue threshold ($ millions)", with: "1000"
    click_on "Save settings"
    assert_text "Settings updated."
    shoot "settings"

    visit "/analyses/new"
    fill_example_a
    click_on "Run checklist"

    assert_text "6 of 7 criteria met"
    assert_text "Revenue of $900M is below the $1,000M minimum."
    assert_selector ".badge", text: "Fail", count: 1
    shoot "results-threshold-fail"
  end

  private
    def log_in
      visit "/login"
      fill_in "Email", with: @user.email
      fill_in "Password", with: "password" # matches test/fixtures/users.yml
      click_on "Log in"
      assert_text "New analysis" # the analysis form is the post-login home
    end

    def fill_example_a
      EXAMPLE_A.each { |label, value| fill_in label, with: value }
    end

    def shoot(name)
      save_screenshot(SCREENSHOT_DIR.join("#{name}.png").to_s)
    end

    def resize_to(width, height)
      page.driver.browser.manage.window.resize_to(width, height)
    end
end
