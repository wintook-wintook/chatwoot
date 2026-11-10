# Plan-Organizaciones O2 — lo que hoy pide «cliente» guarda también su organización (la
# del contacto al crearlo, o la que se elija): si el contacto cambia de empresa, lo hecho
# se queda con la de entonces y los informes por organización no dan vueltas.
class AddOrganizationToClientRecords < ActiveRecord::Migration[7.0]
  TABLES = %i[case_tickets quotes contracts customer_assets maintenance_plans].freeze

  def change
    TABLES.each do |table|
      add_reference table, :organization, foreign_key: { on_delete: :nullify }
    end
  end
end
