# frozen_string_literal: true

# @tickets_cases (recursos por ID_RECURSO) — un ContactTracking "hijo" representa UN
# recurso concreto del catálogo (ej. una grúa) dentro de una solicitud que pidió varios
# recursos para el mismo trabajo. Cada hijo agenda por su cuenta (booking_calendar_ids
# acotado a su propio calendario) y necesita poder estar "activo" al mismo tiempo que
# sus hermanos y que el tracking original — por eso quedan FUERA de la regla de "un
# seguimiento activo por contacto+canal" (que sigue protegiendo a todos los demás casos
# tal cual, ver ContactTracking#only_one_active_tracking_per_contact_and_inbox).
class AddParentToContactTrackings < ActiveRecord::Migration[7.0]
  ACTIVE_STATUSES_SQL = "status IN ('pending', 'scheduled', 'active', 'paused')"

  def up
    add_reference :contact_trackings, :parent_contact_tracking, foreign_key: { to_table: :contact_trackings, on_delete: :nullify }, index: true

    remove_index :contact_trackings, name: :index_unique_active_tracking_per_contact_inbox, if_exists: true
    add_index :contact_trackings, %i[contact_id inbox_id status],
              unique: true,
              where: "#{ACTIVE_STATUSES_SQL} AND parent_contact_tracking_id IS NULL",
              name: :index_unique_active_tracking_per_contact_inbox
  end

  def down
    remove_index :contact_trackings, name: :index_unique_active_tracking_per_contact_inbox, if_exists: true
    add_index :contact_trackings, %i[contact_id inbox_id status],
              unique: true,
              where: ACTIVE_STATUSES_SQL,
              name: :index_unique_active_tracking_per_contact_inbox

    remove_reference :contact_trackings, :parent_contact_tracking
  end
end
