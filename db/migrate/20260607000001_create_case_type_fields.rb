# @tickets_cases 2K — Campos personalizados por tipo de caso.
class CreateCaseTypeFields < ActiveRecord::Migration[7.0]
  def change
    create_table :case_type_fields do |t|
      t.references :account,   null: false, foreign_key: true
      t.references :case_type, null: false, foreign_key: true
      t.string  :key,        null: false
      t.string  :label,      null: false
      t.integer :field_type, null: false, default: 0
      t.jsonb   :options,    null: false, default: []
      t.boolean :required,   null: false, default: false
      t.integer :position,   null: false, default: 0

      t.timestamps
    end

    add_index :case_type_fields, %i[case_type_id key], unique: true, name: 'index_case_type_fields_unique_key'
    add_index :case_type_fields, %i[account_id case_type_id position], name: 'index_case_type_fields_on_scope_position'
  end
end
