# == Schema Information
#
# Table name: ai_agent_attachments
#
#  id                   :bigint           not null, primary key
#  name                 :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  tracking_template_id :bigint           not null
#
# Indexes
#
#  index_ai_agent_attachments_on_account_id            (account_id)
#  index_ai_agent_attachments_on_template_and_name     (tracking_template_id,name) UNIQUE
#  index_ai_agent_attachments_on_tracking_template_id  (tracking_template_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (tracking_template_id => tracking_templates.id)
#

class AiAgentAttachment < ApplicationRecord
  belongs_to :tracking_template
  belongs_to :account

  has_one_attached :file

  # Slug inequívoco para que el token {{name}} termine sin ambigüedad al parsearse.
  NAME_FORMAT = /\A[a-zA-Z0-9_-]+\z/

  validates :name, presence: true,
                   length: { minimum: 1, maximum: 60 },
                   uniqueness: { scope: :tracking_template_id, case_sensitive: false }
  validate :name_format
  validate :file_must_be_attached
  validate :whatsapp_limits, on: :create

  # Lo que WhatsApp acepta (los agentes los mandan por ahí): imagen JPG/PNG hasta 5 MB, video o audio
  # hasta 16 MB, documento hasta 100 MB.
  LIMITS_MB = { 'image' => 5, 'video' => 16, 'audio' => 16 }.freeze
  IMAGE_TYPES = %w[image/jpeg image/png].freeze
  DOCUMENT_MB = 100

  private

  def name_format
    return if name.blank? || name.to_s.match?(NAME_FORMAT)

    errors.add(:name, 'solo admite letras, números, guion y guion bajo (sin espacios)')
  end

  def file_must_be_attached
    errors.add(:file, 'debe adjuntarse un archivo') unless file.attached?
  end

  def whatsapp_limits
    return unless file.attached?

    type = file.content_type.to_s
    errors.add(:file, 'la imagen debe ser JPG o PNG (WhatsApp no manda otras)') if type.start_with?('image/') && IMAGE_TYPES.exclude?(type)
    limit = LIMITS_MB[type.split('/').first] || DOCUMENT_MB
    errors.add(:file, "pesa más de #{limit} MB (lo más que acepta WhatsApp)") if file.byte_size.to_i > limit.megabytes
  end
end
