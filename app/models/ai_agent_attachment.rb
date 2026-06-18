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

  # Slug inequívoco para que el token @adjunto:name termine sin ambigüedad al parsearse.
  NAME_FORMAT = /\A[a-zA-Z0-9_-]+\z/

  validates :name, presence: true,
                   length: { minimum: 1, maximum: 60 },
                   format: { with: NAME_FORMAT,
                             message: 'solo admite letras, números, guion y guion bajo (sin espacios)' },
                   uniqueness: { scope: :tracking_template_id, case_sensitive: false }
  validate :file_must_be_attached

  private

  def file_must_be_attached
    errors.add(:file, 'debe adjuntarse un archivo') unless file.attached?
  end
end
