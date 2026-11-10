# Plan-Eventos E1 — eventos (feria, curso, demostración…) y su lista de contactos con el
# estado de cada uno (invitado, confirmó, asistió, no asistió, canceló), para después
# hacerles campañas por evento y estado.
class CreateEvents < ActiveRecord::Migration[7.0]
  def change
    create_events
    create_event_attendees
  end

  private

  def create_events
    create_table :events do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :kind, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.string :location
      t.string :meeting_url
      t.integer :capacity
      t.text :description
      t.references :owner, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :closed_at
      t.timestamps
    end
    add_index :events, [:account_id, :starts_at]
  end

  def create_event_attendees
    create_table :event_attendees do |t|
      t.references :account, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: { on_delete: :cascade }
      t.references :contact, null: false, foreign_key: { on_delete: :cascade }
      t.integer :status, null: false, default: 0
      t.string :source, null: false, default: 'manual'
      t.datetime :invited_at
      t.datetime :confirmed_at
      t.datetime :attended_at
      t.datetime :cancelled_at
      t.references :updated_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end
    add_index :event_attendees, [:event_id, :contact_id], unique: true
    add_index :event_attendees, [:account_id, :status]
  end
end
