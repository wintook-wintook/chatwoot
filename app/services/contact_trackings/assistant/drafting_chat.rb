# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — CONVERSAR PARA ARMAR UN AGENTE DESDE CERO
# ================================================================================
# Antes de que exista un Entrenamiento, el chat del Asistente conversa como un
# consultor (pedido del usuario, 24/09/2026, con el ejemplo de ChatGPT armando el
# prompt de un consultorio de psicología): explica, recomienda, pregunta por bloques,
# da un cuestionario si se lo piden. La meta de la conversación es LLENAR LAS
# INSTRUCCIONES INICIALES, la misma plantilla que se descarga en el modal
# (public/assistant/instrucciones_iniciales_ejemplo.md). Con ellas llenas, «Crear el
# Entrenamiento» entra por el camino de las instrucciones subidas (BriefIntake →
# BriefDigestService → BriefComposer → BriefCoverage): no hay un segundo redactor.
#
# POR QUÉ MEJOR QUE CHATGPT CON LA MISMA PLANTILLA: además de la plantilla, el modelo
# recibe los RECURSOS DE LA CUENTA (EngineCatalog): sabe que hay calendario, qué hojas,
# qué tipos de caso. No pregunta lo que la cuenta ya resuelve: lo propone.
#
# CONTRATO: JSON { "mensaje": "…", "instrucciones": "el .md completo" | null }.
# null = no cambió nada (una pregunta, una explicación). Las instrucciones se escriben
# en palabras simples, nunca en la gramática del motor: esa la pone la redacción.
# ================================================================================

class ContactTrackings::Assistant::DraftingChat
  EXAMPLE_PATH = Rails.public_path.join('assistant/instrucciones_iniciales_ejemplo.md')
  # Medido el 24/09/2026 con el consultorio de psicología, pidiendo un cuestionario:
  #   gpt-4o        4 s  · 17 preguntas, genérico, sin emergencias ni recursos
  #   gpt-5.4-mini 10 s  · 75 preguntas, completo y del giro        ← elegido por el usuario
  #   gpt-5.5      55 s  · 90 preguntas, al nivel de ChatGPT, pero lento
  # Solo conversa con este modelo: leer las instrucciones y escribir el Entrenamiento
  # siguen con gpt-4o (decisión A del plan de instrucciones iniciales).
  MODEL = 'gpt-5.4-mini'
  # Incluye lo que el modelo razona antes de contestar (familia gpt-5).
  MAX_OUTPUT_TOKENS = 12_000
  # Cada recurso del catálogo, en palabras (la ficha dice su sintaxis, que en una
  # conversación no le sirve a nadie). Medido: con «✓ @agendar_calendar» el modelo no
  # dijo nunca que la cuenta tenía calendario.
  RESOURCE_NAMES = {
    'erp' => 'ERP conectado: consulta productos, precios, existencias o saldos',
    'predefinidas' => 'Respuestas predefinidas cargadas (grupos)',
    'articulo' => 'Centro de Ayuda con artículos',
    'foro' => 'Foro Discourse',
    'discourse' => 'Foro Discourse por canal',
    'contpaq' => 'Soporte de CONTPAQi',
    'doc' => 'Documentos de Google',
    'hoja' => 'Hojas de Google (precios, datos, cálculos exactos)',
    'crear_ticket' => 'Abrir casos para que los atienda una persona (tipos de caso)',
    'estado_ticket' => 'Decirle al cliente cómo va su caso',
    'agendar' => 'Calendario conectado: puede agendar, mover y cancelar citas',
    'adjunto' => 'Enviar archivos que se carguen al agente (catálogos, menús…)'
  }.freeze
  # Lo que cabe en la conversación: más largo que esto no son instrucciones, es un manual.
  MAX_INSTRUCTIONS_CHARS = 30_000

  PROMPT = <<~PROMPT
    Eres el Asistente de Agentes IA de la plataforma. Ayudas a una persona a armar DESDE
    CERO un agente de IA que atiende a sus clientes por chat (WhatsApp, Instagram, web).
    Conversas como un consultor con experiencia: explicas, recomiendas, preguntas.

    TU META: llenar las INSTRUCCIONES INICIALES del agente, con esta plantilla. Es un
    ejemplo de un gimnasio: copia la ESTRUCTURA (las secciones ##), no el contenido.

    ──── PLANTILLA ────
    __PLANTILLA__
    ──── FIN DE LA PLANTILLA ────

    __RECURSOS__

    ═══ CÓMO CONVERSAS ═══
    1. Habla de tú, en el idioma de la persona, cálido y directo. Usa listas cuando ayuden.
    2. EN TU PRIMERA RESPUESTA, siempre:
       a) confirma lo que entendiste (giro y para qué quiere el agente);
       b) di qué vas a usar de los RECURSOS DE LA CUENTA para este caso, con nombre
          ("tu cuenta tiene calendario conectado: ahí agendo las citas");
       c) da al menos 3 recomendaciones PROPIAS DEL GIRO, concretas (psicología: no
          diagnosticar, protocolo ante una emergencia o riesgo, confidencialidad;
          cobranza: nunca amenazar, promesa de pago con fecha; restaurante: alergias…);
       d) haz el primer bloque de preguntas (hasta 5), las más importantes primero.
    3. Después, pregunta por bloques lo que falte (hasta 5 por mensaje), sección por
       sección, y anota cada respuesta en las instrucciones.
    4. SI TE PIDEN UN CUESTIONARIO: dáselo COMPLETO, numerado por sección de la
       plantilla, con preguntas PROPIAS DEL GIRO y, donde ayude, opciones de ejemplo
       para marcar (ej. psicología: modalidad presencial / en línea / ambas; duración de
       la sesión; política de cancelación; qué datos pedir para agendar; pacientes que
       atiende; qué hacer ante una emergencia; precios y formas de pago; datos del
       consultorio). Dile que puede contestar por bloques y "por definir" lo que no sepa.
       Cada tema del cliente lleva SUS preguntas; nunca un subtítulo vacío. Un
       cuestionario COMPLETO tiene entre 30 y 60 preguntas: no lo resumas. Propón tú los
       temas que un negocio de ese giro recibe (no solo el que te dijeron) y cubre lo
       que ese giro necesita definir: servicios y a quién atiende, modalidad, horarios,
       precios y pagos, cómo se agenda y qué datos pide, cambios y cancelaciones, qué
       hacer ante lo delicado del giro, cuándo pasar a una persona, datos del negocio,
       tono y etiquetas.
       Profundidad esperada (ejemplo de OTRO giro, un restaurante; copia el nivel de
       detalle, no el contenido):
         4.1 Reservar mesa
         - ¿Cuántas personas como máximo por reserva? ¿Y para grupos grandes?
         - ¿Con cuánta anticipación se puede reservar? ¿Se reserva el mismo día?
         - ¿Qué datos pide? (nombre / teléfono / número de personas / ocasión especial)
         - ¿Pide anticipo? ¿Cuánto y cómo se paga?
         - Si no hay lugar a esa hora: ¿ofrece otro horario, lista de espera o nada?
         - ¿Confirma la reserva un día antes? ¿Cómo?
    5. USA LOS RECURSOS DE LA CUENTA: no preguntes lo que la cuenta ya resuelve,
       propónlo; ofrece sus nombres reales (una hoja, un tipo de caso, una etiqueta). Si
       el agente necesita algo que la cuenta NO tiene, dilo y di que se configura en
       Base de Conocimiento o en Integraciones. Si va a agendar, aclara que al guardar
       el agente se elige con qué calendario: que la cuenta tenga uno no basta.
    6. No inventes datos del negocio (precios, horarios, dirección, teléfonos): pregúntalos.
    7. Cuando las secciones importantes estén llenas, dile que ya puede tocar
       «Crear el Entrenamiento», y qué quedaría pendiente si lo hace ahora.

    ═══ LAS INSTRUCCIONES ═══
    - Devuélvelas COMPLETAS cada vez que cambien (no solo lo nuevo), con las mismas
      secciones ## de la plantilla y en el mismo orden. Título: "# Instrucciones iniciales:
      <nombre del agente>".
    - Llénalas DESDE EL PRIMER MENSAJE con lo que ya se sabe. Si la persona dijo "un
      consultorio de psicología que agende", ya van: en "Qué tiene que lograr", agendar
      citas del consultorio; en "Lo que la gente viene a pedir", el tema Agendar cita
      con lo que harás (agendar en el calendario de la cuenta). Lo demás, vacío.
    - NADA DEL EJEMPLO: ni una regla, prohibición, tono ni dato de la plantilla del
      gimnasio pasa a estas instrucciones ("una sola pregunta por mensaje", "máximo 3
      renglones"… son de ESE ejemplo). Si crees que una regla le conviene, recomiéndala
      en el mensaje y escríbela solo si la persona la acepta.
    - Los recursos de la cuenta (un tipo de caso, una hoja, una ETIQUETA) se proponen en
      el mensaje; en las instrucciones van solo si la persona los aceptó. Nunca asignes
      a un tema una etiqueta de la cuenta que la persona no eligió: sin etiqueta dicha,
      el tema va sin etiqueta. Solo
      lo que la persona dijo o aceptó. Una sección sin información queda con su título y
      vacía. Sin las notas <!-- --> ni el texto de ejemplo de la plantilla.
    - En palabras simples, como se lo explicarías a una persona nueva: nada de @ruta,
      {{hoja:}} ni otra sintaxis del motor. Los nombres de los recursos de la cuenta
      (una hoja, un tipo de caso) sí, tal cual.
    - Si en este turno no cambió nada, "instrucciones": null.

    Contesta SOLO este JSON:
    {"mensaje": "lo que le dices a la persona", "instrucciones": "el .md completo" | null}
  PROMPT

  def initialize(account, messages:, instructions: nil)
    @account = account
    @messages = Array(messages)
    @instructions = instructions.to_s
    @chat = ContactTrackings::Assistant::OpenaiChat.new(account: account)
  end

  # { reply:, instructions:, changed: } o { error: }
  def call
    return { error: :no_api_key } if @chat.api_key.blank?
    return { error: :no_messages } if @messages.empty?

    raw = @chat.call(history, max_tokens: MAX_OUTPUT_TOKENS, model: MODEL)
    return { error: :unavailable } if raw.nil? || raw['mensaje'].blank?

    nuevas = clean(raw['instrucciones'])
    { reply: raw['mensaje'].to_s.strip, instructions: nuevas || @instructions, changed: nuevas.present? }
  end

  private

  def history
    [{ role: 'system', content: system_prompt }] + context_messages + @messages.map { |m| m.slice('role', 'content') }
  end

  # Las instrucciones como van hasta ahora: el modelo las edita, no las reescribe de memoria.
  def context_messages
    return [] if @instructions.blank?

    [{ role: 'system', content: "INSTRUCCIONES INICIALES HASTA AHORA:\n\n#{@instructions}" }]
  end

  def system_prompt
    # sub y no format: la plantilla o un nombre de la cuenta pueden traer un «%».
    PROMPT.sub('__PLANTILLA__') { EXAMPLE_PATH.read.strip }.sub('__RECURSOS__') { resources }
  end

  # Lo que la cuenta tiene y lo que no, en palabras: las fichas del catálogo del motor.
  def resources
    inventario = ContactTrackings::Assistant::InventoryService.new(@account).call
    fichas = ContactTrackings::Assistant::EngineCatalog.new(inventario).call
    ['═══ RECURSOS DE ESTA CUENTA (úsalos; no los preguntes) ═══', *ready_lines(fichas),
     missing_line(fichas), "Etiquetas que ya existen: #{labels(inventario)}"].compact.join("\n")
  end

  def ready_lines(fichas)
    fichas.select { |f| f[:status] == 'ready' && f[:group] != 'structure' }.map do |f|
      nombres = f[:items].first(8).join(' · ')
      "✓ #{RESOURCE_NAMES.fetch(f[:key], f[:syntax])}#{" — #{nombres}" if nombres.present?}"
    end
  end

  def missing_line(fichas)
    faltan = fichas.select { |f| f[:status] == 'missing' }
    faltan.any? ? "✗ Sin configurar: #{faltan.map { |f| RESOURCE_NAMES.fetch(f[:key], f[:syntax]) }.join(' · ')}" : nil
  end

  def labels(inventario)
    Array(inventario[:labels]).join(' · ').presence || 'ninguna'
  end

  def clean(texto)
    md = texto.to_s.strip
    return nil if md.blank? || md.casecmp?('null')

    md.truncate(MAX_INSTRUCTIONS_CHARS)
  end
end
