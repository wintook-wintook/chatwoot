# frozen_string_literal: true

# Plantilla de seguimiento: la «receta» de un Seguimiento IA para volver a usarla al delegar
# (desde la ventana o desde Dali). Guarda qué lograr, instrucciones, ritmo, qué hacer al
# terminar y la plantilla de WhatsApp preferida; no la conversación ni la fecha de inicio.
# Son de toda la cuenta; la cambia o borra quien la creó o un administrador.
class AiFollowUpPreset < ApplicationRecord
  UNIT_LABELS = { 'minutes' => 'minuto(s)', 'hours' => 'hora(s)', 'days' => 'día(s)' }.freeze
  FIELDS = %w[objective instructions max_attempts interval_value interval_unit on_finish template_name template_language].freeze

  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true

  before_validation :normalize

  validates :name, presence: true, length: { maximum: 80 }
  validates :name, uniqueness: { scope: :account_id, case_sensitive: false }
  validates :objective, presence: true, length: { maximum: 1000 }
  validates :instructions, length: { maximum: 2000 }
  validates :max_attempts, numericality: { only_integer: true, in: 1..10 }
  validates :interval_value, numericality: { only_integer: true, greater_than: 0 }
  validates :interval_unit, inclusion: { in: AiFollowUp::UNITS }
  validates :on_finish, inclusion: { in: AiFollowUp::ON_FINISH }

  scope :ordered, -> { order(Arel.sql('lower(name)')) }

  # Los campos tal como los recibe AiFollowUps::Creator (y la ventana de delegar).
  def fields
    slice(*FIELDS).compact
  end

  # Una línea para Dali y para la lista: de qué se trata y su ritmo.
  def summary
    "#{objective.to_s.squish.first(120)} · #{max_attempts} intento(s) cada #{interval_value} #{UNIT_LABELS[interval_unit]}"
  end

  def editable_by?(user, grant)
    grant&.admin? || (user && created_by_id == user.id)
  end

  private

  def normalize
    self.name = name.to_s.squish
    self.objective = objective.to_s.strip
    self.instructions = instructions.to_s.strip.presence
    self.template_name = template_name.presence
    self.template_language = template_language.presence
  end
end
