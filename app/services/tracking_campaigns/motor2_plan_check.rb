# frozen_string_literal: true

# Campaña con Vendedor IA — la parte de la revisión antes de lanzar (Motor2Check) que mira el plan completo:
#   capacity          con tope diario y fecha de fin, ¿alcanzan los días hábiles para todos los toques?
#   cost              WhatsApp: cuántas plantillas de marketing (las cobra Meta) puede llevar la campaña
#   seller_templates  las plantillas que usa el vendedor (seguimiento pasadas 24 h, aviso de cita) en ESTA bandeja
class TrackingCampaigns::Motor2PlanCheck
  def initialize(campaign, answers, attempts)
    @campaign = campaign
    @answers = answers
    @attempts = attempts
  end

  # Con tope diario y fecha de fin: ¿alcanzan los días para mandar todos los toques? (los que no, se quedan fuera).
  def capacity
    size = Array(@campaign.audience.to_h['contact_ids']).size
    cap = @campaign.daily_cap.to_i
    return nil if size.zero? || cap.zero? || @campaign.ends_at.nil?

    days = business_days(@campaign.scheduled_for || Time.current, @campaign.ends_at)
    needed = (size * @attempts.to_f / cap).ceil
    return nil if needed <= days

    item(:capacity, 'warning', "Con #{cap} al día se necesitan unos #{needed} días hábiles y la campaña dura #{days}: amplía el fin o sube el tope.")
  end

  def business_days(from, to)
    (from.to_date..to.to_date).count { |d| !d.saturday? && !d.sunday? }
  end

  # WhatsApp: Meta cobra cada plantilla de marketing que sale (los toques a quien no ha escrito en 24 h).
  def cost
    return nil unless @campaign.inbox&.whatsapp?

    size = Array(@campaign.audience.to_h['contact_ids']).size
    per = @attempts
    text = "Cada contacto que no conteste recibe hasta #{per} plantilla(s); Meta cobra cada una como mensaje de marketing."
    text += " Con #{size} contactos: hasta #{size * per} mensajes." if size.positive?
    item(:cost, 'ok', text)
  end

  # Las plantillas que usa el vendedor (seguimiento pasadas las 24 h, aviso de la cita) deben estar en ESTA bandeja.
  def seller_templates
    return [] unless @campaign.inbox&.whatsapp?

    ok = approved
    names = Array(@answers.dig('follow_up', 'templates')) + [@answers.dig('appointment_notice', 'template')]
    names.compact_blank.uniq.reject { |name| ok.include?(name) }.map do |name|
      item(:"seller_template_#{name}", 'warning',
           "El vendedor usa la plantilla «#{name}», que no está aprobada en «#{@campaign.inbox.name}»: ese mensaje no saldría.")
    end
  end

  private

  def item(key, level, text) = { key: key, level: level, text: text }

  def approved
    Array(@campaign.inbox.channel.try(:message_templates)).select { |t| t['status'].to_s.casecmp('approved').zero? }.pluck('name')
  end
end
