# frozen_string_literal: true

# Campaña con IA — la parte de la revisión antes de lanzar (Motor2Check) que mira las imágenes y archivos de la
# campaña: que cada uno tenga cuándo va y que ese momento pueda pasar con como está armada la campaña.
#   interest → la primera muestra de interés (información, «le interesa», cotizar, pide la liga, ya lo hizo); en correo,
#              adjunta al primer correo · confirm → Invitar, al confirmar (también con la palabra clave) ·
#   ask → cuando lo pida o le sirva · attempts → en esos toques (en WhatsApp, con la ventana de 24 h abierta).
class TrackingCampaigns::Motor2FileCheck
  def initialize(campaign)
    @campaign = campaign
    @kind = campaign.brief.to_h['kind']
  end

  def call
    @campaign.offer_files.filter_map { |file| problem(file) }
  end

  private

  def problem(file)
    rules = file.rules.to_h
    moments = %w[interest confirm ask].select { |k| rules[k] }
    touches = Array(rules['attempts']).map(&:to_i)
    text = text_for(moments, touches)
    text && { key: :"file_#{file.id}", level: 'warning', text: "«#{file.name}»: #{text}" }
  end

  def text_for(moments, touches)
    return 'no tiene cuándo va; nunca se manda. Márcale un momento o un toque.' if moments.empty? && touches.empty?
    return nil if sure?(moments, touches)
    return only_first_touch if moments.empty?

    wrong_moment unless moments.include?(own_moment)
  end

  # Solo el toque 1 y por WhatsApp (en correo ya salió por sure?).
  def only_first_touch
    'está marcada para el toque 1, que en WhatsApp es la plantilla: solo sale si el contacto escribió en las últimas 24 h.'
  end

  def wrong_moment
    return 'en una encuesta no hay interés ni confirmación; márcale un toque o «Cuando lo pida».' if survey?

    'su momento no aplica a este tipo de campaña; márcale otro.'
  end

  def own_moment
    return 'none' if survey?

    invite? ? 'confirm' : 'interest'
  end

  # «Cuando lo pida», un toque después del primero o el primero en correo: siempre puede salir.
  def sure?(moments, touches)
    moments.include?('ask') || touches.any? { |n| n > 1 } || (touches.include?(1) && email?)
  end

  def email? = @campaign.inbox&.email?
  def survey? = @kind == 'survey'
  def invite? = @kind == 'invite'
end
