require "test_helper"

module Graham
  class AnalysisInputTest < ActiveSupport::TestCase
    VALID_PARAMS = {
      ticker: "STL", company_name: "Steady Corp", financial_company: false,
      price: "24", revenue: "900", current_assets: "500", current_liabilities: "200",
      eps_1: "2.00", eps_2: "2.10", eps_3: "1.90", eps_4: "1.80", eps_5: "1.70",
      eps_6: "1.60", eps_7: "1.50", eps_8: "1.30", eps_9: "1.25", eps_10: "1.20",
      dividend_years: "25", bvps: "20"
    }.freeze

    test "a full valid param set parses into typed values" do
      input = AnalysisInput.new(VALID_PARAMS)

      assert input.valid?
      assert_equal "STL", input.ticker
      assert_equal "Steady Corp", input.company_name
      assert_not input.financial_company?
      assert_equal BigDecimal("24"), input.price
      assert_equal 10, input.eps.size
      assert_equal BigDecimal("2.10"), input.eps[1]
      assert_equal 25, input.dividend_years
    end

    test "ticker is stripped and upcased" do
      input = AnalysisInput.new(VALID_PARAMS.merge(ticker: "  stl "))
      assert_equal "STL", input.ticker
    end

    test "missing ticker and overlong ticker are rejected" do
      assert_equal "is required", AnalysisInput.new(VALID_PARAMS.merge(ticker: " ")).errors[:ticker]
      assert_includes AnalysisInput.new(VALID_PARAMS.merge(ticker: "ABCDEFGHIJK")).errors[:ticker], "too long"
    end

    test "company name is optional" do
      input = AnalysisInput.new(VALID_PARAMS.merge(company_name: ""))
      assert input.valid?
      assert_nil input.company_name
    end

    test "price must be a positive number" do
      assert_equal "must be a number", AnalysisInput.new(VALID_PARAMS.merge(price: "abc")).errors[:price]
      assert_equal "must be greater than 0", AnalysisInput.new(VALID_PARAMS.merge(price: "0")).errors[:price]
      assert_equal "must be greater than 0", AnalysisInput.new(VALID_PARAMS.merge(price: "-1")).errors[:price]
    end

    test "revenue accepts zero but rejects negatives" do
      assert AnalysisInput.new(VALID_PARAMS.merge(revenue: "0")).valid?
      assert_equal "must be 0 or greater", AnalysisInput.new(VALID_PARAMS.merge(revenue: "-5")).errors[:revenue]
    end

    test "current assets and liabilities are required only for non-financial companies" do
      missing = AnalysisInput.new(VALID_PARAMS.merge(current_assets: "", current_liabilities: ""))
      assert_equal "is required", missing.errors[:current_assets]
      assert_equal "is required", missing.errors[:current_liabilities]

      financial = AnalysisInput.new(
        VALID_PARAMS.merge(financial_company: "true", current_assets: "", current_liabilities: "")
      )
      assert financial.valid?
      assert financial.financial_company?
      assert_nil financial.current_assets
    end

    test "current liabilities must be strictly positive" do
      input = AnalysisInput.new(VALID_PARAMS.merge(current_liabilities: "0"))
      assert_equal "must be greater than 0", input.errors[:current_liabilities]
    end

    test "a missing EPS year is flagged on exactly that field" do
      input = AnalysisInput.new(VALID_PARAMS.merge(eps_5: ""))
      assert_equal({ eps_5: "is required" }, input.errors)
    end

    test "EPS accepts negative values" do
      assert AnalysisInput.new(VALID_PARAMS.merge(eps_2: "-0.40")).valid?
    end

    test "dividend years must be a whole number between 0 and 99" do
      %w[3.5 -1 100].each do |bad|
        input = AnalysisInput.new(VALID_PARAMS.merge(dividend_years: bad))
        assert_includes input.errors[:dividend_years], "whole number", "expected #{bad.inspect} to be rejected"
      end
      assert AnalysisInput.new(VALID_PARAMS.merge(dividend_years: "0")).valid?
      assert AnalysisInput.new(VALID_PARAMS.merge(dividend_years: "99")).valid?
    end

    test "bvps accepts negative values" do
      input = AnalysisInput.new(VALID_PARAMS.merge(bvps: "-3.20"))
      assert input.valid?
      assert_equal BigDecimal("-3.20"), input.bvps
    end

    test "commas and dollar signs are stripped from numbers" do
      input = AnalysisInput.new(VALID_PARAMS.merge(revenue: "$1,234.56"))
      assert input.valid?
      assert_equal BigDecimal("1234.56"), input.revenue
    end
  end
end
