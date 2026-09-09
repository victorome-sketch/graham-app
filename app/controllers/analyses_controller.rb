class AnalysesController < ApplicationController
  PERMITTED_FIELDS = [
    :ticker, :company_name, :financial_company,
    :price, :revenue, :current_assets, :current_liabilities,
    *Graham::AnalysisInput::EPS_KEYS,
    :dividend_years, :bvps
  ].freeze

  RAN_AT_FORMAT = "%b %-d, %Y, %-l:%M %p" # "Sep 8, 2026, 3:42 PM"

  def index
    render inertia: "analyses/Index", props: {
      analyses: Current.user.analyses.newest_first.map { |analysis| analysis_summary(analysis) }
    }
  end

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
      analysis = Analysis.snapshot!(user: Current.user, input: input, checklist: checklist, raw_params: analysis_params)
      redirect_to analysis_path(analysis)
    else
      redirect_to new_analysis_path, inertia: { errors: input.errors }
    end
  end

  def show
    analysis = Current.user.analyses.find(params[:id])
    # Frozen snapshot: both props come straight off the row, never recomputed,
    # so a later Settings change cannot alter what this run showed.
    render inertia: "analyses/Results", props: {
      analysis: analysis.result,
      inputs: analysis.inputs,
      record: analysis_summary(analysis)
    }
  end

  def destroy
    Current.user.analyses.find(params[:id]).destroy!
    redirect_to analyses_path, notice: "Analysis deleted."
  end

  private

    def analysis_params
      params.permit(*PERMITTED_FIELDS)
    end

    # One row of the history list; also the `record` prop on a saved result.
    # The date is formatted here, not in the browser: a client-side locale
    # format would differ between the SSR render and hydration.
    def analysis_summary(analysis)
      {
        id: analysis.id,
        url: analysis_path(analysis),
        ticker: analysis.ticker,
        company_name: analysis.company_name,
        met_count: analysis.met_count,
        margin_pct: analysis.margin_pct,
        ran_at: analysis.created_at.iso8601,
        ran_at_label: analysis.created_at.in_time_zone(Current.user.time_zone).strftime(RAN_AT_FORMAT)
      }
    end
end
