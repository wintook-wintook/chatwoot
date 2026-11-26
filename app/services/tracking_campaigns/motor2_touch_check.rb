# frozen_string_literal: true

# Campaña con IA — la parte de la revisión antes de lanzar (Motor2Check) que mira las plantillas de WhatsApp: a quien no
# ha escrito solo se le puede escribir con plantilla aprobada, en la apertura y en cada toque; si dos usan la misma, le
# llegaría lo mismo dos veces.
class TrackingCampaigns::Motor2TouchCheck
  def initialize(campaign, attempts)
    @campaign = campaign
    @templates = Array(campaign.touches.to_h['templates'])
    @attempts = attempts
  end

  def call
    approved = approved_templates
    (1..@attempts).map do |n|
      name = @templates[n - 1].presence
      label = self.class.label(n)
      next item(n, 'error', "#{label}: elige su plantilla de WhatsApp.") unless name
      next item(n, 'error', "#{label}: la plantilla «#{name}» no está aprobada o ya no existe.") unless approved.include?(name)
      next item(n, 'warning', "#{label}: usa la misma plantilla que «#{repeated_of(n)}»; le llegaría lo mismo.") if repeated_of(n)

      item(n, 'ok', "#{label}: plantilla «#{name}».")
    end
  end

  # El mensaje 1 es la apertura; los demás, los toques a quien no contesta.
  def self.label(number) = number == 1 ? 'Apertura' : "Toque #{number - 1}"

  private

  # El mensaje anterior que ya usa esa plantilla, o nil.
  def repeated_of(number)
    first = @templates.first(number - 1).index(@templates[number - 1])
    first && self.class.label(first + 1)
  end

  def approved_templates
    Array(@campaign.inbox.channel.try(:message_templates)).select { |t| t['status'].to_s.casecmp('approved').zero? }.pluck('name')
  end

  def item(number, level, text) = { key: :"touch_#{number}", level: level, text: text }
end
