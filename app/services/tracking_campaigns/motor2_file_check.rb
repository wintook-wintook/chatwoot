# frozen_string_literal: true

# Campaña con IA — la parte de la revisión antes de lanzar (Motor2Check) que mira las imágenes y archivos de la
# campaña: que cada uno tenga cuándo va y que ese momento pueda pasar con como está armada la campaña.
#   interest → la primera muestra de interés (información, «le interesa», cotizar, pide la liga, ya lo hizo); en correo,
#              adjunta al primer correo; en Invitar, cuando pide la información del evento · confirm → Invitar, al
#              confirmar (también con la palabra clave) ·
#   ask → cuando lo pida o le sirva. No van por toque (la apertura y los toques en WhatsApp son plantilla).
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
    text = text_for(moments)
    text && { key: :"file_#{file.id}", level: 'warning', text: "«#{file.name}»: #{text}" }
  end

  def text_for(moments)
    return 'no tiene cuándo va; nunca se manda. Márcale un momento.' if moments.empty?
    return nil if moments.include?('ask') # «Cuando lo pida»: siempre puede salir

    wrong_moment unless moments.intersect?(own_moments)
  end

  def wrong_moment
    return 'en una encuesta no hay interés ni confirmación; márcale «Cuando lo pida».' if survey?

    'su momento no aplica a este tipo de campaña; márcale otro.'
  end

  def own_moments
    return [] if survey?

    invite? ? %w[interest confirm] : %w[interest]
  end

  def survey? = @kind == 'survey'
  def invite? = @kind == 'invite'
end
