# frozen_string_literal: true

# == Schema Information
#
# Table name: case_folio_counters
#
#  id          :bigint           not null, primary key
#  counter_key :string           not null
#  value       :integer          default(0), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_case_folio_counters_on_account_id_and_counter_key  (account_id,counter_key) UNIQUE
#

class CaseFolioCounter < ApplicationRecord
  belongs_to :account

  # Incremento atómico: inserta con value=1 o suma 1 si ya existe. Retorna el nuevo value.
  # Seguro ante concurrencia gracias a ON CONFLICT de Postgres.
  def self.next_value!(account_id, counter_key)
    sql = sanitize_sql_array([
      'INSERT INTO case_folio_counters (account_id, counter_key, value, created_at, updated_at) ' \
      'VALUES (?, ?, 1, NOW(), NOW()) ' \
      'ON CONFLICT (account_id, counter_key) ' \
      'DO UPDATE SET value = case_folio_counters.value + 1, updated_at = NOW() ' \
      'RETURNING value',
      account_id, counter_key
    ])
    connection.select_value(sql).to_i
  end
end
