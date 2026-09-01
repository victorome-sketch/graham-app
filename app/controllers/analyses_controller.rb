class AnalysesController < ApplicationController
  PERMITTED_FIELDS = [
    :ticker, :company_name, :financial_company,
    :price, :revenue, :current_assets, :current_liabilities,
    *Graham::AnalysisInput::EPS_KEYS,
    :dividend_years, :bvps
  ].freeze

  def new
    render inertia: "analyses/New", props: {
      prefill: analysis_params.to_h,
      revenue_threshold: Setting.instance.revenue_threshold_millions.to_f
    }
  end

  def create
    input = Graham::AnalysisInput.new(analysis_params.to_h)

    if input.valid?
      checklist = Graham::Checklist.from_input(input, revenue_threshold: Setting.instance.revenue_threshold_millions)
      # Nothing is persisted yet: the results page is rendered directly from
      # the computed checklist (the Inertia-sanctioned render-on-POST path).
      render inertia: "analyses/Results", props: {
        analysis: {
          ticker: input.ticker,
          company_name: input.company_name,
          financial_company: input.financial_company?,
          price: input.price.round(2).to_f,
          **checklist.to_props
        },
        inputs: analysis_params.to_h
      }
    else
      redirect_to new_analysis_path, inertia: { errors: input.errors }
    end
  end

  private

    def analysis_params
      params.permit(*PERMITTED_FIELDS)
    end
end
