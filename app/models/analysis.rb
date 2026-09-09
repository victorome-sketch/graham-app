# One saved checklist run, frozen at the moment it was computed. `result` is
# byte-for-byte the `analysis` prop the Results page renders and `inputs` is
# the raw form hash as typed, so reopening an analysis replays exactly what
# the user saw — later changes to Settings or the engine never touch it.
class Analysis < ApplicationRecord
  belongs_to :user

  validates :ticker, :inputs, :result, presence: true # {} is blank, so an empty snapshot is rejected

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  def self.snapshot!(user:, input:, checklist:, raw_params:)
    result = {
      ticker: input.ticker,
      company_name: input.company_name,
      financial_company: input.financial_company?,
      price: input.price.round(2).to_f,
      **checklist.to_props
    }

    user.analyses.create!(
      ticker: input.ticker,
      company_name: input.company_name,
      financial_company: input.financial_company?,
      inputs: raw_params.to_h,
      result: result
    )
  end

  # jsonb comes back with string keys (even right after create!, since the JSON
  # type casts on assignment), so these read the snapshot the way it is stored.
  def met_count = result["met_count"]

  def margin_pct = result.dig("graham_number", "margin_pct")
end
