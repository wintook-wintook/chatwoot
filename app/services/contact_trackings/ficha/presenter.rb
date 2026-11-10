# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — LA FICHA DE UN AGENTE QUE YA EXISTE, PARA LA PANTALLA
# ================================================================================
# Tarjetas, lo marcado, los cambios contra el Entrenamiento, ¿listo para atender?, y lo
# que se edita en Recursos: canal y seguimiento, agenda, archivos, reglas, bienvenida,
# preguntas y las rutas (para «con la ruta X»).
# ================================================================================

class ContactTrackings::Ficha::Presenter
  FILE_LINE_RE = /\A\s*\{\{[^}]+\}\}\s*\z/

  def initialize(template)
    @template = template
  end

  def call
    cards = ContactTrackings::Ficha::Catalog.new(@template.account, inbox: @template.inbox, template: @template).call
    cambios = ContactTrackings::Ficha::Changes.new(@template, cards: cards)
    ofertas = ContactTrackings::Ficha::Offers.new(cards, cambios.items).call
    { cards: cards, items: cambios.items, changes: cambios.call.except(:deduced),
      readiness: ContactTrackings::Ficha::Readiness.new(@template.account, offers: ofertas, template: @template).call,
      routes: cambios.test_routes.map { |r| r.slice(:name, :label) } }.merge(settings)
  end

  private

  def settings
    t = @template
    { keyword_actions: t.keyword_actions || [], file_rules: t.file_rules, attempts: t.follow_up_attempts,
      agenda: t.slice(:calendar_event_duration, :timezone, :slots_presentation, :booking_calendar_ids),
      follow: { inbox_id: t.inbox_id, retry_interval_value: t.retry_interval_value, retry_interval_unit: t.retry_interval_unit,
                attempts: t.follow_up_attempts, whatsapp_templates: Array(t.whatsapp_templates), email_signature: t.email_signature },
      profile: t.slice(:name, :customer_display_name, :objective, :ai_context) }.merge(prompt_settings)
  end

  # Bienvenida (sin sus {{archivos}} ni la primera pregunta si va pegada) y preguntas.
  def prompt_settings
    preguntas = ContactTrackings::Ficha::Questions.new(@template.complementary_prompt).read
    bienvenida = ContactTrackings::WelcomeMessage.text(@template.complementary_prompt).to_s.lines.grep_v(FILE_LINE_RE).join.strip
    { welcome: ContactTrackings::Ficha::Questions.welcome_without(bienvenida, preguntas), questions: preguntas }
  end
end
