# ================================================================================
# proyecto@ai_agent_assistant - F6
# ================================================================================
# Servicio: AiAgentAssistant::PatternLibrary
# Descripción: Bloques insertables extraídos de los agentes de producción que sí
#              funcionan, más la guía de forma (§13.2) y el esqueleto (§13.7).
#
# NO es una galería de plantillas para clonar. Con 27 agentes en producción el
# patrón real ya es «copio el que más se parece y lo ajusto», y eso es justo lo
# que produjo seis copias del mismo agente en la cuenta 778. El cuello de botella
# no es empezar: es saber por qué el que copiaste no funciona.
#
# Por eso cada bloque:
#   · resuelve UNA cosa difícil que alguien ya resolvió bien,
#   · deja <huecos> para el negocio en vez de texto de relleno,
#   · declara qué capacidad necesita, y
#   · sabe decir cuándo sería letra muerta en el prompt que tienes delante.
#
# Ese último punto es el que importa: ofrecer un bloque de voz propia a un agente
# con `@discourse` sería regalar caracteres que el motor va a descartar.
# ================================================================================

# Catálogo declarativo, como Capabilities y Linter: la longitud es de los datos.
class AiAgentAssistant::PatternLibrary # rubocop:disable Metrics/ClassLength
  SECTIONS = %w[rol fuente banderas flujo cierre prohibido config].freeze

  # `kind`: :prompt = texto que va dentro del prompt complementario.
  #         :config = NO va en el prompt; es configuración del agente (regla 5:
  #                   lo determinista va fuera del prompt).
  # `requires`: clave del Registry que debe estar disponible, o nil.
  # `source`: de dónde salió. Un bloque sin evidencia es una opinión.
  BLOCKS = [
    {
      key: 'role_identity', section: 'rol', kind: :prompt, requires: nil,
      body: <<~TEXT.strip,
        Eres <rol> de <empresa>. Escribes a <a quién>.
        Trato de <tú|usted> en todo momento, sin cambiar de registro a media conversación.
      TEXT
      source: 'El mejor agente de la instalación (778 · TICKETS UNIDADES V4) declara tono de ' \
              '«tú» y luego trata de «vos» seis veces. El modelo recibe dos órdenes opuestas.'
    },
    {
      key: 'channel_awareness', section: 'rol', kind: :prompt, requires: nil,
      body: 'Escribes por <canal real del inbox>. No menciones ningún otro canal.',
      source: 'Cinco agentes de la 568 y el mejor de la 778 dicen «WhatsApp» en un inbox de ' \
              'Telegram o de página web. El agente se presenta en el canal equivocado.'
    },
    {
      key: 'admits_ignorance', section: 'rol', kind: :prompt, requires: nil,
      body: <<~TEXT.strip,
        Si no tienes el dato, dilo en una línea y ofrece pasar con una persona.
        No inventes cifras, plazos ni disponibilidad.
      TEXT
      source: 'Ninguno de los 27 agentes de la 568 dice qué hacer cuando no sabe. Sin esa ' \
              'línea, el modelo rellena el hueco.'
    },
    {
      key: 'sheet_source', section: 'fuente', kind: :prompt, requires: :hoja,
      body: <<~TEXT.strip,
        {{hoja:<NOMBRE EXACTO DE LA HOJA>}}
        Consulta ahí <qué dato> antes de responder. Si no aparece, dilo; no lo deduzcas.
      TEXT
      source: 'El agente 42 de la 568 escribe dos nombres distintos de la misma hoja. Solo la ' \
              'primera coincidencia se evalúa: la otra es texto muerto.'
    },
    {
      key: 'doc_source', section: 'fuente', kind: :prompt, requires: :doc,
      body: <<~TEXT.strip,
        {{doc:<NOMBRE EXACTO DEL DOCUMENTO>}}
        Responde con lo que diga ese documento. Fuera de él, no afirmes nada.
      TEXT
      source: 'Cero de los 27 agentes de la 568 la usan, teniendo la feature activa. Es la ' \
              'única vía junto a {{hoja:}} para tener conocimiento externo y voz propia a la vez.'
    },
    {
      key: 'erp_query', section: 'fuente', kind: :prompt, requires: :consulta,
      body: <<~TEXT.strip,
        Hola {{nombre_del_contacto}}, <mensaje tal cual lo recibirá el cliente>:
        {{consulta:<conexion>/<consulta>}}
        <cierre del mensaje>
      TEXT
      source: 'Con {{consulta:}} el prompt deja de ser una instrucción: se interpola y se envía ' \
              'LITERAL, sin pasar por el modelo. Escríbelo como se lo dirías tú al cliente.'
    },
    {
      key: 'schedule_flag', section: 'banderas', kind: :prompt, requires: :agendar_calendar,
      body: <<~TEXT.strip,
        @agendar_calendar
        Cuando el cliente acepte, ofrece los horarios que te dé el sistema y confirma uno.
      TEXT
      source: 'Cuatro agentes de la 568 la usan. Uno conserva `slots_presentation` pero perdió ' \
              'los calendarios: configuración que no aplica a nada.'
    },
    {
      key: 'ticket_flag', section: 'banderas', kind: :prompt, requires: :crear_ticket,
      body: '@crear_ticket(prioridad=<LOW|MEDIUM|HIGH>, tipo=<NOMBRE EXACTO DEL TIPO DE CASO>)',
      source: 'En la 778 el `tipo` mal escrito sobrevivió tres versiones sin resolver a nada. ' \
              'El nombre tiene que coincidir con un tipo de caso real de la cuenta.'
    },
    {
      key: 'ticket_status_flag', section: 'banderas', kind: :prompt, requires: :estado_ticket,
      body: '@estado_ticket',
      source: 'Cero de 27 en la 568. Evita que el cliente tenga que escribir a una persona ' \
              'solo para preguntar «¿cómo va lo mío?».'
    },
    {
      key: 'state_machine', section: 'flujo', kind: :prompt, requires: nil,
      body: <<~TEXT.strip,
        ETAPA 1 · <qué averiguas> → pasas a la 2 cuando <condición>.
        ETAPA 2 · <qué haces> → pasas a la 3 cuando <condición>.
        ETAPA 3 · <cierre>.
        Nunca vuelvas a una etapa anterior.
      TEXT
      source: 'Es la arquitectura del mejor agente de la instalación (778 · V4). Da al modelo ' \
              'un sitio donde estar en cada turno, en vez de una lista de temas.'
    },
    {
      key: 'engine_slot_filling', section: 'flujo', kind: :prompt, requires: nil,
      body: <<~TEXT.strip,
        El sistema pide por su cuenta, uno por uno, los datos obligatorios del caso.
        No los pidas tú en bloque ni anuncies que vas a pedirlos: acompaña la conversación.
      TEXT
      source: 'Literal del agente 287 de la 778. Su autor entendió que el motor hace cosas solo ' \
              'y escribió el prompt para acompañarlo, no para reemplazarlo. Es lo que lo separa ' \
              'del resto de la instalación.'
    },
    {
      key: 'intent_router', section: 'flujo', kind: :prompt, requires: nil,
      body: <<~TEXT.strip,
        Si el mensaje es <intención A>, <qué haces>.
        Si es <intención B>, <qué haces>.
        Si no encaja en ninguna, pregunta una sola cosa para desambiguar.
      TEXT
      source: 'Patrón de los agentes que atienden soporte y venta en el mismo inbox. El motor ' \
              'ya clasifica en ocho rutas: esto es para lo que el negocio distingue, no para ' \
              'repetir lo que el motor hace.'
    },
    {
      key: 'single_close_node', section: 'cierre', kind: :prompt, requires: nil,
      body: <<~TEXT.strip,
        Se da por logrado cuando <condición verificable>.
        En ese momento envía UNA despedida y no vuelvas a escribir.
      TEXT
      source: 'Un nodo de cierre único evita el agente que sigue insistiendo con el ticket ya ' \
              'creado — exactamente lo que pasa hoy en la 778 con reintento cada 3 días.'
    },
    {
      key: 'no_questions_after_close', section: 'cierre', kind: :prompt, requires: nil,
      body: 'Después de la despedida no hagas preguntas ni uses signos de interrogación.',
      source: 'Sin esta línea el modelo cierra y vuelve a abrir en la misma frase, y el ' \
              'seguimiento nunca termina.'
    },
    {
      key: 'forbidden_commitments', section: 'prohibido', kind: :prompt, requires: nil,
      body: <<~TEXT.strip,
        Nunca: <dar precios|prometer plazos|diagnosticar|autorizar descuentos>.
        Si te lo piden, <qué haces en su lugar>.
      TEXT
      source: 'La sección que tienen los agentes de producción que funcionan y les falta a los ' \
              'que improvisan.'
    },
    {
      key: 'keyword_actions_pair', section: 'config', kind: :config, requires: nil,
      body: <<~TEXT.strip,
        En «Palabras clave de acción», no en el prompt:
        · <«ya no me interesa», «no gracias»>  → cancelar · entrante
        · <«ya pagué», «listo»>                → objetivo cumplido · entrante
      TEXT
      source: 'Corta el seguimiento de forma exacta, silenciosa y gratis: siempre gana a pedirle ' \
              'al modelo que «detecte rechazo». Solo 4 de 27 agentes de la 568 lo usan, y los ' \
              'cuatro con marcadores tipo #cumplido que el cliente acaba viendo escritos.'
    },
    {
      key: 'whatsapp_templates_per_attempt', section: 'config', kind: :config, requires: nil,
      body: <<~TEXT.strip,
        En «Plantillas de WhatsApp», una por intento.
        Sin plantillas aprobadas, pasadas 24 h la ventana está cerrada y todo reintento falla.
      TEXT
      source: 'Los agentes 43 y 36 de la 568 son de WhatsApp, reintentan cada 3 y cada 1 día, y ' \
              'no tienen ninguna plantilla. Por definición, ningún reintento suyo puede funcionar.'
    }
  ].freeze

  # La guía de forma de §13.2, en orden de impacto. Es material del chat y de la UI:
  # el asistente la cita, el editor la muestra.
  FORM_RULES = [
    { key: 'family_first',
      rule: 'Decide la familia antes de escribir una palabra: o el agente BUSCA (y el prompt se ' \
            'descarta) o el agente HABLA. Es excluyente en el código, no una preferencia. Las ' \
            'fuentes Google son la excepción: conservan el prompt.' },
    { key: 'objective_is_gold',
      rule: 'El objetivo es el único campo que llega íntegro siempre, y admite 500 caracteres. ' \
            'Si el agente usa una búsqueda, es su ÚNICO canal de instrucción: escribirlo como ' \
            'título equivale a no configurar nada.' },
    { key: 'what_not_how_much',
      rule: 'El prompt define QUÉ decir, no cuánto. Salen dos oraciones o cuatro líneas. Un ' \
            'prompt de 11 000 caracteres no se ejecuta a medias: diluye. Techo práctico, 1 500.' },
    { key: 'delete_engine_duplication',
      rule: 'Borra todo lo que el motor ya hace. Ya ordena no decir que es un bot, no hablar de ' \
            'intentos y no dar detalles técnicos. Repetirlo gasta presupuesto y a veces lo ' \
            'contradice.' },
    { key: 'deterministic_outside',
      rule: 'Lo determinista va fuera del prompt: palabras clave de acción y una plantilla de ' \
            'WhatsApp por intento. Siempre gana a pedírselo al modelo.' },
    { key: 'no_fake_keys',
      rule: 'Ninguna {{llave}} que no sea un archivo. Cualquier {{palabra}} sin dos puntos es ' \
            'una orden de adjuntar; el nombre del contacto ya llega por otro camino.' },
    { key: 'one_prompt_one_place',
      rule: 'Un prompt, un lugar. El mismo texto en tres canales son tres copias que corregir ' \
            'tres veces. Si el texto es idéntico, el agente debería ser uno.' }
  ].freeze

  # El esqueleto de §13.7. Estructura, no contenido: no hay nada que clonar.
  SKELETON = <<~TEXT.strip
    [ROL Y LÍMITES]
    <quién es, a quién escribe, trato, qué no hace nunca>

    [FUENTE]
    <{{hoja:}} o {{doc:}} si necesita consultar algo — o nada>

    [BANDERAS]
    <@agendar_calendar · @crear_ticket(...) · @estado_ticket>

    [FLUJO]
    <solo lo que el motor NO hace ya>

    [CIERRE]
    <qué cuenta como logrado>
  TEXT

  def self.for(account:, inbox: nil, template: nil, prompt: nil)
    new(account: account, inbox: inbox, template: template, prompt: prompt).call
  end

  def initialize(account:, inbox: nil, template: nil, prompt: nil)
    @account = account
    @inbox = inbox
    @template = template
    @prompt = prompt.to_s
  end

  def call
    { blocks: BLOCKS.map { |block| resolve(block) },
      sections: SECTIONS,
      rules: FORM_RULES,
      skeleton: SKELETON,
      prompt_is_discarded: prompt_discarded? }
  end

  private

  attr_reader :account, :inbox, :template, :prompt

  def resolve(block)
    block.slice(:key, :section, :kind, :body, :source).merge(
      i18n_key: "patterns.#{block[:key]}",
      requires: block[:requires],
      available: available?(block),
      chars: block[:body].length,
      status: status_for(block)
    )
  end

  def available?(block)
    return true if block[:requires].blank?

    resolved.fetch(block[:requires], false)
  end

  def resolved
    @resolved ||= AiAgentAssistant::Capabilities
                  .resolve_for(account: account, inbox: inbox, template: template)
                  .to_h { |capability| [capability[:key], capability[:available]] }
  end

  # `dead_letter` es el estado que justifica esta pieza: el bloque está bien escrito
  # y aun así no serviría de nada en ESTE prompt.
  def status_for(block)
    return 'unavailable' unless available?(block)
    return 'dead_letter' if block[:kind] == :prompt && prompt_discarded?
    return 'source_taken' if block[:section] == 'fuente' && source_taken?(block)

    'ready'
  end

  # Las cuatro búsquedas descartan el prompt entero: cualquier bloque de texto que
  # se añada es presupuesto tirado.
  def prompt_discarded?
    return @prompt_discarded if defined?(@prompt_discarded)

    @prompt_discarded = prompt.present? &&
                        AiAgentAssistant::PromptBuilder.clean_complementary_prompt(prompt).blank?
  end

  # Solo una fuente resuelve el turno. Si ya hay una, la segunda es texto muerto.
  def source_taken?(block)
    occupied = AiAgentAssistant::Capabilities.detect(prompt).select do |capability|
      AiAgentAssistant::Capabilities::EXCLUSIVE_KINDS.include?(capability[:kind])
    end

    occupied.any? && occupied.none? { |capability| capability[:key] == block[:requires] }
  end
end
