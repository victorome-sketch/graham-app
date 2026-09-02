require "application_system_test_case"

class AnalysisFlowTest < ApplicationSystemTestCase
  SCREENSHOT_DIR = Rails.root.join("tmp/screenshots")

  # Worked example A: every rule passes, price below the Graham Number.
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

  # Worked example C (see test/models/graham/checklist_test.rb): one pass, six
  # fails, price three times the Graham Number.
  EXAMPLE_C = {
    "Ticker" => "JUNK",
    "Share price ($)" => "45",
    "Annual revenue ($ millions)" => "300",
    "Current assets ($ millions)" => "150",
    "Current liabilities ($ millions)" => "100",
    "Latest year" => "1.00",
    "1 year ago" => "-0.40",
    "2 years ago" => "0.60",
    "3 years ago" => "0.55",
    "4 years ago" => "0.50",
    "5 years ago" => "0.45",
    "6 years ago" => "0.40",
    "7 years ago" => "0.30",
    "8 years ago" => "0.20",
    "9 years ago" => "0.10",
    "Consecutive years of dividends paid" => "5",
    "Book value per share ($)" => "10"
  }.freeze

  LONG_NAME = "The Very Long Industrial Conglomerate Holdings Corporation of North America".freeze

  VERDICT_PANEL = "section[aria-labelledby='verdict-heading']".freeze
  INPUTS_RECAP = "section[aria-labelledby='inputs-heading']".freeze

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

    within(VERDICT_PANEL) do
      assert_selector ".figure-xl", exact_text: "7"
      assert_text "of 7"
      assert_no_text "Fails rule"
      assert_selector "dt", text: "Graham Number"
      assert_selector "dd", text: "$30.00"
      assert_selector "dt", text: "Current price"
      assert_selector "dd", text: "$24.00"
      assert_selector "dd.text-affirm-display", text: "+20.0%"
      assert_text "ceiling $30.00"
      assert_text "√(22.5 × EPS $2.00 × book value $20.00) = $30.00"
    end
    assert_selector "li[data-verdict='pass']", count: 7
    assert_selector ".badge", text: "Pass", count: 7, visible: :all
    assert_selector "h3", text: "1. Adequate size"
    assert_text "0 fail · 7 pass"
    within("li[data-rule='adequate_size']") do
      assert_text "Revenue meets the minimum."
      assert_text "$900M ≥ $700M minimum"
    end
    assert_selector "a", text: "Edit inputs & re-run", count: 1
    assert_text "Nothing here is investment advice."

    # The inputs recap is open by default on desktop and echoes raw strings.
    within(INPUTS_RECAP) do
      assert_text "Share price ($)"
      assert_selector ".figure", exact_text: "24"
      assert_text "Latest year"
      assert_selector ".figure", exact_text: "2.00"
      assert_selector ".figure", exact_text: "1.20"
      assert_text "Financial company (bank or insurer)"
      assert_text "No"
    end
    shoot_responsive "results-all-pass"

    click_on "Edit inputs & re-run"
    assert_field "Ticker", with: "STL"
    assert_field "7 years ago", with: "1.30"

    check "This is a financial company (bank or insurer)"
    assert_field "Current assets ($ millions)", disabled: true
    click_on "Run checklist"

    within(VERDICT_PANEL) do
      assert_selector ".figure-xl", exact_text: "7"
      assert_text "Includes 1 not-applicable rule"
      assert_no_text "Fails rule"
    end
    assert_selector "li[data-verdict='na']", count: 1
    assert_selector ".badge", text: "N/A", count: 1, visible: :all
    within("li[data-rule='financial_condition']") do
      assert_text "Not applied — Graham never fails banks and insurers on the current-ratio test."
      assert_no_selector ".font-mono" # nothing to compute, so no derivation column
    end
    assert_text "0 fail · 6 pass · 1 N/A"
    within(INPUTS_RECAP) do
      assert_text "Yes"
      assert_text "not used — financial company"
    end
    shoot "results-financial-na"

    # Every field, including the flag and all ten EPS years, survives the round trip.
    click_on "Edit inputs & re-run"
    assert_checked_field "This is a financial company (bank or insurer)"
    assert_field "Ticker", with: "STL"
    # Current assets/liabilities stay disabled for a financial company, but keep their values.
    EXAMPLE_A.except("Ticker").each { |label, value| assert_field label, with: value, disabled: :all }
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

    within(VERDICT_PANEL) do
      assert_selector ".figure-xl", exact_text: "6"
      assert_text "Fails rule 1."
    end
    assert_selector "li[data-verdict='fail']", count: 1
    assert_selector ".badge", text: "Fail", count: 1, visible: :all
    within("li[data-rule='adequate_size']") do
      assert_text "Revenue is below the minimum."
      assert_text "$900M < $1,000M minimum"
    end
    assert_text "1 fail · 6 pass"
    shoot "results-threshold-fail"
  end

  test "edge cases: negative latest EPS, N/A growth base, negative book value, long company name" do
    log_in

    fill_example_a
    fill_in "Company name", with: LONG_NAME
    fill_in "Latest year", with: "-6.00"
    fill_in "Book value per share ($)", with: "10"
    # Mount the results page at phone width: the recap must start collapsed there.
    resize_to(375, 2600)
    click_on "Run checklist"

    assert_selector "h1", text: "STL"
    assert_selector "h1", text: LONG_NAME
    within(VERDICT_PANEL) do
      assert_selector ".figure-xl", exact_text: "3"
      assert_text "Fails rules 3, 5, 6 and 7."
      assert_text "Not computable"
      assert_selector "dt", text: "Latest EPS"
      assert_selector "dd", text: "-$6.00"
      assert_selector "dd", text: "$10.00"
      assert_no_selector "dt", text: "Margin"
      assert_no_text "ceiling"
    end
    within("li[data-rule='earnings_stability']") do
      assert_text "EPS was not positive in every one of the last 10 years"
      assert_text "9 of 10 years positive"
    end
    within("li[data-rule='moderate_pe']") do
      assert_text "The 3-year average EPS is not positive, so no price can satisfy Graham's 15× ceiling."
      assert_text "3-year average EPS -$0.67"
    end
    within("li[data-rule='moderate_pb']") do
      assert_text "the P/E × P/B fallback is not computable"
      assert_text "P/B 2.40 · ceiling 1.5"
      assert_no_text "allowance"
    end
    assert_no_text "NaN"

    # Still at phone width: nothing may overflow, and the recap starts collapsed.
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"),
           "results page scrolls horizontally at 375px"
    within(INPUTS_RECAP) { assert_no_selector ".figure", exact_text: "-6.00" }
    find("summary", text: "As entered").click
    within(INPUTS_RECAP) { assert_selector ".figure", exact_text: "-6.00" }
    resize_to(1400, 1400)
    shoot_responsive "results-not-computable"

    # A non-positive years 8–10 average makes rule 5 N/A for a non-financial company.
    click_on "Edit inputs & re-run"
    assert_field "Company name", with: LONG_NAME
    fill_in "7 years ago", with: "0.10"
    fill_in "8 years ago", with: "0.00"
    fill_in "9 years ago", with: "-0.10"
    click_on "Run checklist"

    within(VERDICT_PANEL) do
      assert_selector ".figure-xl", exact_text: "4"
      assert_text "Fails rules 3, 6 and 7."
      assert_text "Includes 1 not-applicable rule"
    end
    within("li[data-rule='earnings_growth']") do
      assert_text "Not computable — the average EPS of years 8–10 was not positive"
      assert_text "years 8–10 average EPS $0.00"
    end
    assert_selector "li[data-verdict='na']", count: 1

    # A negative book value takes rule 7 down the bvps_not_positive branch.
    click_on "Edit inputs & re-run"
    fill_in "Book value per share ($)", with: "-5"
    click_on "Run checklist"

    within("li[data-rule='moderate_pb']") do
      assert_text "Book value per share is not positive, so price-to-book cannot be computed."
      assert_no_text "ceiling 1.5"
    end
    within(VERDICT_PANEL) do
      assert_text "Not computable"
      assert_selector "dd", text: "-$5.00"
    end
    assert_no_text "NaN"
  end

  test "worked example C: mixed verdicts with the price far above the Graham Number" do
    log_in

    EXAMPLE_C.each { |label, value| fill_in label, with: value }
    click_on "Run checklist"

    within(VERDICT_PANEL) do
      assert_selector ".figure-xl", exact_text: "1"
      assert_text "Fails rules 1, 2, 3, 4, 6 and 7."
      assert_selector "dd", text: "$15.00"
      assert_selector "dd", text: "$45.00"
      assert_selector "dd.text-danger-display", text: "-200.0%"
      assert_text "ceiling $15.00"
      assert_text "price $45.00"
    end
    assert_selector "li[data-verdict='fail']", count: 6
    assert_selector "li[data-verdict='pass']", count: 1
    assert_text "6 fail · 1 pass"
    within("li[data-rule='moderate_pe']") do
      assert_text "Price is above 15× the 3-year average EPS."
      assert_text "$45.00 ÷ $0.40 = 112.50×"
      assert_text "ceiling 15× ($6.00)"
    end
    within("li[data-rule='moderate_pb']") do
      assert_text "P/E × P/B exceeds the 22.5 allowance."
      assert_text "P/B 4.50 · ceiling 1.5"
      assert_text "P/E × P/B 506.25"
      assert_text "allowance 22.5"
    end
    within("li[data-rule='earnings_growth']") do
      assert_text "Growth in 3-year average EPS meets the required +33%."
      assert_text "$0.20 → $0.40 = +100.0%"
    end
    shoot_responsive "results-mixed"
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

    # Full-page captures at the three review widths, light and dark. Dark mode
    # is the `dark` class on <html>, which is exactly what the ThemeToggle sets.
    def shoot_responsive(name)
      [ [ 375, 2600 ], [ 768, 2200 ], [ 1440, 1600 ] ].each do |width, height|
        resize_to(width, height)
        shoot "#{name}-#{width}-light"
        page.execute_script("document.documentElement.classList.add('dark')")
        shoot "#{name}-#{width}-dark"
        page.execute_script("document.documentElement.classList.remove('dark')")
      end
      resize_to(1400, 1400)
    end

    def resize_to(width, height)
      page.driver.browser.manage.window.resize_to(width, height)
    end
end
