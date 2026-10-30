# frozen_string_literal: true

# ================================================================================
# feat/plantillas_whatsapp_mejoras — ¿DÓNDE SE USA ESTA PLANTILLA?
# ================================================================================
# Antes de borrar una plantilla, el modal avisa qué envíos van a fallar. Todo se guarda por
# nombre y en la misma bandeja:
#
#   agentes       tracking_templates.whatsapp_templates (los seguimientos nuevos la heredan)
#   seguimientos  contact_trackings.whatsapp_templates, en los que siguen vivos
#   campañas      las que no han terminado y usan uno de esos agentes
#   portales      case_portals.acuse_template_name (por nombre e idioma)
#
# Agentes, seguimientos y campañas guardan solo el nombre: si queda el mismo nombre en otro
# idioma pueden seguir mandándolo, así que ahí no hay nada que avisar.
#
# Los mensajes programados no cuentan: su tabla no tiene las columnas de plantilla que usa
# ScheduledMessage (is_template, template_name…), así que hoy no se pueden guardar.
# ================================================================================
class Whatsapp::TemplateUsage
  LIVE_TRACKINGS = %w[pending scheduled active paused].freeze
  NAME_IN_LIST = 'jsonb_exists(whatsapp_templates::jsonb, ?)'

  def self.call(template)
    new(template).call
  end

  def initialize(template)
    @template = template
    @channel = template.channel_whatsapp
    @inbox = @channel.inbox
  end

  def call
    agentes = other_language? ? [] : agents.select(:id, :name).to_a
    {
      agents: agentes.map { |a| { id: a.id, name: a.name } },
      trackings_count: other_language? ? 0 : trackings_count,
      campaigns: campaigns_of(agentes).map { |c| { id: c.id, name: c.name } },
      portals: portals.map { |p| { id: p.id, name: p.name } }
    }
  end

  private

  def other_language?
    return @other_language if defined?(@other_language)

    @other_language = Array(@channel.message_templates).any? do |t|
      t['name'] == @template.name && t['language'] != @template.language
    end
  end

  def agents
    TrackingTemplate.where(inbox_id: @inbox.id).where(NAME_IN_LIST, @template.name)
  end

  def trackings_count
    ContactTracking.where(inbox_id: @inbox.id, status: LIVE_TRACKINGS).where(NAME_IN_LIST, @template.name).count
  end

  def campaigns_of(agentes)
    return [] if agentes.empty?

    TrackingCampaign.where(tracking_template_id: agentes.map(&:id)).where.not(status: 'finished').select(:id, :name)
  end

  def portals
    CasePortal.where(inbox_id: @inbox.id, acuse_template_name: @template.name, acuse_template_language: @template.language)
  end
end
