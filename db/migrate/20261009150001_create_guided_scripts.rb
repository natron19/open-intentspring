class CreateGuidedScripts < ActiveRecord::Migration[8.1]
  def change
    create_table :guided_scripts, id: :uuid do |t|
      t.references :intention, type: :uuid, null: false, foreign_key: true
      t.string   :status, null: false, default: "pending"
      t.text     :gemini_raw
      t.string   :failure_reason
      t.datetime :generated_at

      t.string  :title
      t.integer :length_minutes
      t.integer :word_count
      t.jsonb   :segments,      null: false, default: []
      t.jsonb   :making_prompt, null: false, default: {}

      t.timestamps null: false
    end
    add_index :guided_scripts, :status
  end
end
