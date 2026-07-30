# frozen_string_literal: true

# == Schema Information
#
# Table name: wintook.palabras_sinonimos
#
#  palabra               :string
#  account_id            :integer          default(0), not null
#  palabra_id            :bigint           not null, primary key
#  palabra_sinonimo_id   :integer          default(0), not null
#  sinonimo_semantico_id :integer
#
# ================================================================================
# Sinónimos nativos — tabla legacy wintook.palabras_sinonimos (auto-referenciada)
# --------------------------------------------------------------------------------
# Una sola tabla: una fila es RAÍZ o SINÓNIMO según palabra_sinonimo_id.
#   RAÍZ     → palabra_id == palabra_sinonimo_id  (cabeza de su grupo)
#   SINÓNIMO → palabra_sinonimo_id == palabra_id de su raíz (y != al propio)
# La tabla NO tiene timestamps → record_timestamps = false.
# La categoría semántica (opcional) vive solo en las RAÍCES.
# ================================================================================
class PalabraSinonimo < ApplicationRecord
  self.table_name = 'wintook.palabras_sinonimos'
  self.primary_key = 'palabra_id'
  self.record_timestamps = false

  belongs_to :account
  belongs_to :sinonimo_semantico, optional: true

  scope :raices,          -> { where('palabras_sinonimos.palabra_id = palabras_sinonimos.palabra_sinonimo_id') }
  scope :sinonimos,       -> { where('palabras_sinonimos.palabra_id <> palabras_sinonimos.palabra_sinonimo_id') }
  scope :de_raiz,         ->(raiz_id) { sinonimos.where(palabra_sinonimo_id: raiz_id) }
  scope :buscar,          ->(q) { where('palabra ILIKE ?', "%#{q}%") }

  def raiz?
    palabra_id == palabra_sinonimo_id
  end
end
