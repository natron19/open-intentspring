class CreateIntentions < ActiveRecord::Migration[8.1]
  def change
    create_table :intentions, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string  :sentence,       null: false
      t.integer :length_minutes, null: false, default: 3
      t.string  :tone,           null: false, default: "plain"

      t.timestamps null: false
    end
  end
end
