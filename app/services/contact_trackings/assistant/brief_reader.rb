# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — ENTENDER UN TROZO DEL ENCARGO (F2 de docs/importar_prompt_md_plan.md)
# ================================================================================
# Una llamada por trozo: lo que ese pedazo del encargo pide del agente, en la forma de
# BriefFicha. Los trozos los arma BriefChunker; esta clase no sabe del resto del
# documento, salvo el nombre del archivo y la ruta de títulos del trozo.
#
# LO QUE SE LE PIDE AL MODELO, Y POR QUÉ:
#   · ENTENDER, no copiar: el encargo es la idea de alguien, no el Entrenamiento. Un
#     párrafo de explicación se vuelve una regla de una línea, o nada.
#   · Solo lo que el trozo dice. Lo que no dice queda vacío: las preguntas las hace la
#     entrevista, con la persona, no el modelo adivinando (decisión del 23/09).
#   · Los ejemplos del prompt son de objetivos distintos a propósito: con un solo
#     ejemplo de ventas, todos los agentes salían vendedores (§2.1 del plan).
#   · Contradicciones dentro del trozo: se anotan, no se resuelven.
#
# LAS LÍNEAS @ruta LAS LEE EL PARSER, NO EL MODELO: un encargo que es un prompt viejo
# trae sus rutas escritas en la gramática del motor. Medido el 23/09 con el Vendedor
# Catálogo (#8724): gpt-4o copiaba la #etiqueta de una ruta sí y de otra no. RouteMap la
# lee siempre, así que el código completa etiqueta, fuente y escalamiento de cada tema
# con su ruta, y agrega como tema la ruta que el modelo no haya anotado.
#
# Devuelve { ficha:, origin:, usage: } o { error: }.
# ================================================================================

class ContactTrackings::Assistant::BriefReader
  Ficha = ContactTrackings::Assistant::BriefFicha

  PROMPT = <<~PROMPT.freeze
    Leés UN PEDAZO de un encargo: el texto donde alguien describe cómo quiere que sea
    un agente de IA que atiende clientes por chat (WhatsApp, Instagram, web). Puede ser
    un manual enorme, una página suelta, viñetas, un correo o un prompt viejo.

    Tu trabajo es ENTENDER qué pide este pedazo y anotarlo en la ficha, en JSON, con
    esta forma exacta:

    #{Ficha::SHAPE}
    ═══ REGLAS ═══
    1. Solo lo que ESTE pedazo dice. Si no dice algo, dejalo en null o en lista vacía.
       No completes con lo que "suele" hacer un agente así: lo que falte se le pregunta
       a la persona después.
    2. Entendé, no copies. Cada punto es UNA idea corta en tus palabras (una línea). Un
       párrafo de explicación, ejemplos o justificación se vuelve una regla corta, o
       nada si no pide nada del agente.
    3. Si varias frases dicen lo mismo, es UN punto.
    4. Un "tema" es algo que el CLIENTE viene a pedir o a resolver (agendar una cita,
       reclamar un cobro, preguntar un precio, reportar una falla). No es una etapa
       interna del agente ni una sección del documento.
    5. "frases_cliente" solo si el texto trae cómo escribe el cliente, literal o casi.
       No las inventes.
    6. "prohibiciones" = lo que NUNCA hace. "reglas" = lo que hace siempre o cómo
       procede. Una misma idea va en una sola de las dos.
    7. Información que el agente CONSULTA o CITA va en "conocimiento", no en reglas:
       lo largo (un catálogo, una tabla de precios, cada servicio, un glosario) resumido,
       y los DATOS DEL NEGOCIO (dirección, horario de atención, teléfonos, sucursales)
       completos y tal cual, porque el agente los va a dar: {"tema": "Horario", "resumen":
       "lunes a viernes 6:00–22:00, sábados 8:00–14:00, domingos cerrado"}.
    8. Plantillas de mensaje textuales ("responde exactamente: …") van como regla
       que diga cuándo se usa y qué dice, en corto.
    9. Si el pedazo se contradice (una parte dice una cosa y otra lo contrario),
       anotalo en "contradicciones". No elijas.
    10. Nombres propios (empresa, producto, sucursal, teléfono) tal cual aparecen.
    11. Si un tema se atiende con una herramienta (se agenda en un calendario, se abre un
        caso, se consulta una hoja o un documento), escribilo TAMBIÉN en ese tema: en
        "fuente" si de ahí sale la respuesta, o en "si_no_resuelve" si es lo que hace el
        agente para cerrar (agendar, abrir el caso, pasar a una persona).
    12. El texto puede ser un prompt viejo escrito con la gramática del motor. Se lee así:
        @ruta(nombre #etiqueta: descripción): fuente -> escalamiento
          → un tema: nombre, etiqueta (sin el #), la descripción son las frases del
            cliente, la fuente y el escalamiento van a "fuente" y "si_no_resuelve".
        @ruta_por_defecto: nombre → el tema que atiende cuando no encaja en otro.
        Herramientas: {{consulta:…}} → erp · {{doc:…}} → documento · {{hoja:…}} → hoja
          · @buscar_predefinidas → predefinidas · @buscar_foro / @discourse → foro
          · @buscar_articulo → articulo · @crear_ticket → ticket · @agendar_calendar →
          agenda · {{nombre}} de un archivo → adjunto.

    Ejemplos de cómo se anota (de encargos distintos):
      "Si el perro no respira, que llamen a urgencias al 442…" → regla: "Ante una
        emergencia, no tomar datos: pedir que llamen a urgencias (442…) y abrir el
        caso como urgente"; tema "emergencia"; herramienta ticket.
      "Nunca amenazar con buró de crédito" → prohibición.
      "Los saldos están en la hoja Cartera vencida" → herramienta hoja, para "saldos
        y facturas vencidas".
      "Ofrecemos 13 servicios: …(dos páginas)…" → conocimiento, un punto por servicio
        con un resumen de una línea.

    Contestá SOLO el JSON.
  PROMPT

  MAX_ATTEMPTS = 2
  # Sube cada vez que cambian las instrucciones de PROMPT: una lectura hecha con otras
  # instrucciones no se reusa (ver BriefDigestService#cached_readings).
  # 2 (23/09/2026): datos del negocio a "conocimiento" y la herramienta de cada tema.
  VERSION = 2
  CONNECTORS = %w[de del la las el los y a en por con para un una].freeze

  attr_reader :chunk

  def initialize(account, chunk:, filename:)
    @account = account
    @chunk = chunk
    @filename = filename
    @chat = ContactTrackings::Assistant::OpenaiChat.new(account: account)
  end

  # La clave se lee antes de repartir trozos entre hilos: consulta la base.
  def api_key
    @chat.api_key
  end

  def call
    return { error: :no_api_key } if api_key.blank?

    usado = []
    MAX_ATTEMPTS.times do
      raw = @chat.call(messages)
      usado << @chat.last_usage if @chat.last_usage
      next if raw.nil?

      ficha, origen = Ficha.from_reading(with_routes(raw), @chunk.index)
      return { ficha: ficha, origin: origen, usage: sum_usage(usado) }
    end
    { error: :unavailable, usage: sum_usage(usado) }
  end

  private

  def messages
    [
      { role: 'system', content: PROMPT },
      { role: 'user', content: <<~TXT }
        Archivo: #{@filename}
        Dónde está este pedazo: #{@chunk.path.presence&.join(' › ') || 'principio del documento'}

        ──── PEDAZO ────
        #{@chunk.text}
      TXT
    ]
  end

  def with_routes(raw)
    rutas = ContactTrackings::RouteMap.parse(@chunk.text).routes
    return raw if rutas.empty? || !raw.is_a?(Hash)

    temas = Array(raw['temas']).select { |t| t.is_a?(Hash) }
    rutas.each do |ruta|
      tema = temas.find { |t| same_route?(t, ruta) }
      temas << (tema = { 'nombre' => ruta.name }) if tema.nil?
      fill_from_route(tema, ruta)
    end
    raw.merge('temas' => temas)
  end

  # La etiqueta de la ruta manda; lo demás solo si el modelo lo dejó vacío.
  def fill_from_route(tema, ruta)
    tema['etiqueta'] = ruta.tag if ruta.tag.present?
    tema['frases_cliente'] = [ruta.description].compact if Array(tema['frases_cliente']).empty?
    tema['fuente'] = ruta.directive if tema['fuente'].blank?
    tema['si_no_resuelve'] = ruta.escalation if tema['si_no_resuelve'].blank?
  end

  def same_route?(tema, ruta)
    nombres = [tema['nombre'], tema['etiqueta']].map { |n| route_key(n) }
    nombres.include?(route_key(ruta.name)) || (ruta.tag.present? && nombres.include?(route_key(ruta.tag)))
  end

  # "Información de carrera" y informacion_carrera son la misma ruta.
  def route_key(texto)
    palabras = I18n.transliterate(texto.to_s).downcase.scan(/[a-z0-9]+/)
    (palabras - CONNECTORS).join('_')
  end

  def sum_usage(lista)
    %w[prompt_tokens completion_tokens].index_with { |k| lista.sum { |u| u[k].to_i } }
  end
end
