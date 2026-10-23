# frozen_string_literal: true

# == Schema Information
#
# Table name: case_type_columns
#
#  id           :bigint           not null, primary key
#  advance_mode :integer          default("suggest"), not null
#  color        :string           default("#64748b"), not null
#  label        :string           not null
#  outcome      :integer
#  position     :integer          default(0), not null
#  probability  :integer
#  statuses     :jsonb            not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  case_type_id :bigint           not null
#
# Indexes
#
#  index_case_type_columns_on_account_id         (account_id)
#  index_case_type_columns_on_type_and_position  (case_type_id,position)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (case_type_id => case_types.id) ON DELETE => cascade
#

# @tickets_cases — Columna del Kanban propia de un Tipo de Caso (Opción A+).
# Cada columna cubre uno o más `status` del enum global de CaseTicket. Varias
# columnas del mismo tipo PUEDEN cubrir el mismo estado (ej. tres etapas de un
# flujo comercial, todas `in_progress`): esa es la funcionalidad, no un error, por
# eso NO hay validación de solape. El ticket recuerda en cuál está vía
# `case_tickets.case_type_column_id`; `status` sigue siendo el estado canónico.
class CaseTypeColumn < ApplicationRecord
  belongs_to :account
  belongs_to :case_type
  has_many   :case_tickets, dependent: :nullify
  # Plan-Plantilla-Tareas-Etapa — tareas que nacen al entrar a esta etapa.
  has_many   :task_templates, -> { ordered }, class_name: 'CaseTypeColumnTask', dependent: :destroy,
                                              inverse_of: :case_type_column

  validates :label, presence: true, length: { maximum: 60 }
  validates :color, presence: true
  validate  :statuses_are_valid
  # Plan-Clase-Comercial F3 — columna final del embudo (Ganada/Perdida/Cancelada) y
  # probabilidad que toma la oportunidad al entrar. Valores nuevos SIEMPRE al final.
  enum outcome: { won: 0, lost: 1, cancelled: 2 }, _prefix: :outcome
  validates :probability, numericality: { only_integer: true, in: 0..100 }, allow_nil: true
  validate  :outcome_column_is_closed
  # Plan-Plantilla-Tareas-Etapa — al terminar las tareas obligatorias: sugerir pasar a
  # la siguiente etapa (defecto), pasar sola o no hacer nada. Valores nuevos al final.
  enum advance_mode: { suggest: 0, automatic: 1, manual: 2 }, _prefix: :advance

  scope :ordered, -> { order(:position, :id) }

  before_validation :normalize_statuses

  # @tickets_cases — plantillas de columnas por defecto, espejo del tablero fijo.
  # Al crear un Tipo de Caso se siembran estas (según el modo de la cuenta) como
  # punto de partida editable. Cubren los 13 estados. Etiquetas alineadas con
  # CASE_TICKETS.KANBAN.COLUMNS del front.
  SIMPLE_TEMPLATE = [
    { label: 'Nuevo', color: '#3b82f6', statuses: %w[open] },
    { label: 'En proceso', color: '#f59e0b',
      statuses: %w[classified assigned in_diagnosis in_progress escalated] },
    { label: 'En espera', color: '#f97316',
      statuses: %w[waiting_on_customer waiting_on_third_party waiting_on_internal] },
    { label: 'Resuelto',  color: '#10b981', statuses: %w[resolved validating] },
    { label: 'Cerrado',   color: '#64748b', statuses: %w[closed cancelled] }
  ].freeze

  ITIL_TEMPLATE = [
    { label: 'Nuevo',     color: '#3b82f6', statuses: %w[open classified] },
    { label: 'Asignado / Diagnóstico', color: '#8b5cf6', statuses: %w[assigned in_diagnosis] },
    { label: 'En proceso', color: '#f59e0b', statuses: %w[in_progress escalated] },
    { label: 'En espera', color: '#f97316',
      statuses: %w[waiting_on_customer waiting_on_third_party waiting_on_internal] },
    { label: 'Resuelto',  color: '#10b981', statuses: %w[resolved validating] },
    { label: 'Cerrado',   color: '#64748b', statuses: %w[closed cancelled] }
  ].freeze

  # Plan-Clase-Comercial F3 — embudo por defecto de un tipo Comercial. Cubre los 13
  # estados como exige TypeColumnsReplaceService; resolved/validating nunca se usan
  # en una oportunidad pero quedan en Negociación por si un caso llega de Soporte.
  COMMERCIAL_TEMPLATE = [
    { label: 'Prospecto', color: '#3b82f6', probability: 10, statuses: %w[open classified assigned in_diagnosis] },
    { label: 'Calificado', color: '#6366f1', probability: 25,
      statuses: %w[in_progress escalated waiting_on_third_party waiting_on_internal] },
    { label: 'Propuesta', color: '#8b5cf6', probability: 50, statuses: %w[in_progress] },
    { label: 'Negociación', color: '#f59e0b', probability: 75, statuses: %w[in_progress resolved validating] },
    { label: 'Pospuesta', color: '#f97316', statuses: %w[waiting_on_customer] },
    { label: 'Ganada', color: '#10b981', probability: 100, outcome: 'won', statuses: %w[closed] },
    { label: 'Perdida', color: '#ef4444', probability: 0, outcome: 'lost', statuses: %w[closed] },
    { label: 'Cancelada', color: '#64748b', probability: 0, outcome: 'cancelled', statuses: %w[closed cancelled] }
  ].freeze

  # Plan-Clase-Orden-de-Trabajo F1 — flujo por defecto de una orden de trabajo.
  # Cubre los 13 estados como exige TypeColumnsReplaceService.
  WORK_ORDER_TEMPLATE = [
    { label: 'Por programar', color: '#64748b', statuses: %w[open classified] },
    { label: 'Programada', color: '#3b82f6', statuses: %w[assigned in_diagnosis] },
    { label: 'En ejecución', color: '#0d9488', statuses: %w[in_progress escalated] },
    { label: 'Pausada', color: '#f59e0b',
      statuses: %w[waiting_on_customer waiting_on_third_party waiting_on_internal] },
    { label: 'Terminada', color: '#10b981', statuses: %w[resolved validating] },
    { label: 'Cerrada', color: '#475569', statuses: %w[closed] },
    { label: 'Cancelada', color: '#94a3b8', statuses: %w[cancelled] }
  ].freeze

  # Plan-Clase-Proyecto P1 — fases por defecto de un proyecto (cubre los 13 estados).
  PROJECT_TEMPLATE = [
    { label: 'Planeación', color: '#6366f1', statuses: %w[open classified assigned in_diagnosis] },
    { label: 'Ejecución', color: '#0ea5e9', statuses: %w[in_progress escalated] },
    { label: 'Pausado', color: '#f59e0b', statuses: %w[waiting_on_customer waiting_on_third_party waiting_on_internal] },
    { label: 'Entrega', color: '#10b981', statuses: %w[resolved validating] },
    { label: 'Cerrado', color: '#475569', statuses: %w[closed] },
    { label: 'Cancelado', color: '#94a3b8', statuses: %w[cancelled] }
  ].freeze

  # Siembra las columnas por defecto de un tipo recién creado, espejo del tablero
  # fijo (simple 5 / ITIL 6) según el modo de la cuenta, el embudo si el tipo es
  # Comercial, el flujo de la orden si es Orden de trabajo o las fases si es Proyecto. No pisa columnas ya
  # existentes: solo actúa si el tipo aún no tiene ninguna.
  def self.seed_defaults_for(case_type, itil:)
    return if case_type.case_type_columns.exists?

    template = if case_type.class_commercial?
                 COMMERCIAL_TEMPLATE
               elsif case_type.class_work_order?
                 WORK_ORDER_TEMPLATE
               elsif case_type.class_project?
                 PROJECT_TEMPLATE
               else
                 itil ? ITIL_TEMPLATE : SIMPLE_TEMPLATE
               end
    template.each_with_index do |col, position|
      case_type.case_type_columns.create!(
        account: case_type.account, label: col[:label], color: col[:color],
        position: position, statuses: col[:statuses], outcome: col[:outcome], probability: col[:probability]
      )
    end
  end

  private

  # `statuses` siempre array de strings únicos y no vacíos.
  def normalize_statuses
    self.statuses = Array(statuses).map { |s| s.to_s.strip }.reject(&:blank?).uniq
  end

  # Debe cubrir al menos un estado, y todos han de pertenecer al enum de CaseTicket.
  # (La cobertura TOTAL de los 13 estados se valida a nivel del tipo, en el
  # servicio de guardado — una columna suelta no sabe qué cubren sus hermanas.)
  def statuses_are_valid
    if statuses.blank?
      errors.add(:statuses, 'requiere al menos un estado')
      return
    end

    invalid = statuses - CaseTicket.statuses.keys
    errors.add(:statuses, "estados inválidos: #{invalid.join(', ')}") if invalid.any?
  end

  # Una columna de resultado solo puede contener casos cerrados.
  def outcome_column_is_closed
    return if outcome.nil?
    return if statuses.include?('closed') && (statuses - %w[closed cancelled]).empty?

    errors.add(:outcome, 'una columna de resultado solo cubre casos cerrados')
  end
end
