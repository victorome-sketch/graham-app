require "test_helper"

class AnalysesControllerTest < ActionDispatch::IntegrationTest
  VALID_PARAMS = {
    ticker: "STL", company_name: "Steady Corp",
    price: "24", revenue: "900", current_assets: "500", current_liabilities: "200",
    eps_1: "2.00", eps_2: "2.10", eps_3: "1.90", eps_4: "1.80", eps_5: "1.70",
    eps_6: "1.60", eps_7: "1.50", eps_8: "1.30", eps_9: "1.25", eps_10: "1.20",
    dividend_years: "25", bvps: "20"
  }.freeze

  setup do
    @user = users(:one)
    @password = "password" # matches test/fixtures/users.yml
  end

  test "unauthenticated users are sent to login" do
    record = snapshot(@user)

    get analyses_path
    assert_redirected_to login_path

    get new_analysis_path
    assert_redirected_to login_path

    post analyses_path, params: VALID_PARAMS
    assert_redirected_to login_path

    get analysis_path(record)
    assert_redirected_to login_path

    delete analysis_path(record)
    assert_redirected_to login_path
  end

  test "GET new renders the form" do
    log_in_as(@user)
    get new_analysis_path
    assert_response :success
  end

  test "GET new accepts prefill query params" do
    log_in_as(@user)
    get new_analysis_path, params: { ticker: "KO", price: "60" }
    assert_response :success
  end

  test "GET index lists only the current user's analyses, newest first" do
    older = snapshot(@user)
    older.update_columns(created_at: 2.days.ago)
    newer = snapshot(@user, ticker: "KO", company_name: "Coca-Cola")
    snapshot(users(:two), ticker: "XOM")

    log_in_as(@user)
    get analyses_path, headers: inertia_headers
    assert_response :success

    page = JSON.parse(response.body)
    assert_equal "analyses/Index", page.fetch("component")

    rows = page.dig("props", "analyses")
    assert_equal [ "KO", "STL" ], rows.map { |row| row.fetch("ticker") }
    assert_equal [ newer.id, older.id ], rows.map { |row| row.fetch("id") }

    row = rows.first
    assert_equal analysis_path(newer), row.fetch("url")
    assert_equal "Coca-Cola", row.fetch("company_name")
    assert_equal 7, row.fetch("met_count")
    assert_equal 20.0, row.fetch("margin_pct")
    assert_equal newer.created_at.iso8601, row.fetch("ran_at")
    assert_equal newer.created_at.in_time_zone(@user.time_zone).strftime(AnalysesController::RAN_AT_FORMAT),
                 row.fetch("ran_at_label")
  end

  test "GET index with nothing saved renders an empty list" do
    log_in_as(@user)
    get analyses_path, headers: inertia_headers
    assert_response :success
    assert_equal [], JSON.parse(response.body).dig("props", "analyses")
  end

  test "POST create saves a snapshot and redirects to it" do
    log_in_as(@user)

    assert_difference("Analysis.count", 1) do
      post analyses_path, params: VALID_PARAMS
    end

    analysis = @user.analyses.newest_first.first
    assert_redirected_to analysis_path(analysis)
    assert_equal "STL", analysis.ticker
    assert_equal 7, analysis.met_count
    assert_equal "2.00", analysis.inputs["eps_1"]
  end

  test "POST create for a financial company works with blank current assets and liabilities" do
    log_in_as(@user)
    post analyses_path, params: VALID_PARAMS.merge(
      financial_company: "true", current_assets: "", current_liabilities: ""
    )

    analysis = @user.analyses.newest_first.first
    assert_redirected_to analysis_path(analysis)
    assert analysis.financial_company
    assert_equal "financial_company", analysis.result["rules"][1]["reason"]
  end

  test "POST create with a missing price redirects back to the form and saves nothing" do
    log_in_as(@user)
    assert_no_difference("Analysis.count") do
      post analyses_path, params: VALID_PARAMS.merge(price: "")
    end
    assert_redirected_to new_analysis_path
  end

  test "POST create with a non-numeric EPS redirects back to the form and saves nothing" do
    log_in_as(@user)
    assert_no_difference("Analysis.count") do
      post analyses_path, params: VALID_PARAMS.merge(eps_3: "lots")
    end
    assert_redirected_to new_analysis_path
  end

  test "GET show renders the saved snapshot: raw inputs, seven rules, and the record" do
    log_in_as(@user)
    post analyses_path, params: VALID_PARAMS, headers: inertia_headers
    assert_response :redirect # a POST redirect stays 302; the Inertia client follows it with GET

    analysis = @user.analyses.newest_first.first
    get analysis_path(analysis), headers: inertia_headers
    assert_response :success

    page = JSON.parse(response.body)
    assert_equal "analyses/Results", page.fetch("component")

    props = page.fetch("props")
    # The results page's inputs recap shows these strings exactly as typed.
    assert_equal "STL", props.dig("inputs", "ticker")
    assert_equal "2.00", props.dig("inputs", "eps_1")
    assert_equal "1.20", props.dig("inputs", "eps_10")
    assert_equal "20", props.dig("inputs", "bvps")
    assert_equal 7, props.dig("analysis", "rules").size
    assert_equal 7, props.dig("analysis", "met_count")
    assert_equal analysis.id, props.dig("record", "id")
    assert_equal analysis_path(analysis), props.dig("record", "url")
  end

  test "GET show is frozen: a later threshold change does not alter a saved analysis" do
    analysis = snapshot(@user)
    Setting.instance.update!(revenue_threshold_millions: 1000)

    log_in_as(@user)
    get analysis_path(analysis), headers: inertia_headers
    assert_response :success

    props = JSON.parse(response.body).fetch("props")
    assert_equal 700.0, props.dig("analysis", "revenue_threshold")
    assert_equal "pass", props.dig("analysis", "rules", 0, "verdict")
    assert_equal 7, props.dig("analysis", "met_count")
  end

  test "GET show of another user's analysis is not found" do
    other = snapshot(users(:two))

    log_in_as(@user)
    get analysis_path(other)
    assert_response :not_found
  end

  test "DELETE destroys the analysis and returns to history with a notice" do
    analysis = snapshot(@user)
    log_in_as(@user)

    assert_difference("Analysis.count", -1) do
      delete analysis_path(analysis)
    end
    assert_redirected_to analyses_path
    assert_equal "Analysis deleted.", flash[:notice]
  end

  test "DELETE via Inertia answers 303 so the client follows with a GET" do
    analysis = snapshot(@user)
    log_in_as(@user)

    delete analysis_path(analysis), headers: inertia_headers
    assert_response :see_other
    assert_redirected_to analyses_path
  end

  test "DELETE of another user's analysis is not found and deletes nothing" do
    other = snapshot(users(:two))
    log_in_as(@user)

    assert_no_difference("Analysis.count") do
      delete analysis_path(other)
    end
    assert_response :not_found
  end

  private
    def log_in_as(user)
      post login_path, params: { email: user.email, password: @password }
    end

    def inertia_headers
      { "X-Inertia" => "true", "X-Inertia-Version" => ViteRuby.digest }
    end

    def snapshot(user, overrides = {})
      params = VALID_PARAMS.merge(overrides)
      input = Graham::AnalysisInput.new(params)
      checklist = Graham::Checklist.from_input(input, revenue_threshold: Setting.instance.revenue_threshold_millions)
      Analysis.snapshot!(user: user, input: input, checklist: checklist, raw_params: params)
    end
end
