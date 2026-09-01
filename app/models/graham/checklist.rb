module Graham
  # Evaluates Benjamin Graham's seven defensive-investor criteria
  # (The Intelligent Investor, Ch. 14) and the Graham Number for one stock.
  #
  # Verdicts are computed on unrounded BigDecimals; to_props rounds for
  # display only, so a P/E of 15.004 fails even though it displays as 15.00.
  # Rule copy lives in the frontend — this class emits only numbers, verdicts,
  # and machine-readable reason keys.
  class Checklist
    MIN_CURRENT_RATIO = 2
    REQUIRED_DIVIDEND_YEARS = 20
    GROWTH_MIN = BigDecimal("0.33") # the PRD fixes 33%, not Graham's one-third
    MAX_PE = 15
    MAX_PB = BigDecimal("1.5")
    MAX_PE_PB = BigDecimal("22.5")
    GRAHAM_MULTIPLIER = BigDecimal("22.5")

    INTEGER_VALUES = %i[positive_years dividend_years required_years].freeze
    ONE_DECIMAL_VALUES = %i[growth_pct margin_pct].freeze

    RuleResult = Data.define(:key, :verdict, :values, :reason)

    def self.from_input(input, revenue_threshold:)
      new(
        financial_company: input.financial_company?,
        price: input.price,
        revenue: input.revenue,
        current_assets: input.current_assets,
        current_liabilities: input.current_liabilities,
        eps: input.eps,
        dividend_years: input.dividend_years,
        bvps: input.bvps,
        revenue_threshold: revenue_threshold
      )
    end

    def initialize(financial_company:, price:, revenue:, current_assets:, current_liabilities:,
                   eps:, dividend_years:, bvps:, revenue_threshold:)
      @financial_company = financial_company
      @price = price
      @revenue = revenue
      @current_assets = current_assets
      @current_liabilities = current_liabilities
      @eps = eps
      @dividend_years = dividend_years
      @bvps = bvps
      @revenue_threshold = revenue_threshold
    end

    def rules
      @rules ||= [
        adequate_size, financial_condition, earnings_stability, dividend_record,
        earnings_growth, moderate_pe, moderate_pb
      ]
    end

    def pass_count = rules.count { |rule| rule.verdict == :pass }
    def fail_count = rules.count { |rule| rule.verdict == :fail }
    def na_count = rules.count { |rule| rule.verdict == :na }

    # Counting policy: an N/A rule counts as met (it is never failed), so a
    # financial company can reach 7 of 7. Change this method to change policy.
    def met_count = rules.count { |rule| rule.verdict != :fail }

    # Uses the most recent year's EPS. Not computable unless both EPS and book
    # value are positive — the formula presumes positive earnings and equity,
    # so a negative-times-negative product must not sneak through the sqrt.
    def graham_number
      @graham_number ||= begin
        eps_used = @eps.first
        if eps_used.positive? && @bvps.positive?
          value = (GRAHAM_MULTIPLIER * eps_used * @bvps).sqrt(16)
          { computable: true, value: value, margin_pct: (value - @price) / value * 100,
            eps_used: eps_used, bvps_used: @bvps }
        else
          { computable: false, value: nil, margin_pct: nil, eps_used: eps_used, bvps_used: @bvps }
        end
      end
    end

    def to_props
      {
        rules: rules.map do |rule|
          {
            key: rule.key.to_s,
            verdict: rule.verdict.to_s,
            reason: rule.reason,
            values: rule.values.to_h { |key, value| [ key, rounded(key, value) ] }
          }
        end,
        pass_count: pass_count,
        fail_count: fail_count,
        na_count: na_count,
        met_count: met_count,
        graham_number: {
          computable: graham_number[:computable],
          value: rounded(:money, graham_number[:value]),
          margin_pct: rounded(:margin_pct, graham_number[:margin_pct]),
          eps_used: rounded(:money, graham_number[:eps_used]),
          bvps_used: rounded(:money, graham_number[:bvps_used])
        },
        revenue_threshold: rounded(:money, @revenue_threshold)
      }
    end

    private

      def adequate_size
        RuleResult.new(
          key: :adequate_size,
          verdict: @revenue >= @revenue_threshold ? :pass : :fail,
          values: { revenue: @revenue, threshold: @revenue_threshold },
          reason: nil
        )
      end

      def financial_condition
        if @financial_company
          return RuleResult.new(
            key: :financial_condition,
            verdict: :na,
            values: { current_ratio: nil, current_assets: nil, current_liabilities: nil },
            reason: "financial_company"
          )
        end

        ratio = @current_assets / @current_liabilities
        RuleResult.new(
          key: :financial_condition,
          verdict: ratio >= MIN_CURRENT_RATIO ? :pass : :fail,
          values: { current_ratio: ratio, current_assets: @current_assets, current_liabilities: @current_liabilities },
          reason: nil
        )
      end

      def earnings_stability
        positive_years = @eps.count(&:positive?)
        RuleResult.new(
          key: :earnings_stability,
          verdict: positive_years == @eps.size ? :pass : :fail,
          values: { positive_years: positive_years },
          reason: nil
        )
      end

      def dividend_record
        RuleResult.new(
          key: :dividend_record,
          verdict: @dividend_years >= REQUIRED_DIVIDEND_YEARS ? :pass : :fail,
          values: { dividend_years: @dividend_years, required_years: REQUIRED_DIVIDEND_YEARS },
          reason: nil
        )
      end

      # Growth from a non-positive base is undefined, so the verdict is N/A
      # rather than a judgment call. Contained: a non-positive base average
      # implies at least one non-positive EPS year, so rule 3 already fails.
      def earnings_growth
        if old_avg <= 0
          return RuleResult.new(
            key: :earnings_growth,
            verdict: :na,
            values: { recent_avg: recent_avg, old_avg: old_avg, growth_pct: nil },
            reason: "base_avg_not_positive"
          )
        end

        growth = (recent_avg - old_avg) / old_avg
        RuleResult.new(
          key: :earnings_growth,
          verdict: growth >= GROWTH_MIN ? :pass : :fail,
          values: { recent_avg: recent_avg, old_avg: old_avg, growth_pct: growth * 100 },
          reason: nil
        )
      end

      # A non-positive average EPS is a fail, not N/A: no positive price can
      # satisfy "price <= 15 x average EPS" when the bound is <= 0.
      def moderate_pe
        if recent_avg <= 0
          return RuleResult.new(
            key: :moderate_pe,
            verdict: :fail,
            values: { pe: nil, avg_eps: recent_avg, price_limit: nil },
            reason: "avg_eps_not_positive"
          )
        end

        price_limit = MAX_PE * recent_avg
        RuleResult.new(
          key: :moderate_pe,
          verdict: @price <= price_limit ? :pass : :fail,
          values: { pe: @price / recent_avg, avg_eps: recent_avg, price_limit: price_limit },
          reason: nil
        )
      end

      # Gated on bvps > 0 first: a negative book value makes P/B negative,
      # which would absurdly pass a naive "P/B <= 1.5" check.
      def moderate_pb
        if @bvps <= 0
          return RuleResult.new(
            key: :moderate_pb,
            verdict: :fail,
            values: { pb: nil, pe: nil, pe_times_pb: nil },
            reason: "bvps_not_positive"
          )
        end

        pb = @price / @bvps
        pe = recent_avg.positive? ? @price / recent_avg : nil
        product = pe && pe * pb
        verdict = pb <= MAX_PB || (product && product <= MAX_PE_PB) ? :pass : :fail
        RuleResult.new(
          key: :moderate_pb,
          verdict: verdict,
          values: { pb: pb, pe: pe, pe_times_pb: product },
          reason: nil
        )
      end

      def recent_avg
        @recent_avg ||= (@eps[0] + @eps[1] + @eps[2]) / 3
      end

      def old_avg
        @old_avg ||= (@eps[7] + @eps[8] + @eps[9]) / 3
      end

      def rounded(key, value)
        return value.to_i if INTEGER_VALUES.include?(key) && !value.nil?
        return nil if value.nil?

        value.round(ONE_DECIMAL_VALUES.include?(key) ? 1 : 2).to_f
      end
  end
end
