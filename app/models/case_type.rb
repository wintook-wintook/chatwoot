# frozen_string_literal: true

# == Schema Information
#
# Table name: case_types
#
#  id         :bigint           not null, primary key
#  color      :string           default("#3b82f6"), not null
#  name       :string           not null
#  position   :integer          default(0), not null
#  prefix     :string           default(""), not null
#  public     :boolean          default(FALSE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_case_types_on_account_id_and_position  (account_id,position)
#

class CaseType < ApplicationRecord
  belongs_to :account
  has_many   :case_tickets, dependent: :nullify
  has_many   :case_type_fields, dependent: :destroy # @tickets_cases 2K

  validates :name,  presence: true, length: { maximum: 100 }
  validates :color, presence: true

  scope :ordered, -> { order(:position, :id) }

  before_validation :ensure_prefix, on: :create

  # Tipos por defecto que se crean cuando una cuenta abre el módulo sin tipos.
  DEFAULTS = [
    { name: 'Soporte',               color: '#3b82f6', prefix: 'SOP' },
    { name: 'Comercial',             color: '#8b5cf6', prefix: 'COM' },
    { name: 'Implementación',        color: '#06b6d4', prefix: 'IMP' },
    { name: 'Seguimiento interno',   color: '#f59e0b', prefix: 'SEG' },
    { name: 'Incidente del sistema', color: '#ef4444', prefix: 'INC' }
  ].freeze

  # Crea los tipos por defecto para una cuenta si aún no tiene ninguno.
  # Retorna la colección de tipos de la cuenta.
  def self.ensure_defaults_for(account)
    return account.case_types.ordered if account.case_types.exists?

    DEFAULTS.each_with_index do |t, position|
      account.case_types.create!(name: t[:name], color: t[:color], prefix: t[:prefix], position: position)
    end
    account.case_types.ordered
  end

  private

  # Si no se especifica prefijo, autogenera uno de las 3 primeras letras del nombre.
  def ensure_prefix
    return if prefix.present?

    self.prefix = name.to_s.gsub(/[^a-zA-Z]/, '').upcase[0, 3]
  end
end
