class AddIsForIaToNotes < ActiveRecord::Migration[7.0]
  def change
    add_column :notes, :is_for_ia, :boolean, default: false, null: false
    add_index :notes, [:contact_id, :is_for_ia],
              name: 'index_notes_on_contact_id_and_is_for_ia'
  end
end
