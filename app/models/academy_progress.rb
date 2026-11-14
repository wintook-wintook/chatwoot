# frozen_string_literal: true

# == Schema Information
#
# Table name: academy_progresses
#
#  id            :bigint           not null, primary key
#  attempts      :integer          default(0), not null
#  completed_at  :datetime
#  evidence_type :string
#  module_key    :string           not null
#  started_at    :datetime
#  step_key      :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#  evidence_id   :bigint
#  user_id       :bigint           not null
#
# Indexes
#
#  index_academy_progress_unique  (account_id,user_id,module_key,step_key) UNIQUE
#

# Academia Kontrolya — cómo va un usuario en un paso (lección o ejercicio) de un módulo.
# Los módulos viven en config/academy/modules.yml (Academy::Catalog); aquí solo el avance.
class AcademyProgress < ApplicationRecord
  belongs_to :account
  belongs_to :user

  validates :module_key, :step_key, presence: true

  scope :done, -> { where.not(completed_at: nil) }

  def done? = completed_at.present?
end
