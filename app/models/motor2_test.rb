# frozen_string_literal: true

# Motor 2.0 — una plática guardada como prueba (a mano o al corregir un 👎). Se vuelve a correr
# antes de que el entrenador aplique un cambio y con «Correr todas».
class Motor2Test < ApplicationRecord
  ORIGINS = %w[manual correction].freeze

  belongs_to :account
  belongs_to :tracking_template

  validates :name, presence: true, length: { maximum: 120 }
  validates :origin, inclusion: { in: ORIGINS }
end
