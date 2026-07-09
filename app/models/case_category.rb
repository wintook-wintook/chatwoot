# frozen_string_literal: true

# == Schema Information
#
# Table name: case_categories
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  parent_id  :bigint
#
# Indexes
#
#  index_case_categories_on_account_id_and_position  (account_id,position)
#  index_case_categories_on_parent_id                (parent_id)
#

# @tickets_cases 2B — Categoría / subcategoría (self-ref) configurable por cuenta.
class CaseCategory < ApplicationRecord
  belongs_to :account
  belongs_to :parent, class_name: 'CaseCategory', optional: true
  has_many   :subcategories, class_name: 'CaseCategory', foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  has_many   :case_tickets, foreign_key: :category_id, dependent: :nullify, inverse_of: :category

  validates :name, presence: true, length: { maximum: 100 }

  scope :ordered, -> { order(:position, :id) }
  scope :roots,   -> { where(parent_id: nil) }
  scope :enabled, -> { where(active: true) }

  # Categorías raíz por defecto cuando la cuenta abre el módulo sin categorías.
  DEFAULTS = [
    'Acceso', 'Configuración', 'Error de sistema', 'Integración',
    'Datos / sincronización', 'Rendimiento', 'Capacitación', 'Comercial', 'Soporte técnico'
  ].freeze

  def self.ensure_defaults_for(account)
    return account.case_categories.ordered if account.case_categories.exists?

    DEFAULTS.each_with_index do |name, position|
      account.case_categories.create!(name: name, position: position)
    end
    account.case_categories.ordered
  end
end
