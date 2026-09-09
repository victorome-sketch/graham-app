require "application_system_test_case"

# Milestone 3 "done when": runs appear in History newest-first, an old one
# reopens exactly as it was, re-running creates a second record beside it, and
# deleting removes one.
class SavedHistoryTest < ApplicationSystemTestCase
  SCREENSHOT_DIR = Rails.root.join("tmp/screenshots")

  # Worked example A: every rule passes, price below the Graham Number.
  EXAMPLE_A = {
    "Ticker" => "STL",
    "Company name" => "Steady Corp",
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

  # Worked example C: one pass, six fails, price three times the Graham Number.
  EXAMPLE_C = {
    "Ticker" => "JUNK",
    "Share price" => "45",
    "Annual revenue" => "300",
    "Current assets" => "150",
    "Current liabilities" => "100",
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
    "Consecutive years of dividends" => "5",
    "Book value per share" => "10"
  }.freeze

  VERDICT_PANEL = "section[aria-labelledby='verdict-heading']".freeze
  HISTORY_LIST = "[data-testid='history-list']".freeze
  HISTORY_ROWS = "#{HISTORY_LIST} li".freeze

  setup do
    FileUtils.mkdir_p(SCREENSHOT_DIR)
    @user = users(:one)
  end

  test "runs are saved, listed newest-first, reopen frozen, re-run as new records, and can be deleted" do
    log_in

    # A run lands on its own saved page, which survives a hard refresh.
    fill_in_all EXAMPLE_A
    click_on "Run checklist"
    assert_current_path %r{\A/analyses/\d+\z}
    assert_text "Run on"
    within(VERDICT_PANEL) { assert_selector ".figure-xl", exact_text: "7" }
    refresh
    within(VERDICT_PANEL) { assert_selector ".figure-xl", exact_text: "7" }
    assert_selector "a", text: "Edit inputs & re-run", count: 1
    assert_selector "button", text: "Delete", count: 1
    shoot_responsive "results-saved"

    # A second ticker.
    visit "/analyses/new"
    fill_in_all EXAMPLE_C
    click_on "Run checklist"
    assert_current_path %r{\A/analyses/\d+\z}

    # History (via the nav) lists both, newest first, with X-of-7 and margin.
    find("a[href='/analyses']", match: :first).click
    assert_current_path "/analyses"
    assert_text "2 saved analyses."
    assert_selector HISTORY_ROWS, count: 2
    rows = all(HISTORY_ROWS)
    assert_match(/JUNK.*1 of 7.*-200\.0%/m, rows[0].text)
    assert_match(/STL.*Steady Corp.*7 of 7.*\+20\.0%/m, rows[1].text)
    shoot_responsive "history"

    # Raising the threshold afterwards must not touch the saved run.
    visit "/settings"
    fill_in "Revenue threshold ($ millions)", with: "1000"
    click_on "Save settings"
    assert_text "Settings updated."

    visit "/analyses"
    all(HISTORY_ROWS).last.find("a").click
    within(VERDICT_PANEL) do
      assert_selector ".figure-xl", exact_text: "7"
      assert_no_text "Fails rule"
    end
    assert_selector "li[data-verdict='pass']", count: 7
    within("li[data-rule='adequate_size']") { assert_text "$900M ≥ $700M minimum" }
    assert_text "The revenue minimum used for this run ($700M)"

    # Re-running is prefilled from the snapshot and saves a new record, which
    # is computed against the new threshold while the original stays intact.
    click_on "Edit inputs & re-run"
    assert_text "Re-running STL"
    assert_field "Ticker", with: "STL"
    assert_field "Share price", with: "24"
    assert_field "Latest year", with: "2.00"
    assert_field "9 years ago", with: "1.20"
    shoot "analyses-new-rerun"
    click_on "Run checklist"
    assert_current_path %r{\A/analyses/\d+\z}
    within(VERDICT_PANEL) { assert_selector ".figure-xl", exact_text: "6" }

    visit "/analyses"
    assert_text "3 saved analyses."
    assert_selector HISTORY_ROWS, count: 3
    rows = all(HISTORY_ROWS)
    assert_match(/STL.*6 of 7/m, rows[0].text)
    assert_match(/JUNK.*1 of 7/m, rows[1].text)
    assert_match(/STL.*7 of 7/m, rows[2].text)

    # Deleting asks first, then returns to History with a notice.
    rows[0].find("a").click
    click_on "Delete", exact: true
    within("[role='dialog']") do
      assert_text "Delete this analysis?"
      assert_text "The STL checklist run on"
      shoot "delete-dialog"
      click_on "Delete analysis"
    end
    assert_current_path "/analyses"
    assert_text "Analysis deleted."
    assert_text "2 saved analyses."
    assert_selector HISTORY_ROWS, count: 2
    shoot "history-after-delete"

    # Cancelling leaves the record alone.
    all(HISTORY_ROWS).first.find("a").click
    click_on "Delete", exact: true
    within("[role='dialog']") { click_on "Cancel" }
    assert_no_selector "[role='dialog']"
    assert_current_path %r{\A/analyses/\d+\z}

    # Delete the rest: the empty state points back to the form.
    2.times do
      visit "/analyses"
      all(HISTORY_ROWS).first.find("a").click
      click_on "Delete", exact: true
      within("[role='dialog']") { click_on "Delete analysis" }
      assert_current_path "/analyses"
      assert_text "Analysis deleted."
    end
    assert_text "0 saved analyses."
    assert_text "No analyses yet"
    assert_no_selector HISTORY_LIST
    shoot_responsive "history-empty"
  end

  private
    def log_in
      visit "/login"
      fill_in "Email", with: @user.email
      fill_in "Password", with: "password" # matches test/fixtures/users.yml
      click_on "Log in"
      assert_text "New analysis" # the analysis form is the post-login home
    end

    def fill_in_all(fields)
      fields.each { |label, value| fill_in label, with: value }
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
