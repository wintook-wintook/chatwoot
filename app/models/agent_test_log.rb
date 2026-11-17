# frozen_string_literal: true

# Probador de agentes — la bitácora de correcciones: cada 👎 con lo que dijo el usuario y dónde
# estuvo el error (prompt, contenido, modelo o motor). Los del motor llevan su reporte a
# Kontrolya (motor2_reports).
class AgentTestLog < ApplicationRecord
  KINDS = %w[prompt content model engine question].freeze

  belongs_to :account
  belongs_to :tracking_template, optional: true
  belongs_to :user, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :engine, inclusion: { in: %w[1 2] }
end
