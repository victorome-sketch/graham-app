# frozen_string_literal: true

# Covers the redesigned New analysis page: completion progress, the error
# summary, financial-company mode, the mobile action bar, both themes, and the
# "Edit inputs & re-run" round trip. The results-page assertions stay in
# analysis_flow_test.rb — this file only exercises the input side.

require "application_system_test_case"

class NewAnalysisFormTest < ApplicationSystemTestCase
  SCREENSHOT_DIR = Rails.root.join("tmp/screenshots")

  # Same worked example as analysis_flow_test.rb, keyed by the redesigned
  # labels (units moved into the field affix, so they left the label text).
  EXAMPLE_A = {
    "Ticker" => "STL",
    "Share price" => "24",
    "Annual revenue" => "900",
    "Current assets" => "500",
    "Current liabilities" => "200",
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
    "Consecutive years of dividends" => "25",
    "Book value per share" => "20"
  }.freeze

  PROGRESS_CARD = "[data-testid='progress-card']".freeze
  MOBILE_BAR = "[data-testid='mobile-action-bar']".freeze

  setup do
    FileUtils.mkdir_p(SCREENSHOT_DIR)
    @user = users(:one)
    resize_to(1400, 1400)
    log_in
  end

  test "completion progress counts every required value and only claims readiness when complete" do
    within(PROGRESS_CARD) do
      assert_heading "Input progress"
      assert_selector ".figure-lg", exact_text: "0"
      assert_text "of 17"
      assert_text "01 Company"
      assert_text "0/1"
      assert_text "0/10"
    end

    fill_in "Ticker", with: "STL"
    within(PROGRESS_CARD) do
      assert_selector ".figure-lg", exact_text: "1"
      assert_heading "Input progress"
      # A finished section reports "done" rather than "1/1".
      assert_text "done"
    end

    # An optional field never moves the count.
    fill_in "Company name", with: "Steady Corp"
    within(PROGRESS_CARD) { assert_selector ".figure-lg", exact_text: "1" }

    fill_example_a
    within(PROGRESS_CARD) do
      assert_heading "Ready to run"
      assert_selector ".figure-lg", exact_text: "17"
      assert_text "of 17"
      assert_text "done", count: 4
    end
    shoot "new-ready-desktop"
  end

  test "labels never change as the user types" do
    label_text = -> { find("label[for='ticker']").text }

    assert_equal "Ticker", label_text.call
    fill_in "Ticker", with: "STL"
    assert_equal "Ticker", label_text.call
    fill_in "Ticker", with: ""
    assert_equal "Ticker", label_text.call

    # Requiredness is stated once for the whole form, and the single optional
    # field is marked statically.
    assert_text "Every field is required unless marked optional"
    assert_equal "Company name optional", find("label[for='company_name']").text
    fill_in "Company name", with: "Steady Corp"
    assert_equal "Company name optional", find("label[for='company_name']").text
  end

  test "server-side validation errors surface in the summary, on the field, and in the progress heading" do
    fill_example_a
    # Values the browser's own `required` accepts but Rails rejects.
    fill_in "Ticker", with: "TOOLONGTICKER"
    fill_in "Current liabilities", with: "0"
    fill_in "3 years ago", with: "n/a"
    click_on "Run checklist"

    assert_selector "[role='alert']", text: "3 fields need attention"
    within("[role='alert']") do
      assert_link "Ticker"
      assert_text "is too long"
      assert_link "Current liabilities"
      assert_text "must be greater than 0"
      assert_link "EPS — 3 years ago"
      assert_text "must be a number"
    end

    # The summary takes focus when it arrives, and its links move focus to the
    # field they name.
    assert_selector "[role='alert']:focus"
    within("[role='alert']") { click_link "Current liabilities" }
    assert_selector "#current_liabilities:focus"

    # Inline messages and aria-invalid stay on the fields themselves.
    assert_selector "#ticker[aria-invalid='true']"
    assert_selector "#current_liabilities[aria-invalid='true']"
    assert_selector "#eps_4[aria-invalid='true']"
    assert_selector "#eps_4-error", text: "must be a number"

    # Every value is present, so the count is full — but errors are outstanding,
    # so the card must not claim readiness.
    within(PROGRESS_CARD) do
      assert_heading "Input progress"
      assert_no_heading "Ready to run"
      assert_selector ".figure-lg", exact_text: "17"
    end
    shoot "new-errors-desktop"
  end

  test "financial-company mode disables the balance-sheet fields once and drops them from the total" do
    fill_example_a
    within(PROGRESS_CARD) { assert_heading "Ready to run" }

    check "This is a financial company (bank or insurer)"

    assert_field "Current assets", disabled: true
    assert_field "Current liabilities", disabled: true
    assert_text "Skipped — you marked this as a financial company, so rule 2 reports N/A."

    within(PROGRESS_CARD) do
      assert_heading "Ready to run"
      assert_selector ".figure-lg", exact_text: "15"
      assert_text "of 15"
    end

    # One dim, not two: the wrapper carries the disabled treatment and the
    # control inside it stays fully opaque, so the value remains readable.
    assert_equal "1",
                 page.evaluate_script(
                   "getComputedStyle(document.getElementById('current_assets')).opacity"
                 )
    # The label is outside the disabled wrapper and keeps full contrast.
    assert_equal "1",
                 page.evaluate_script(
                   "getComputedStyle(document.querySelector(\"label[for='current_assets']\")).opacity"
                 )
    shoot "new-financial-desktop"

    unchecking_restores_the_pair
  end

  test "mobile puts the action in a fixed bar and never scrolls sideways" do
    resize_to(375, 812)
    # The stylesheet scrolls smoothly; the geometry checks below read positions
    # synchronously after scrollIntoView/focus, so make scrolling instant here.
    page.execute_script("document.documentElement.style.scrollBehavior = 'auto'")

    # The sidebar's own submit is hidden below `lg`; the bar carries the action.
    assert_selector MOBILE_BAR, visible: true
    within(MOBILE_BAR) do
      assert_text "0 of 17 entered"
      assert_button "Run checklist"
    end

    fill_example_a
    within(MOBILE_BAR) { assert_text "17 of 17 entered" }

    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"),
           "new analysis page scrolls horizontally at 375px"

    # The bar must not sit on top of the last field.
    # scroll-margin-bottom, not the form's padding, is what keeps a control
    # the browser scrolls to from landing under the fixed bar.
    assert page.evaluate_script(<<~JS), "mobile action bar overlaps the last form field"
      (() => {
        const bar = document.querySelector("#{MOBILE_BAR}").getBoundingClientRect();
        const last = document.getElementById("bvps");
        last.scrollIntoView({ block: "end" });
        return last.getBoundingClientRect().bottom <= bar.top;
      })()
    JS

    # Same guarantee via focus, which is how a user actually gets there.
    assert page.evaluate_script(<<~JS), "focused field sits under the mobile action bar"
      (() => {
        const bar = document.querySelector("#{MOBILE_BAR}").getBoundingClientRect();
        const field = document.getElementById("eps_10");
        field.focus();
        return field.getBoundingClientRect().bottom <= bar.top;
      })()
    JS

    shoot "new-mobile-light"
    page.execute_script("document.documentElement.classList.add('dark')")
    shoot "new-mobile-dark"
    page.execute_script("document.documentElement.classList.remove('dark')")

    click_on "Run checklist"
    assert_selector "h1", text: "STL"

    resize_to(1400, 1400)
  end

  test "light and dark render at every review width" do
    fill_example_a
    [ [ 375, 2400 ], [ 1024, 1400 ], [ 1280, 1400 ], [ 1440, 1400 ] ].each do |width, height|
      resize_to(width, height)
      shoot "new-#{width}-light"
      page.execute_script("document.documentElement.classList.add('dark')")
      shoot "new-#{width}-dark"
      page.execute_script("document.documentElement.classList.remove('dark')")
    end
    resize_to(1400, 1400)
  end

  test "edit inputs and re-run returns every value, the flag, and a full progress count" do
    fill_example_a
    check "This is a financial company (bank or insurer)"
    fill_in "Company name", with: "Steady Corp"
    click_on "Run checklist"
    assert_selector "h1", text: "STL"

    click_on "Edit inputs & re-run"

    assert_checked_field "This is a financial company (bank or insurer)"
    assert_field "Ticker", with: "STL"
    assert_field "Company name", with: "Steady Corp"
    assert_field "7 years ago", with: "1.30"
    EXAMPLE_A.except("Ticker").each { |label, value| assert_field label, with: value, disabled: :all }

    within(PROGRESS_CARD) do
      assert_heading "Ready to run"
      assert_selector ".figure-lg", exact_text: "15"
    end
  end

  private
    # The card's heading is uppercased by CSS (text-transform), and Selenium
    # reports rendered text, so a case-sensitive match on the source copy fails
    # — and, worse, a negative one passes vacuously.
    def assert_heading(text) = assert_text(/#{Regexp.escape(text)}/i)
    def assert_no_heading(text) = assert_no_text(/#{Regexp.escape(text)}/i)

    def log_in
      visit "/login"
      fill_in "Email", with: @user.email
      fill_in "Password", with: "password" # matches test/fixtures/users.yml
      click_on "Log in"
      assert_text "New analysis"
    end

    def fill_example_a
      EXAMPLE_A.each { |label, value| fill_in label, with: value }
    end

    def unchecking_restores_the_pair
      uncheck "This is a financial company (bank or insurer)"
      assert_field "Current assets", disabled: false
      assert_text "Rule 2 needs current assets ÷ current liabilities to be at least 2."
      within(PROGRESS_CARD) { assert_text "of 17" }
    end

    # Review screenshots are taken right after toggling `.dark`; without this
    # the design system's colour transitions are caught mid-way and the light
    # shots come out grey.
    def shoot(name)
      page.execute_script(<<~JS)
        if (!document.getElementById("no-transitions")) {
          document.head.insertAdjacentHTML("beforeend", '<style id="no-transitions">* { transition: none !important; }</style>');
        }
      JS
      save_screenshot(SCREENSHOT_DIR.join("#{name}.png").to_s)
    end

    def resize_to(width, height)
      page.driver.browser.manage.window.resize_to(width, height)
    end
end
