# frozen_string_literal: true

# Campaña con Vendedor IA — el correo del toque que escribió la empresa en la campaña (touches['emails'][n]):
# sale tal cual, con {{contacto}} (primer nombre) y {{empresa}} llenos y las ligas con conteo de clics
# (TrackingCampaigns::ClickLink). nil si no es una campaña 2.0 de correo o ese toque no trae texto: entonces lo
# escribe el agente (Motor2::Attempt). Lo usa Motor2::AttemptHook; la firma la pone ContactTrackingJob.
module Motor2::CampaignTouch
  module_function

  def text(tracking)
    campaign = tracking.tracking_campaign
    return unless campaign&.motor2?
    return whatsapp_opener(campaign, tracking) if tracking.inbox&.whatsapp?

    email_text(campaign, tracking)
  end

  def email_text(campaign, tracking)
    return unless tracking.inbox&.email?

    clicked = TrackingCampaignClick.exists?(contact_tracking_id: tracking.id)
    body = TrackingCampaigns::Motor2Brief.email_body(campaign, tracking.attempt_count + 1, clicked: clicked)
    body &&= TrackingCampaigns::SurveyLink.append(campaign, tracking, fill(body, tracking.contact, campaign))
    body && TrackingCampaigns::ClickLink.wrap(body, tracking)
  end

  # El correo que escribió la IA (sin texto de la empresa): también con la encuesta y el conteo de clics.
  def ai_text(tracking, text)
    campaign = tracking.tracking_campaign
    return text unless text.present? && campaign&.motor2? && tracking.inbox&.email?

    TrackingCampaigns::ClickLink.wrap(TrackingCampaigns::SurveyLink.append(campaign, tracking, text), tracking)
  end

  # El mensaje que va a salir es la apertura (el primero; no los del seguimiento corto, que reinician attempt_count).
  def opener?(tracking) = tracking.attempt_count.to_i.zero? && !tracking.motor2_state.to_h['follow_up']

  # WhatsApp con la ventana abierta: el texto que escribió la empresa para el toque N; vacío, lo escribe la IA. La
  # apertura no lleva texto fijo: sale con su plantilla (Motor2::CampaignSendHook).
  def whatsapp_opener(campaign, tracking)
    written = fixed_text(campaign, tracking.attempt_count.to_i + 1)
    written.present? ? fill(written, tracking.contact, campaign) : nil
  end

  MAX_TOUCH_TEXTS = 5 # toques después de la apertura (la campaña manda hasta 6 mensajes)

  # Los textos fijos de los toques, por posición (toque 1, 2…): uno vacío deja que la IA lo escriba.
  def clean_texts(list, max_length)
    texts = Array(list).first(MAX_TOUCH_TEXTS).map { |t| t.to_s.strip.first(max_length) }
    texts.any?(&:present?) ? texts : nil
  end

  # Mensaje n de la campaña: 2.. = toque 1.. (brief.touch_texts). La apertura (1) no tiene texto fijo.
  def fixed_text(campaign, number)
    return '' if number <= 1

    Array(campaign.brief.to_h['touch_texts'])[number - 2].to_s.strip
  end

  # {{contacto}}, {{empresa}}, {{oferta}} (lo que ofrece la campaña) y, de cada contacto, {{ultima_compra}},
  # {{que_vence}}, {{vence}} y {{monto}} (TrackingCampaigns::ContactFacts).
  CONTACT_FACTS = { 'ultima_compra' => 'last_purchase', 'que_vence' => 'due_what', 'vence' => 'due_date', 'monto' => 'due_amount' }.freeze

  def fill(body, contact, campaign = nil)
    offer = campaign&.brief.to_h['offer_what'].to_s.squish
    body = body.gsub(/\{\{\s*oferta\s*\}\}/i, offer)
    body = fill_facts(body, contact) if body.match?(/\{\{\s*(#{CONTACT_FACTS.keys.join('|')})\s*\}\}/i)
    fill_contact(body, contact)
  end

  def fill_facts(body, contact)
    values = contact.is_a?(Contact) && contact.persisted? ? TrackingCampaigns::ContactFacts.new(contact).values : {}
    CONTACT_FACTS.reduce(body) { |text, (tag, key)| text.gsub(/\{\{\s*#{tag}\s*\}\}/i, values[key].to_s) }
  end

  def fill_contact(body, contact)
    first = contact&.name.to_s.strip.split(/\s+/).first.to_s
    attrs = contact&.additional_attributes || {}
    company = (attrs['company_name'].presence || attrs['company'].presence).to_s.strip
    body.gsub(/\{\{\s*contacto\s*\}\}/i, first).gsub(/\{\{\s*empresa\s*\}\}/i, company).gsub(/[ \t]+([,.;:!?])/, '\1')
  end
end
