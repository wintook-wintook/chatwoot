# Plan-Organizaciones — una sola vez: lo que se creó antes de ligar al contacto (sin
# organización) pasa a la organización que hoy tiene su contacto. De aquí en adelante lo
# hace Contact#adopt_unlinked_records al ligarlo por primera vez.
class BackfillOrganizationOnClientRecords < ActiveRecord::Migration[7.0]
  TABLES = %w[case_tickets quotes contracts customer_assets maintenance_plans].freeze

  def up
    TABLES.each do |table|
      execute <<~SQL.squish
        UPDATE #{table} SET organization_id = contacts.organization_id
        FROM contacts
        WHERE #{table}.contact_id = contacts.id
          AND #{table}.organization_id IS NULL
          AND contacts.organization_id IS NOT NULL
      SQL
    end
  end

  def down; end
end
