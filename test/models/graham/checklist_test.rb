require "test_helper"

module Graham
  class ChecklistTest < ActiveSupport::TestCase
    # Worked example A from the build plan: every rule passes with exact,
    # hand-verified numbers (ratio 2.50, growth 60%, P/E 12, P/B 1.20, GN 30).
    EXAMPLE_A_EPS = %w[2.00 2.10 1.90 1.80 1.70 1.60 1.50 1.30 1.25 1.20].freeze

    test "worked example A passes all 7 rules with the expected numbers" do
      checklist = build

      assert_equal %i[pass pass pass pass pass pass pass], checklist.rules.map(&:verdict)
      assert_equal 7, checklist.pass_count
      assert_equal 0, checklist.na_count
      assert_equal 7, checklist.met_count

      props = checklist.to_props
      assert_equal 2.5, values_for(props, "financial_condition")[:current_ratio]
      assert_equal 60.0, values_for(props, "earnings_growth")[:growth_pct]
      assert_equal 2.0, values_for(props, "earnings_growth")[:recent_avg]
      assert_equal 1.25, values_for(props, "earnings_growth")[:old_avg]
      assert_equal 12.0, values_for(props, "moderate_pe")[:pe]
      assert_equal 30.0, values_for(props, "moderate_pe")[:price_limit]
      assert_equal 1.2, values_for(props, "moderate_pb")[:pb]
      assert_equal 14.4, values_for(props, "moderate_pb")[:pe_times_pb]

      graham_number = props[:graham_number]
      assert graham_number[:computable]
      assert_equal 30.0, graham_number[:value]
      assert_equal 20.0, graham_number[:margin_pct]
    end

    test "worked example B: financial company gets N/A on rule 2 and still reaches 7 of 7 met" do
      checklist = build(financial_company: true, current_assets: nil, current_liabilities: nil)

      rule = rule_for(checklist, :financial_condition)
      assert_equal :na, rule.verdict
      assert_equal "financial_company", rule.reason
      assert_nil rule.values[:current_ratio]

      assert_equal 6, checklist.pass_count
      assert_equal 1, checklist.na_count
      assert_equal 7, checklist.met_count
    end

    test "financial-company flag wins even when current assets and liabilities are provided" do
      checklist = build(financial_company: true, current_assets: d("100"), current_liabilities: d("100"))

      assert_equal :na, rule_for(checklist, :financial_condition).verdict
    end

    test "worked example C: multi-fail company passes only earnings growth" do
      checklist = build(
        price: d("45"), revenue: d("300"),
        current_assets: d("150"), current_liabilities: d("100"),
        eps: %w[1.00 -0.40 0.60 0.55 0.50 0.45 0.40 0.30 0.20 0.10].map { |v| d(v) },
        dividend_years: 5, bvps: d("10")
      )

      assert_equal %i[fail fail fail fail pass fail fail], checklist.rules.map(&:verdict)
      assert_equal 1, checklist.met_count
      assert_equal 9, rule_for(checklist, :earnings_stability).values[:positive_years]

      props = checklist.to_props
      assert_equal 100.0, values_for(props, "earnings_growth")[:growth_pct]
      assert_equal 112.5, values_for(props, "moderate_pe")[:pe]
      assert_equal 506.25, values_for(props, "moderate_pb")[:pe_times_pb]
      assert_equal 15.0, props[:graham_number][:value]
      assert_equal(-200.0, props[:graham_number][:margin_pct])
    end

    test "boundary: current ratio exactly 2 passes, just under fails" do
      assert_equal :pass, rule_for(build(current_assets: d("400")), :financial_condition).verdict
      assert_equal :fail, rule_for(build(current_assets: d("399")), :financial_condition).verdict
    end

    test "boundary: revenue exactly at the threshold passes" do
      assert_equal :pass, rule_for(build(revenue: d("700")), :adequate_size).verdict
      assert_equal :fail, rule_for(build(revenue: d("699.99")), :adequate_size).verdict
    end

    test "boundary: P/E exactly 15 passes, just over fails" do
      assert_equal :pass, rule_for(build(price: d("30")), :moderate_pe).verdict
      assert_equal :fail, rule_for(build(price: d("30.30")), :moderate_pe).verdict
    end

    test "boundary: P/B exactly 1.5 passes via the first branch" do
      assert_equal :pass, rule_for(build(price: d("30")), :moderate_pb).verdict
    end

    test "boundary: P/E times P/B exactly 22.5 passes, above fails" do
      # price 30, 3y avg EPS 4.00 -> P/E 7.5; BVPS 10 -> P/B 3.0 (over 1.5); product 22.5
      at_limit = build(price: d("30"), eps: eps_with(recent: %w[4.00 4.00 4.00]), bvps: d("10"))
      assert_equal :pass, rule_for(at_limit, :moderate_pb).verdict

      over_limit = build(price: d("30"), eps: eps_with(recent: %w[4.00 4.00 4.00]), bvps: d("8"))
      assert_equal :fail, rule_for(over_limit, :moderate_pb).verdict
    end

    test "boundary: growth of exactly 33 percent passes, 32 percent fails" do
      passing = build(eps: eps_with(recent: %w[1.33 1.33 1.33], old: %w[1.00 1.00 1.00]))
      assert_equal :pass, rule_for(passing, :earnings_growth).verdict
      assert_equal 33.0, passing.to_props[:rules][4][:values][:growth_pct]

      failing = build(eps: eps_with(recent: %w[1.32 1.32 1.32], old: %w[1.00 1.00 1.00]))
      assert_equal :fail, rule_for(failing, :earnings_growth).verdict
    end

    test "growth from a non-positive base average is N/A with a reason" do
      zero_base = build(eps: eps_with(old: %w[0.10 0.00 -0.10]))
      rule = rule_for(zero_base, :earnings_growth)
      assert_equal :na, rule.verdict
      assert_equal "base_avg_not_positive", rule.reason
      assert_nil rule.values[:growth_pct]

      negative_base = build(eps: eps_with(old: %w[-1.00 -1.00 -1.00]))
      assert_equal :na, rule_for(negative_base, :earnings_growth).verdict
    end

    test "negative recent average with a positive base computes a large negative growth and fails" do
      checklist = build(eps: eps_with(recent: %w[-1.00 -1.00 -1.00], old: %w[1.00 1.00 1.00]))
      rule = rule_for(checklist, :earnings_growth)

      assert_equal :fail, rule.verdict
      assert_equal(-200.0, checklist.to_props[:rules][4][:values][:growth_pct])
    end

    test "non-positive 3-year average EPS fails rule 6 with no P/E" do
      checklist = build(eps: eps_with(recent: %w[-1.00 0.50 0.20]))
      rule = rule_for(checklist, :moderate_pe)

      assert_equal :fail, rule.verdict
      assert_equal "avg_eps_not_positive", rule.reason
      assert_nil rule.values[:pe]
    end

    test "rule 7 with non-positive average EPS: fails when P/B is high, still passes when P/B is low" do
      high_pb = build(eps: eps_with(recent: %w[-1.00 0.50 0.20]), price: d("40"), bvps: d("10"))
      rule = rule_for(high_pb, :moderate_pb)
      assert_equal :fail, rule.verdict
      assert_nil rule.values[:pe_times_pb]

      low_pb = build(eps: eps_with(recent: %w[-1.00 0.50 0.20]), price: d("24"), bvps: d("20"))
      assert_equal :pass, rule_for(low_pb, :moderate_pb).verdict
    end

    test "non-positive book value fails rule 7 and makes the Graham Number not computable" do
      [ d("0"), d("-5") ].each do |bvps|
        checklist = build(bvps: bvps)
        rule = rule_for(checklist, :moderate_pb)

        assert_equal :fail, rule.verdict
        assert_equal "bvps_not_positive", rule.reason
        assert_not checklist.graham_number[:computable]
        assert_nil checklist.to_props[:graham_number][:value]
      end
    end

    test "Graham Number is not computable with negative latest EPS, even when the product would be positive" do
      negative_eps = build(eps: eps_with(recent: %w[-0.50 2.10 1.90]))
      assert_not negative_eps.graham_number[:computable]

      both_negative = build(eps: eps_with(recent: %w[-2.00 2.10 1.90]), bvps: d("-10"))
      assert_not both_negative.graham_number[:computable]
    end

    test "a single zero-EPS year fails earnings stability" do
      checklist = build(eps: eps_with(recent: %w[2.00 0.00 1.90]))
      rule = rule_for(checklist, :earnings_stability)

      assert_equal :fail, rule.verdict
      assert_equal 9, rule.values[:positive_years]
    end

    test "to_props is JSON-safe: rounded floats or integers, string verdicts, rules in order" do
      props = build.to_props

      assert_equal %w[adequate_size financial_condition earnings_stability dividend_record
                      earnings_growth moderate_pe moderate_pb], props[:rules].map { |r| r[:key] }

      props[:rules].each do |rule|
        assert_kind_of String, rule[:verdict]
        rule[:values].each_value do |value|
          assert value.nil? || value.is_a?(Float) || value.is_a?(Integer),
                 "expected JSON-safe numeric, got #{value.class}"
        end
      end
      props[:graham_number].each_value do |value|
        assert [ Float, Integer, TrueClass, FalseClass, NilClass ].any? { |klass| value.is_a?(klass) },
               "expected JSON-safe leaf, got #{value.class}"
      end
    end

    private

      def d(value) = BigDecimal(value.to_s)

      def build(**overrides)
        defaults = {
          financial_company: false,
          price: d("24"),
          revenue: d("900"),
          current_assets: d("500"),
          current_liabilities: d("200"),
          eps: EXAMPLE_A_EPS.map { |v| d(v) },
          dividend_years: 25,
          bvps: d("20"),
          revenue_threshold: d("700")
        }
        Checklist.new(**defaults.merge(overrides))
      end

      def eps_with(recent: nil, old: nil)
        values = EXAMPLE_A_EPS.map { |v| d(v) }
        values[0, 3] = recent.map { |v| d(v) } if recent
        values[7, 3] = old.map { |v| d(v) } if old
        values
      end

      def rule_for(checklist, key)
        checklist.rules.find { |rule| rule.key == key }
      end

      def values_for(props, key)
        props[:rules].find { |rule| rule[:key] == key }[:values]
      end
  end
end
