# frozen_string_literal: true

# ================================================================================
# proyecto@publicar_prompts (F5) — BAJAR UN PROMPT PUBLICADO A LA CUENTA
# ================================================================================
# Crea UN Agente IA (TrackingTemplate) en la cuenta con lo que trae la publicación
# elegida: es una copia, suya y editable. No se tocan ni el agente del autor ni las
# copias de otras cuentas. Se baja de a uno: la persona elige un prompt de la Galería
# del Asistente y baja solo ese.
#
# Lo atado a la cuenta del autor no viene en la publicación (ver Snapshot), así que el
# agente nuevo nace sin bandeja, calendarios, Base de Conocimiento, plantillas ni
# etiquetas. Las directivas siguen en el texto; `requirements` dice qué configurar.
#
# F6: los archivos que el autor publicó llegan como archivos propios del agente nuevo
# (pestaña «Archivos»), con el mismo nombre, así sus {{nombre}} funcionan desde ya.
#
# El nombre es único por cuenta: si «Agente de grúas» ya existe, se usa
# «Agente de grúas (2)», «(3)», …
# Plan: docs/publicar_prompts_plan.md
# ================================================================================

class PublishedPrompts::Installer
  MAX_NAME = 100

  def initialize(publication, account, user)
    @publication = publication
    @account = account
    @user = user
  end

  def install!
    ActiveRecord::Base.transaction do
      template = @account.tracking_templates.create!(template_attributes)
      copy_files(template)
      # Suma en SQL (downloads_count = downloads_count + 1): dos cuentas bajando a la vez
      # no se pisan la cuenta. No hay nada que validar en un contador.
      PublishedPrompt.update_counters(@publication.id, downloads_count: 1) # rubocop:disable Rails/SkipsModelValidations
      template
    end
  end

  private

  def copy_files(template)
    @publication.files.includes(file_attachment: :blob).find_each do |publicado|
      adjunto = template.ai_agent_attachments.new(name: publicado.name, account: @account)
      PublishedPrompts::FileCopier.copy(publicado.file, adjunto.file)
      adjunto.save!
    end
  end

  def template_attributes
    {
      name: available_name,
      objective: @publication.objective,
      ai_context: @publication.ai_context,
      complementary_prompt: @publication.prompt,
      keyword_actions: @publication.keyword_actions,
      user: @user,
      published_prompt: @publication,
      published_prompt_version: @publication.version # F7: para avisar de versiones nuevas
    }.merge(@publication.settings.slice(*PublishedPrompts::Snapshot::SETTINGS).symbolize_keys)
  end

  def available_name
    base = @publication.title.to_s.strip.first(MAX_NAME - 5)
    taken = @account.tracking_templates.pluck(:name).to_set(&:downcase)
    return base unless taken.include?(base.downcase)

    (2..999).each do |n|
      candidate = "#{base} (#{n})"
      return candidate unless taken.include?(candidate.downcase)
    end
    "#{base} (#{SecureRandom.hex(2)})"
  end
end
