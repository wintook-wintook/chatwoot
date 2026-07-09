# frozen_string_literal: true

# proyecto@contact_tracking
# Permite 1 seguimiento activo por (contacto, inbox) en vez de 1 por contacto.
# Cambio seguro sin migrar datos: el índice nuevo es más laxo que el anterior
# (incluye inbox_id), así que ningún registro existente puede violarlo.
class ChangeUniqueActiveTrackingIndexToPerInbox < ActiveRecord::Migration[7.0]
  ACTIVE_STATUSES_SQL = "status IN ('pending', 'scheduled', 'active', 'paused')"

  def up
    remove_index :contact_trackings, name: :index_unique_active_tracking_per_contact, if_exists: true
    add_index :contact_trackings, %i[contact_id inbox_id status],
              unique: true,
              where: ACTIVE_STATUSES_SQL,
              name: :index_unique_active_tracking_per_contact_inbox
  end

  def down
    remove_index :contact_trackings, name: :index_unique_active_tracking_per_contact_inbox, if_exists: true
    add_index :contact_trackings, %i[contact_id status],
              unique: true,
              where: ACTIVE_STATUSES_SQL,
              name: :index_unique_active_tracking_per_contact
  end
end
