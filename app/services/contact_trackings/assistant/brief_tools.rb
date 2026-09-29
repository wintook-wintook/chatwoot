# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LAS HERRAMIENTAS DE UN ENCARGO, CONTRA EL MOTOR
# ================================================================================
# El lector anota qué necesita el agente con palabras simples ("hoja", "agenda",
# "ticket"). Esta es la ÚNICA tabla que traduce eso al motor. Se usa en tres lados:
#   BriefReader    la lista de tipos que puede anotar y la gramática que reconoce
#   BriefGaps      si la cuenta tiene la herramienta
#   BriefComposer  qué directiva EXACTA escribir, con el nombre real de la fuente
#
# NO SE REPITE LA GRAMÁTICA DEL MOTOR: las directivas de las fuentes salen de
# InventoryService (SOURCE_DIRECTIVES y lo que la cuenta tiene conectado, con su
# nombre exacto). Hasta el 23/09 estaban escritas a mano en tres archivos; el
# Composer mandaba "{{hoja:NOMBRE EXACTO…}}" y el modelo inventó una hoja que no
# existía en la cuenta.
#
# UN TIPO DE FUENTE NUEVO EN EL MOTOR: si se agrega a KnowledgeSource::SOURCE_TYPES y
# a SOURCE_DIRECTIVES sin darle un nombre acá, falla el spec de completitud
# (brief_tools_spec). Mientras tanto no se pierde: el lector lo anota como "otra" y la
# redacción igual lo ve, porque recibe el inventario completo de la cuenta
# (InterviewService → InventoryPrompt).
# ================================================================================

module ContactTrackings::Assistant::BriefTools
  # tipo en la ficha → source_type del motor (lo que el agente CONSULTA)
  SOURCES = {
    'predefinidas' => 'canned_response',
    'foro' => 'discourse',
    'articulo' => 'article',
    'documento' => 'google_doc',
    'hoja' => 'google_sheet',
    'contpaq' => 'contpaq_support'
  }.freeze
  # tipo en la ficha → lo que el agente HACE al cerrar. Salen del inventario: el
  # ticket con los tipos de caso de la cuenta, la agenda si hay calendario.
  ACTIONS = %w[ticket agenda].freeze
  # Sin cruce con la cuenta: el ERP depende de la bandera `erp_connection`, el adjunto
  # es del agente (no de la cuenta), y persona/otra no son directivas.
  OTHERS = %w[erp adjunto persona otra].freeze
  TYPES = (SOURCES.keys + ACTIONS + OTHERS).freeze

  module_function

  # true / false si la cuenta la tiene; nil si no depende de la cuenta.
  def available?(tipo, inventory)
    directivas = directives(tipo, inventory)
    return nil if directivas.nil?

    directivas.any?
  end

  # Las directivas que el agente puede usar para ese tipo en ESTA cuenta, tal cual
  # se escriben ("{{hoja:Cartera vencida}}"). nil si el tipo no se cruza con la cuenta.
  def directives(tipo, inventory)
    return source_directives(SOURCES[tipo], inventory) if SOURCES.key?(tipo)
    return Array(inventory[:case_types]).map { |t| "@crear_ticket(tipo=#{t})" } if tipo == 'ticket'
    return calendar_directives(inventory) if tipo == 'agenda'
    return (inventory[:erp_enabled] ? ['{{consulta:…}}'] : []) if tipo == 'erp'

    nil
  end

  def source_directives(source_type, inventory)
    Array(inventory[:sources]).select { |s| s[:source_type] == source_type }.pluck(:directive)
  end

  def calendar_directives(inventory)
    agenda = Array(inventory[:actions]).find { |a| a[:directive] == '@agendar_calendar' }
    agenda && agenda[:available] ? ['@agendar_calendar'] : []
  end

  # La gramática que el lector tiene que reconocer en un prompt viejo, armada desde
  # la del motor: "@buscar_foro(…) → foro · {{hoja:…}} → hoja · …".
  def grammar
    fuentes = SOURCES.filter_map do |tipo, source_type|
      plantilla, = ContactTrackings::Assistant::InventoryService::SOURCE_DIRECTIVES[source_type]
      "#{plantilla.include?('%s') ? format(plantilla, '…') : plantilla} → #{tipo}" if plantilla
    end
    (fuentes + ['@discourse → foro', '@crear_ticket → ticket', '@agendar_calendar → agenda',
                '{{consulta:…}} → erp', '{{nombre}} de un archivo → adjunto']).join(' · ')
  end
end
