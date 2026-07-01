# frozen_string_literal: true

# == Schema Information
#
# Table name: tracking_campaigns
#
#  id                   :bigint           not null, primary key
#  name                 :string           not null
#  objective            :string
#  scheduled_for        :datetime
#  status               :string           default("running"), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  inbox_id             :bigint
#  tracking_template_id :bigint
#  user_id              :bigint
#
# Indexes
#
#  index_tracking_campaigns_on_account_id             (account_id)
#  index_tracking_campaigns_on_account_id_and_status  (account_id,status)
#  index_tracking_campaigns_on_inbox_id               (inbox_id)
#  index_tracking_campaigns_on_tracking_template_id   (tracking_template_id)
#  index_tracking_campaigns_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#  fk_rails_...  (tracking_template_id => tracking_templates.id)
#  fk_rails_...  (user_id => users.id)
#
# @campanas_vendedor

# ================================================================================
# Modelo: TrackingCampaign
# ================================================================================
# Agrupador con nombre de una asignación masiva de seguimientos (Agente IA).
# Reúne los ContactTracking creados en una misma corrida del bulk assign para
# poder medir, en el dashboard, qué pasó con la campaña (enviados, respondieron,
# agendaron, finalizados). NO es el Campaign nativo de Chatwoot (envíos).
# ================================================================================

class TrackingCampaign < ApplicationRecord
  STATUSES = %w[draft running paused finished].freeze

  belongs_to :account
  belongs_to :tracking_template, optional: true
  belongs_to :inbox, optional: true
  belongs_to :user, optional: true

  has_many :contact_trackings, dependent: :nullify

  validates :name, presence: true, length: { minimum: 2, maximum: 120 }
  validates :status, inclusion: { in: STATUSES }
  # El objective se copia de la plantilla (que permite hasta 500). Sin esta
  # validación explícita, la de ApplicationRecord lo limitaría a 255 y el
  # create! reventaría con RecordInvalid en plantillas de objective largo.
  validates :objective, length: { maximum: 500 }, allow_nil: true

  scope :active, -> { where(status: %w[draft running paused]) }

  # Estadísticas agregadas de los seguimientos de la campaña (alimentan el dashboard).
  def stats
    grouped = contact_trackings.group(:status).count
    {
      total: grouped.values.sum,
      pending: grouped.fetch('pending', 0) + grouped.fetch('scheduled', 0),
      active: grouped.fetch('active', 0) + grouped.fetch('paused', 0),
      completed: grouped.fetch('completed', 0),
      failed: grouped.fetch('failed', 0) + grouped.fetch('cancelled', 0)
    }
  end
end
