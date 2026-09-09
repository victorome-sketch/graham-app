require "test_helper"

class AnalysisTest < ActiveSupport::TestCase
  # Worked example A: every rule passes, Graham Number $30 against a $24 price.
  VALID_PARAMS = {
    ticker: "STL", company_name: "Steady Corp",
    price: "24", revenue: "900", current_assets: "500", current_liabilities: "200",
    eps_1: "2.00", eps_2: "2.10", eps_3: "1.90", eps_4: "1.80", eps_5: "1.70",
    eps_6: "1.60", eps_7: "1.50", eps_8: "1.30", eps_9: "1.25", eps_10: "1.20",
    dividend_years: "25", bvps: "20"
  }.freeze

  setup do
    @user = users(:one)
  end

  test "snapshot! freezes the identity columns, the raw inputs, and the computed result" do
    analysis = snapshot(@user)

    assert_equal @user, analysis.user
    assert_equal "STL", analysis.ticker
    assert_equal "Steady Corp", analysis.company_name
    assert_not analysis.financial_company
    assert_equal 7, analysis.met_count
    assert_equal 20.0, analysis.margin_pct

    # Raw strings exactly as typed: the results page's inputs recap shows these.
    assert_equal "2.00", analysis.inputs["eps_1"]
    assert_equal "20", analysis.inputs["bvps"]

    assert_equal 7, analysis.result["rules"].size
    assert_equal 30.0, analysis.result.dig("graham_number", "value")
    assert_equal 700.0, analysis.result["revenue_threshold"]
  end

  test "result round-trips through jsonb as exactly the props the results page rendered" do
    input, checklist = build_engine(VALID_PARAMS)
    expected = {
      ticker: "STL", company_name: "Steady Corp", financial_company: false, price: 24.0,
      **checklist.to_props
    }

    analysis = Analysis.snapshot!(user: @user, input: input, checklist: checklist, raw_params: VALID_PARAMS)

    assert_equal JSON.parse(expected.to_json), analysis.reload.result
  end

  test "margin_pct is nil when the Graham Number is not computable" do
    analysis = snapshot(@user, eps_1: "-6.00")

    assert_nil analysis.margin_pct
    assert_equal false, analysis.result.dig("graham_number", "computable")
  end

  test "a financial company is flagged and its current-ratio rule is N/A" do
    analysis = snapshot(@user, financial_company: "true", current_assets: "", current_liabilities: "")

    assert analysis.financial_company
    assert_equal "na", analysis.result["rules"][1]["verdict"]
    assert_equal 7, analysis.met_count
  end

  test "newest_first puts the most recent run at the top" do
    older = snapshot(@user)
    older.update_columns(created_at: 2.days.ago)
    newer = snapshot(@user, ticker: "KO")

    assert_equal [ newer, older ], @user.analyses.newest_first.to_a
  end

  test "destroying a user removes their analyses" do
    snapshot(@user)

    assert_difference("Analysis.count", -1) { @user.destroy }
  end

  test "an empty snapshot is invalid" do
    analysis = Analysis.new(user: @user, ticker: "STL", inputs: {}, result: {})

    assert_not analysis.valid?
    assert_includes analysis.errors[:inputs], "can't be blank"
    assert_includes analysis.errors[:result], "can't be blank"
  end

  private
    def build_engine(params)
      input = Graham::AnalysisInput.new(params)
      checklist = Graham::Checklist.from_input(input, revenue_threshold: Setting.instance.revenue_threshold_millions)
      [ input, checklist ]
    end

    def snapshot(user, overrides = {})
      params = VALID_PARAMS.merge(overrides)
      input, checklist = build_engine(params)
      Analysis.snapshot!(user: user, input: input, checklist: checklist, raw_params: params)
    end
end
