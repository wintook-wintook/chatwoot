# frozen_string_literal: true

# == Schema Information
#
# Table name: tracking_test_cases
#
#  id                   :bigint           not null, primary key
#  check_text           :text
#  expected_route       :string
#  kind                 :string           default("propia"), not null
#  last_dry             :jsonb            not null
#  last_live            :jsonb            not null
#  message              :text             not null
#  pinned               :boolean          default(FALSE), not null
#  position             :integer          default(0), not null
#  previous_dry         :jsonb            not null
#  previous_live        :jsonb            not null
#  rule                 :text
#  source_key           :string
#  turns                :jsonb            not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  tracking_template_id :bigint           not null
#
# Indexes
#
#  index_tracking_test_cases_on_account_id               (account_id)
#  index_tracking_test_cases_on_template_and_source_key  (tracking_template_id,source_key) UNIQUE WHERE (source_key IS NOT NULL)
#  index_tracking_test_cases_on_tracking_template_id     (tracking_template_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (tracking_template_id => tracking_templates.id)
#
# ================================================================================
# proyecto@diagrama_agente_ia — F3: UNA PRUEBA DE LA PILA DE UN AGENTE
# ================================================================================
# Plan: docs/diagrama_agente_ia_plan.md §6 y §9.1. Antes la pila vivía en la caché dos
# días y se perdía; ahora cada agente tiene la suya, se vuelve a correr al publicar
# (en seco, siempre: D5) y guarda su último resultado y el anterior para comparar.
#
#   last_dry / previous_dry    { at, path, informe }  — DryRunService, contra el texto
#   last_live / previous_live  { at, reply, cumple, motivo, fallas, ruta_ok, traza,
#                                conversation, tokens }  — TestBatteryJob
#
# `turns` (F5): una prueba puede ser un DIÁLOGO de 2–4 mensajes del cliente; `message`
# es el primero. Vacío = un solo mensaje. Sirve para lo que depende de lo ya hablado:
# agenda, variables, el dato que pide @crear_ticket.
#
# `path` es la FIRMA del camino en seco (ruta · fuente · si trajo fragmentos · si abre
# caso · etiqueta): dos corridas con la misma firma tomaron el mismo camino. Es lo que
# decide, al publicar, qué pruebas «cambiaron» y vale la pena correr en vivo.
# ================================================================================

class TrackingTestCase < ApplicationRecord
  KINDS = %w[ruta regla propia].freeze
  MAX_PER_TEMPLATE = 40
  MAX_TURNS = 4

  belongs_to :account
  belongs_to :tracking_template

  validates :message, presence: true, length: { maximum: 500 }
  validates :kind, inclusion: { in: KINDS }
  validate :within_limit, on: :create
  validate :turns_shape

  scope :ordered, -> { order(:position, :id) }

  # Los mensajes del cliente, en orden: el diálogo, o el único mensaje.
  def customer_turns
    turns.presence || [message]
  end

  def dialog?
    customer_turns.size > 1
  end

  # ¿El último camino en seco es distinto del anterior? nil si no hay con qué comparar.
  def dry_changed?
    antes = previous_dry['path']
    ahora = last_dry['path']
    return nil if antes.blank? || ahora.blank?

    antes != ahora
  end

  def live_failed?
    last_live.present? && last_live['cumple'] == false
  end

  # Se guarda el nuevo resultado y el que había pasa a ser el «antes».
  def store_dry!(resultado)
    update!(previous_dry: last_dry, last_dry: resultado.merge('at' => Time.current.iso8601))
  end

  def store_live!(resultado)
    update!(previous_live: last_live, last_live: resultado.merge('at' => Time.current.iso8601))
  end

  private

  def turns_shape
    return if turns.blank?
    return errors.add(:turns, :invalid) unless turns.is_a?(Array) && turns.all? { |t| t.is_a?(String) && t.present? }

    errors.add(:turns, :too_long, count: MAX_TURNS) if turns.size > MAX_TURNS
  end

  def within_limit
    return if tracking_template.nil?
    return if TrackingTestCase.where(tracking_template_id: tracking_template_id).count < MAX_PER_TEMPLATE

    errors.add(:base, "La pila de un agente llega hasta #{MAX_PER_TEMPLATE} pruebas.")
  end
end
