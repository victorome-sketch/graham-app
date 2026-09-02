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
    get new_analysis_path
    assert_redirected_to login_path

    post analyses_path, params: VALID_PARAMS
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

  test "GET /analyses redirects to the form until history exists" do
    log_in_as(@user)
    get "/analyses"
    assert_redirected_to "/analyses/new"
  end

  test "POST create with valid inputs renders the results page" do
    log_in_as(@user)
    # Intentionally a 200 Inertia render, not a redirect: nothing is persisted
    # in milestone 1, so the results are rendered straight from the engine.
    post analyses_path, params: VALID_PARAMS
    assert_response :success
  end

  test "POST create for a financial company works with blank current assets and liabilities" do
    log_in_as(@user)
    post analyses_path, params: VALID_PARAMS.merge(
      financial_company: "true", current_assets: "", current_liabilities: ""
    )
    assert_response :success
  end

  test "POST create with a missing price redirects back to the form" do
    log_in_as(@user)
    post analyses_path, params: VALID_PARAMS.merge(price: "")
    assert_redirected_to new_analysis_path
  end

  test "POST create with a non-numeric EPS redirects back to the form" do
    log_in_as(@user)
    post analyses_path, params: VALID_PARAMS.merge(eps_3: "lots")
    assert_redirected_to new_analysis_path
  end

  test "POST create echoes the raw inputs and seven rules in the Inertia payload" do
    log_in_as(@user)
    post analyses_path, params: VALID_PARAMS,
         headers: { "X-Inertia" => "true", "X-Inertia-Version" => ViteRuby.digest }
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
  end

  private
    def log_in_as(user)
      post login_path, params: { email: user.email, password: @password }
    end
end
