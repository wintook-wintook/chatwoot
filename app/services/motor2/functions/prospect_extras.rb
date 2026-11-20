# frozen_string_literal: true

# «Atención a prospectos» — lo que pasa alrededor de la plática (lo incluye Motor2::Functions::Prospects):
#   lo que comparten los tres agentes (seguimiento, recordatorio de cita, plazo, cotizar): Motor2::Functions::Extras
#   ad_block             de qué anuncio de clic a WhatsApp viene (para el prompt)
module Motor2::Functions::ProspectExtras
  include Motor2::Functions::Extras

  private

  # Viene de un anuncio de clic a WhatsApp (Whatsapp::IncomingMessageBaseService#note_ad_referral): de cuál.
  def ad_block(conversation)
    ad = conversation.try(:additional_attributes).to_h['ad_referral'].to_h
    text = [ad['headline'], ad['body']].compact_blank.join(' — ')
    return '' if text.blank?

    "VIENE DEL ANUNCIO: «#{text.first(300)}». Si su primer mensaje es genérico («info», «precio»), dale la bienvenida " \
      'hablando de eso (sin preguntarle qué le interesó) y sigue con tus preguntas.'
  end
end
