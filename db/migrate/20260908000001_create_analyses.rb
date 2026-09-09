class CreateAnalyses < ActiveRecord::Migration[8.0]
  def change
    create_table :analyses do |t|
      # The composite index below covers lookups by user, so skip the default one.
      t.references :user, null: false, foreign_key: true, index: false
      t.string :ticker, null: false
      t.string :company_name
      t.boolean :financial_company, null: false, default: false
      # Frozen snapshot: the raw form values exactly as typed, and the computed
      # results in the shape the Results page renders. Never recomputed on read.
      t.jsonb :inputs, null: false, default: {}
      t.jsonb :result, null: false, default: {}

      t.timestamps
    end
    add_index :analyses, [ :user_id, :created_at ]
  end
end
