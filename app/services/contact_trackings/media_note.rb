# frozen_string_literal: true

# ================================================================================
# Imágenes y videos del cliente en el Motor 1.0 (25/11/2026)
# ================================================================================
# El 1.0 no ve imágenes ni videos. Antes, una foto sola llegaba vacía al clasificador y a
# las fuentes, y el conversacional (que sí veía «[imagen adjunta]») inventaba qué había en
# ella: describió autos que no estaban en la foto. Ahora:
#
# · el texto del mensaje lleva una marca fija (IMAGE / VIDEO) en el clasificador, en las
#   fuentes y en el conversacional, para que sepan que llegó una imagen;
# · si el turno trae una marca, el modelo recibe RULE: no la puede ver y no supone nada.
#
# El prompt de cada agente decide qué contestar («no puedo ver fotos, ¿cuál te interesa?»).
# Motor 2.0 tiene su propio lector de imágenes (Motor2::MediaReader) y no usa esto.
# ================================================================================
module ContactTrackings::MediaNote
  IMAGE = '[el cliente envió una imagen]'
  VIDEO = '[el cliente envió un video]'
  RULE = 'IMÁGENES: el cliente envió una imagen o un video y tú NO puedes verlo. Nunca describas ni ' \
         'supongas qué muestra (qué producto, auto, modelo, precio o dato). La información consultada NO ' \
         'dice qué hay en la imagen: no la uses para adivinarlo ni digas «si te refieres a…». Si el ' \
         'cliente no escribió el nombre de lo que le interesa, dile que no puedes ver imágenes y pídele ' \
         'en una frase el nombre o el modelo, sin ofrecer ninguno.'

  module_function

  # Las marcas de los adjuntos de un mensaje (una por imagen o video).
  def marks(message)
    Array(message&.attachments).filter_map do |adjunto|
      case adjunto.file_type.to_s
      when 'image' then IMAGE
      when 'video' then VIDEO
      end
    end
  end

  # El texto con sus marcas al final.
  def with_marks(text, message)
    [text.to_s.strip.presence, *marks(message)].compact.join(' ')
  end

  # La regla para el modelo, solo si el texto del turno trae una marca.
  def rule(text)
    text.to_s.include?(IMAGE) || text.to_s.include?(VIDEO) ? RULE : nil
  end
end
