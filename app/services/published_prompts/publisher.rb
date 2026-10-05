# frozen_string_literal: true

# ================================================================================
# proyecto@publicar_prompts — PUBLICAR / DESPUBLICAR EL PROMPT DE UN AGENTE IA
# ================================================================================
# Un agente tiene UNA publicación. Publicarlo otra vez toma una foto nueva del agente y
# sube la versión: las cuentas que ya lo bajaron se quedan con su copia, sin cambios.
# Despublicar solo lo saca de la Galería; la fila se conserva (contador de descargas,
# copias que apuntan a ella) y volver a publicar la reactiva con versión nueva.
#
# El permiso (User#can_publish_prompts?) lo revisa el controlador, no este servicio.
# Plan: docs/publicar_prompts_plan.md (F2)
# ================================================================================

class PublishedPrompts::Publisher
  def initialize(template, user)
    @template = template
    @user = user
  end

  def publication
    @publication ||= PublishedPrompt.find_or_initialize_by(tracking_template: @template)
  end

  def publish!(title: nil, description: nil, category: nil)
    publication.assign_attributes(PublishedPrompts::Snapshot.new(@template).attributes)
    publication.assign_attributes(listing(title, description, category))
    publication.assign_attributes(
      account: @template.account,
      user: @user,
      version: publication.new_record? ? 1 : publication.version + 1,
      status: 'published',
      published_at: Time.current
    )
    publication.save!
    publication
  end

  def unpublish!
    publication.update!(status: 'unpublished') if publication.persisted?
    publication
  end

  private

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
