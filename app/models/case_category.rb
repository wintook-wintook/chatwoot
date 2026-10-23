# frozen_string_literal: true

# == Schema Information
#
# Table name: case_categories
#
#  id           :bigint           not null, primary key
#  active       :boolean          default(TRUE), not null
#  name         :string           not null
#  position     :integer          default(0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  case_type_id :bigint
#  parent_id    :bigint
#
# Indexes
#
#  index_case_categories_on_account_id_and_position  (account_id,position)
#  index_case_categories_on_case_type_id             (case_type_id)
#  index_case_categories_on_parent_id                (parent_id)
#
# Foreign Keys
#
#  fk_rails_...  (case_type_id => case_types.id)
#

# @tickets_cases 2B — Categoría / subcategoría (self-ref) configurable por cuenta.
class CaseCategory < ApplicationRecord
  belongs_to :account
  belongs_to :parent, class_name: 'CaseCategory', optional: true
  # @tickets_cases — Plan-Clase-Comercial F2: NULL = global (todos los tipos).
  # Lo decide la categoría raíz; las subcategorías lo heredan siempre.
  belongs_to :case_type, optional: true
  has_many   :subcategories, class_name: 'CaseCategory', foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  has_many   :case_tickets, foreign_key: :category_id, dependent: :nullify, inverse_of: :category

  validates :name, presence: true, length: { maximum: 100 }

  scope :ordered, -> { order(:position, :id) }
  scope :roots,   -> { where(parent_id: nil) }
  scope :enabled, -> { where(active: true) }
  # Lo que se ofrece para un tipo: las globales + las propias de ese tipo.
  scope :for_type, ->(case_type_id) { where(case_type_id: [nil, case_type_id].uniq) }

  before_validation :inherit_case_type_from_parent
  validate :case_type_in_account
  after_update :propagate_case_type_to_subcategories, if: :saved_change_to_case_type_id?

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

  # ¿Se puede usar en un caso de este tipo? (global o del mismo tipo)
  def applies_to_type?(type_id)
    case_type_id.nil? || case_type_id == type_id
  end

  private

  def inherit_case_type_from_parent
    self.case_type_id = parent.case_type_id if parent
  end

  def propagate_case_type_to_subcategories
    subcategories.update_all(case_type_id: case_type_id) # rubocop:disable Rails/SkipsModelValidations
  end

  def case_type_in_account
    return if case_type_id.nil? || account&.case_types&.exists?(id: case_type_id)

    errors.add(:case_type_id, 'no pertenece a la cuenta')
  end
end
