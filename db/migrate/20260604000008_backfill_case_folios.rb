# frozen_string_literal: true

# @tickets_cases — backfill de folios para datos existentes
class BackfillCaseFolios < ActiveRecord::Migration[7.0]
  PREFIX_BY_NAME = {
    'Soporte'               => 'SOP',
    'Comercial'             => 'COM',
    'Implementación'        => 'IMP',
    'Seguimiento interno'   => 'SEG',
    'Incidente del sistema' => 'INC'
  }.freeze

  def up
    conn = ActiveRecord::Base.connection

    # 1. Prefijos para los tipos existentes (por nombre, o 3 letras del nombre)
    conn.select_all('SELECT id, name FROM case_types').each do |row|
      prefix = PREFIX_BY_NAME[row['name']] ||
               row['name'].to_s.gsub(/[^a-zA-Z]/, '').upcase[0, 3]
      conn.execute("UPDATE case_types SET prefix = #{conn.quote(prefix)} WHERE id = #{row['id']}")
    end

    # Cuentas que usan el módulo
    account_ids = conn.select_values(<<~SQL).map(&:to_i).uniq
      SELECT account_id FROM case_tickets
      UNION
      SELECT account_id FROM case_types
    SQL

    account_ids.each do |account_id|
      # 2. Config de folio por defecto: {PREFIX}-{SEQ:5}, por tipo, sin reinicio
      unless conn.select_value("SELECT 1 FROM case_folio_configs WHERE account_id = #{account_id}")
        conn.execute(
          'INSERT INTO case_folio_configs (account_id, enabled, template, per_type, reset_period, created_at, updated_at) ' \
          "VALUES (#{account_id}, true, '{PREFIX}-{SEQ:5}', true, 'never', NOW(), NOW())"
        )
      end

      # 3. Folios retroactivos: por tipo, tickets ordenados por created_at
      backfill_account(conn, account_id)
    end
  end

  def down
    ActiveRecord::Base.connection.execute('UPDATE case_tickets SET folio = NULL')
    ActiveRecord::Base.connection.execute('DELETE FROM case_folio_counters')
  end

  private

  def backfill_account(conn, account_id)
    # Prefijo por tipo
    prefixes = {}
    conn.select_all("SELECT id, prefix FROM case_types WHERE account_id = #{account_id}").each do |r|
      prefixes[r['id'].to_i] = r['prefix']
    end

    # Agrupar tickets sin folio por case_type_id, ordenados por fecha
    rows = conn.select_all(
      "SELECT id, case_type_id FROM case_tickets " \
      "WHERE account_id = #{account_id} AND folio IS NULL " \
      'ORDER BY created_at ASC, id ASC'
    )

    counters = Hash.new(0)
    rows.each do |row|
      type_id = row['case_type_id']&.to_i
      counters[type_id] += 1
      seq    = counters[type_id]
      prefix = prefixes[type_id].to_s
      folio  = "#{prefix}-#{seq.to_s.rjust(5, '0')}"
      conn.execute("UPDATE case_tickets SET folio = #{conn.quote(folio)} WHERE id = #{row['id']}")
    end

    # Persistir el valor final del contador por tipo (counter_key = "type:<id>")
    counters.each do |type_id, value|
      key = "type:#{type_id || 'none'}"
      conn.execute(
        'INSERT INTO case_folio_counters (account_id, counter_key, value, created_at, updated_at) ' \
        "VALUES (#{account_id}, #{conn.quote(key)}, #{value}, NOW(), NOW()) " \
        'ON CONFLICT (account_id, counter_key) DO UPDATE SET value = EXCLUDED.value'
      )
    end
  end
end
