# frozen_string_literal: true

# == Schema Information
#
# Table name: wintook.sinonimo_semantico
#
#  id     :bigint           not null, primary key
#  nombre :string           not null
#
# Indexes
#
#  idx_wintook_sinonimo_semantico_nombre  (nombre) UNIQUE
#
# ================================================================================
# Catálogo semántico FIJO de los sinónimos (wintook.sinonimo_semantico).
# 8 categorías precargadas por migración: marca, color, material, medida, modelo,
# uso, compatibilidad, característica. No editable desde la app (solo lectura).
# Sin timestamps.
# ================================================================================
class SinonimoSemantico < ApplicationRecord
  self.table_name = 'wintook.sinonimo_semantico'
  self.record_timestamps = false

  has_many :palabras_sinonimos, foreign_key: :sinonimo_semantico_id, dependent: :nullify, inverse_of: :sinonimo_semantico

  validates :nombre, presence: true
end
