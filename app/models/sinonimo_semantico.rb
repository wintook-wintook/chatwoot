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
class SinonimoSemantico < ApplicationRecord
  self.table_name = 'wintook.sinonimo_semantico'
  self.record_timestamps = false

  has_many :palabras_sinonimos, dependent: :nullify, inverse_of: :sinonimo_semantico

  validates :nombre, presence: true
end
