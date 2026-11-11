# frozen_string_literal: true

# proyecto@respuestas_predefinidas R3 (docs/respuestas_predefinidas_plan.md §2): las
# categorías de las respuestas predefinidas. Una por predefinida (D1). Borrar una categoría
# deja sus predefinidas sin categoría (no las borra). Idempotente.
class CreateCannedResponseCategories < ActiveRecord::Migration[7.0]
  def up
    unless table_exists?(:canned_response_categories)
      create_table :canned_response_categories do |t|
        t.references :account, null: false, foreign_key: { on_delete: :cascade }
        t.string :name, null: false
        t.string :description
        t.timestamps
      end
      add_index :canned_response_categories, 'account_id, lower(name)', unique: true,
                                                                        name: 'index_canned_categories_on_account_and_lower_name'
    end
    return if column_exists?(:canned_responses, :category_id)

    add_reference :canned_responses, :category, foreign_key: { to_table: :canned_response_categories, on_delete: :nullify }
  end

  def down
    remove_reference :canned_responses, :category, foreign_key: true if column_exists?(:canned_responses, :category_id)
    drop_table :canned_response_categories, if_exists: true
  end
end
