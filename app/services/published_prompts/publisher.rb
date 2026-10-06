# frozen_string_literal: true

# ================================================================================
# proyecto@publicar_prompts — PUBLICAR / DESPUBLICAR EL PROMPT DE UN AGENTE IA
# ================================================================================
# Un agente tiene UNA publicación. Publicarlo otra vez toma una foto nueva del agente y
# sube la versión: las cuentas que ya lo bajaron se quedan con su copia, sin cambios.
# Despublicar solo lo saca de la Galería; la fila se conserva (contador de descargas,
# copias que apuntan a ella) y volver a publicar la reactiva con versión nueva.
#
# F6: los archivos del agente ({{nombre}}) viajan solo si el autor los elige
# (`attachment_ids`). Se copian en cada publicación, así lo publicado no cambia si el
# autor después cambia o borra el archivo en su agente. `attachment_ids: nil` (no vino)
# vuelve a copiar los mismos nombres que tenía la versión anterior. Un archivo que viaja
# deja de figurar en «tienes que configurar».
#
# El permiso (User#can_publish_prompts?) lo revisa el controlador, no este servicio.
# Plan: docs/publicar_prompts_plan.md (F2, F6)
# ================================================================================

class PublishedPrompts::Publisher
  def initialize(template, user)
    @template = template
    @user = user
  end

  def publication
    @publication ||= PublishedPrompt.find_or_initialize_by(tracking_template: @template)
  end

  def publish!(title: nil, description: nil, category: nil, attachment_ids: nil)
    archivos = selected_attachments(attachment_ids)
    take_snapshot(archivos)
    publication.assign_attributes(listing(title, description, category))
    publication.assign_attributes(
      account: @template.account,
      user: @user,
      version: publication.new_record? ? 1 : publication.version + 1,
      status: 'published',
      published_at: Time.current
    )
    ActiveRecord::Base.transaction do
      publication.save!
      replace_files(archivos)
    end
    publication
  end

  def unpublish!
    publication.update!(status: 'unpublished') if publication.persisted?
    publication
  end

  private

  def selected_attachments(attachment_ids)
    adjuntos = @template.ai_agent_attachments.includes(file_attachment: :blob)
    return adjuntos.where(id: attachment_ids) unless attachment_ids.nil?
    return adjuntos.none if publication.new_record?

    adjuntos.where(name: publication.files.pluck(:name))
  end

  # La foto del agente, sin pedir como requisito los archivos que ya viajan.
  def take_snapshot(archivos)
    foto = PublishedPrompts::Snapshot.new(@template).attributes
    nombres = archivos.map { |a| a.name.downcase }
    foto[:requirements] = foto[:requirements].reject do |req|
      req['kind'] == 'attachment' && nombres.include?(req['name'].to_s.downcase)
    end
    publication.assign_attributes(foto)
  end

  def replace_files(archivos)
    publication.files.destroy_all
    archivos.each do |adjunto|
      next unless adjunto.file.attached?

      copia = publication.files.new(name: adjunto.name)
      PublishedPrompts::FileCopier.copy(adjunto.file, copia.file)
      copia.save!
    end
    publication.files.reset
  end

  # Lo que se ve en la Galería. Un campo que no viene (nil) conserva lo de la versión
  # anterior; uno que viene vacío lo borra. El título nunca queda vacío.
  def listing(title, description, category)
    {
      title: title.presence || publication.title.presence || @template.name,
      description: description.nil? ? publication.description : description.presence,
      category: category.nil? ? publication.category : category.presence
    }
  end
end
