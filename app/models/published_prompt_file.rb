# == Schema Information
#
# Table name: published_prompt_files
#
#  id                  :bigint           not null, primary key
#  name                :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  published_prompt_id :bigint           not null
#
# Indexes
#
#  index_published_prompt_files_on_published_prompt_id           (published_prompt_id)
#  index_published_prompt_files_on_published_prompt_id_and_name  (published_prompt_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (published_prompt_id => published_prompts.id) ON DELETE => cascade
#
# ================================================================================
# proyecto@publicar_prompts (F6)
# ================================================================================
# Modelo: PublishedPromptFile
# Descripción: un archivo del agente ({{nombre}}) publicado junto con el prompt. Es una
# copia propia del archivo: si el autor lo cambia o lo borra en su agente, lo publicado
# sigue igual hasta que vuelva a publicar. Al bajar el prompt se copia otra vez, como
# AiAgentAttachment del agente nuevo. Plan: docs/publicar_prompts_plan.md
# ================================================================================

class PublishedPromptFile < ApplicationRecord
  belongs_to :published_prompt

  has_one_attached :file

  validates :name, presence: true, length: { maximum: 60 },
                   format: { with: AiAgentAttachment::NAME_FORMAT },
                   uniqueness: { scope: :published_prompt_id, case_sensitive: false }
  validate :file_must_be_attached

  def summary
    { 'name' => name, 'filename' => file.filename.to_s, 'byte_size' => file.byte_size, 'content_type' => file.content_type }
  end

  private

  def file_must_be_attached
    errors.add(:file, 'debe adjuntarse un archivo') unless file.attached?
  end
end
