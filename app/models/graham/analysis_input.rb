module Graham
  # Parses and validates the raw analysis form params into the typed values
  # Graham::Checklist needs. Error keys match the form's field names exactly
  # so messages surface under the right inputs via Inertia's shared errors prop.
  class AnalysisInput
    EPS_KEYS = (1..10).map { |i| :"eps_#{i}" }.freeze
    TICKER_MAX_LENGTH = 10
    DIVIDEND_YEARS_RANGE = (0..99)

    attr_reader :ticker, :company_name, :price, :revenue,
                :current_assets, :current_liabilities,
                :eps, :dividend_years, :bvps

    def initialize(params)
      @params = params.to_h.symbolize_keys
      @ticker = @params[:ticker].to_s.strip.upcase
      @company_name = @params[:company_name].to_s.strip.presence
      @financial_company = ActiveModel::Type::Boolean.new.cast(@params[:financial_company]) || false
      @price = decimal(@params[:price])
      @revenue = decimal(@params[:revenue])
      unless financial_company?
        @current_assets = decimal(@params[:current_assets])
        @current_liabilities = decimal(@params[:current_liabilities])
      end
      @eps = EPS_KEYS.map { |key| decimal(@params[key]) }
      @dividend_years = integer(@params[:dividend_years])
      @bvps = decimal(@params[:bvps])
    end

    def financial_company? = @financial_company

    def valid? = errors.empty?

    def errors
      @errors ||= validate
    end

    private

      def validate
        errors = {}

        if @ticker.empty?
          errors[:ticker] = "is required"
        elsif @ticker.length > TICKER_MAX_LENGTH
          errors[:ticker] = "is too long (#{TICKER_MAX_LENGTH} characters max)"
        end

        validate_number(errors, :price, @price, :positive)
        validate_number(errors, :revenue, @revenue, :non_negative)

        unless financial_company?
          validate_number(errors, :current_assets, @current_assets, :non_negative)
          validate_number(errors, :current_liabilities, @current_liabilities, :positive)
        end

        EPS_KEYS.each_with_index do |key, index|
          validate_number(errors, key, @eps[index], :any)
        end

        validate_dividend_years(errors)
        validate_number(errors, :bvps, @bvps, :any)

        errors
      end

      def validate_number(errors, field, parsed, requirement)
        if raw(field).empty?
          errors[field] = "is required"
        elsif parsed.nil?
          errors[field] = "must be a number"
        elsif requirement == :positive && parsed <= 0
          errors[field] = "must be greater than 0"
        elsif requirement == :non_negative && parsed.negative?
          errors[field] = "must be 0 or greater"
        end
      end

      def validate_dividend_years(errors)
        if raw(:dividend_years).empty?
          errors[:dividend_years] = "is required"
        elsif @dividend_years.nil? || !DIVIDEND_YEARS_RANGE.cover?(@dividend_years)
          errors[:dividend_years] = "must be a whole number between #{DIVIDEND_YEARS_RANGE.min} and #{DIVIDEND_YEARS_RANGE.max}"
        end
      end

      def raw(field) = @params[field].to_s.strip

      def decimal(value)
        cleaned = value.to_s.strip.delete(",$")
        return nil if cleaned.empty?

        BigDecimal(cleaned)
      rescue ArgumentError
        nil
      end

      def integer(value)
        Integer(value.to_s.strip, 10)
      rescue ArgumentError
        nil
      end
  end
end
