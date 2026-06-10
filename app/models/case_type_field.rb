# frozen_string_literal: true

# == Schema Information
#
# Table name: case_type_fields
#
#  id           :bigint           not null, primary key
#  field_type   :integer          default("text"), not null
#  key          :string           not null
#  label        :string           not null
#  options      :jsonb            not null
#  position     :integer          default(0), not null
#  required     :boolean          default(FALSE), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  case_type_id :bigint           not null
#
# Indexes
#
#  index_case_type_fields_on_account_id      (account_id)
#  index_case_type_fields_on_case_type_id    (case_type_id)
#  index_case_type_fields_on_scope_position  (account_id,case_type_id,position)
#  index_case_type_fields_unique_key         (case_type_id,key) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (case_type_id => case_types.id)
#

# @tickets_cases 2K
# Definición de un campo personalizado para un tipo de caso. Los valores capturados
# se persisten en `case_tickets.custom_attributes` bajo la clave `key` (patrón
# CustomAttributeDefinition, pero acotado por tipo de caso).
class CaseTypeField < ApplicationRecord
  belongs_to :account
  belongs_to :case_type

  # text/number/date → input simple · list → select con `options` · checkbox → booleano
  enum field_type: { text: 0, number: 1, date: 2, list: 3, checkbox: 4 }, _prefix: :field

  validates :label, presence: true, length: { maximum: 100 }
  validates :key,
            presence: true,
            format: { with: /\A[a-z][a-z0-9_]*\z/, message: 'solo minúsculas, números y guion bajo' },
            uniqueness: { scope: :case_type_id, message: 'ya existe para este tipo de caso' },
            length: { maximum: 60 }
  validate  :options_present_for_list

  scope :ordered, -> { order(:position, :id) }

  before_validation :normalize_options

  private

  # `options` siempre array de strings no vacíos.
  def normalize_options
    self.options = Array(options).map { |o| o.to_s.strip }.reject(&:blank?)
  end

  def options_present_for_list
    return unless field_list? && options.blank?

    errors.add(:options, 'requiere al menos una opción para el tipo lista')
  end
end
