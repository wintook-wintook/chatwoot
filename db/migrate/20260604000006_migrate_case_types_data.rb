# frozen_string_literal: true

# @tickets_cases
# Crea los tipos de caso por defecto para cada cuenta que ya usa el módulo,
# reasigna los case_tickets y case_rules existentes, y elimina la columna enum vieja.
class MigrateCaseTypesData < ActiveRecord::Migration[7.0]
  # slug viejo → { name, color, enum_val }
  DEFAULT_TYPES = [
    { slug: 'support',            name: 'Soporte',               color: '#3b82f6', enum_val: 0 },
    { slug: 'commercial',         name: 'Comercial',             color: '#8b5cf6', enum_val: 1 },
    { slug: 'implementation',     name: 'Implementación',        color: '#06b6d4', enum_val: 2 },
    { slug: 'internal_tracking',  name: 'Seguimiento interno',   color: '#f59e0b', enum_val: 3 },
    { slug: 'system_incident',    name: 'Incidente del sistema', color: '#ef4444', enum_val: 4 },
  ].freeze

  def up
    conn = ActiveRecord::Base.connection

    # Cuentas que ya usan el módulo (tienen tickets o reglas)
    account_ids = conn.select_values(<<~SQL).map(&:to_i).uniq
      SELECT account_id FROM case_tickets
      UNION
      SELECT account_id FROM case_rules
    SQL

    account_ids.each do |account_id|
      # slug → new case_type id  /  enum_val → new case_type id
      slug_to_id = {}
      enum_to_id = {}

      DEFAULT_TYPES.each_with_index do |t, position|
        id = conn.select_value(
          conn.unprepared_statement do
            sanitized = conn.quote(t[:name])
            color     = conn.quote(t[:color])
            "INSERT INTO case_types (account_id, name, color, position, created_at, updated_at) " \
              "VALUES (#{account_id}, #{sanitized}, #{color}, #{position}, NOW(), NOW()) RETURNING id"
          end
        )
        slug_to_id[t[:slug]]     = id.to_i
        enum_to_id[t[:enum_val]] = id.to_i
      end

      # Reasignar tickets por el valor del enum viejo
      enum_to_id.each do |enum_val, type_id|
        conn.execute(
          "UPDATE case_tickets SET case_type_id = #{type_id} " \
          "WHERE account_id = #{account_id} AND case_type = #{enum_val}"
        )
      end

      # Reasignar reglas: en conditions, donde field='case_type', value pasa de slug a id
      migrate_rules(conn, account_id, slug_to_id)
    end

    # Eliminar la columna enum vieja (ya migrada)
    remove_column :case_tickets, :case_type
  end

  def down
    add_column :case_tickets, :case_type, :integer, null: false, default: 0
    drop_table_rows = ActiveRecord::Base.connection
    drop_table_rows.execute('DELETE FROM case_types')
    remove_column :case_tickets, :case_type_id if column_exists?(:case_tickets, :case_type_id)
  end

  private

  def migrate_rules(conn, account_id, slug_to_id)
    rows = conn.select_all(
      "SELECT id, conditions FROM case_rules WHERE account_id = #{account_id}"
    )
    rows.each do |row|
      conditions = row['conditions']
      conditions = JSON.parse(conditions) if conditions.is_a?(String)
      next unless conditions.is_a?(Array)

      changed = false
      conditions.each do |cond|
        next unless cond['field'] == 'case_type'

        new_id = slug_to_id[cond['value'].to_s]
        next unless new_id

        cond['value'] = new_id.to_s
        changed = true
      end

      next unless changed

      conn.execute(
        "UPDATE case_rules SET conditions = #{conn.quote(conditions.to_json)}::jsonb " \
        "WHERE id = #{row['id']}"
      )
    end
  end
end
