class CreateSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :settings do |t|
      t.decimal :revenue_threshold_millions, precision: 12, scale: 2, null: false, default: 700

      t.timestamps
    end
  end
end
