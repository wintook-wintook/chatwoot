# frozen_string_literal: true

# @tickets_cases 2B — Categorías y subcategorías (self-ref) configurables por cuenta.
class CreateCaseCategories < ActiveRecord::Migration[7.0]
  def change
    create_table :case_categories do |t|
      t.bigint  :account_id, null: false
      t.bigint  :parent_id   # null = categoría raíz; presente = subcategoría
      t.string  :name,       null: false
      t.boolean :active,     null: false, default: true
      t.integer :position,   null: false, default: 0
      t.timestamps
    end

    add_index :case_categories, [:account_id, :position]
    add_index :case_categories, :parent_id
  end
end
