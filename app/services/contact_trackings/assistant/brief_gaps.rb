# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LO QUE AL ENCARGO LE FALTA (F2 de docs/importar_prompt_md_plan.md)
# ================================================================================
# Sin IA. Compara la ficha con lo que el Asistente necesita para escribir, que son los
# mismos cuatro pasos de la entrevista (Instructions):
#
#   PASO 1  temas y modo (contesta o deriva)
#   PASO 2  cómo lo dice el cliente, tema por tema     ← nunca se deduce
#   PASO 3  de dónde sale la respuesta y qué pasa si no resuelve
#   PASO 4  con qué etiqueta cierra cada tema
#
# y cruza las herramientas que el encargo pide con el INVENTARIO real de la cuenta: un
# encargo de cobranza que lee "la hoja Cartera vencida" en una cuenta sin hojas de
# Google conectadas no puede funcionar, y eso se pregunta antes de escribir.
#
# Por qué no lo decide el modelo: "¿falta algo?" es una opinión, y un modelo que opina
# que no falta nada deja preguntas sin hacer. Qué campos están vacíos es un hecho.
# ================================================================================

class ContactTrackings::Assistant::BriefGaps
  # tipo de herramienta → cómo saber si la cuenta la tiene (nil = no depende de la cuenta)
  TOOL_CHECKS = {
    'agenda' => ->(inv) { inv[:actions].any? { |a| a[:directive] == '@agendar_calendar' && a[:available] } },
    'erp' => ->(inv) { inv[:erp_enabled] },
    'ticket' => ->(inv) { inv[:case_types].any? },
    'documento' => ->(inv) { inv[:sources].any? { |s| s[:source_type] == 'google_doc' } },
    'hoja' => ->(inv) { inv[:sources].any? { |s| s[:source_type] == 'google_sheet' } },
    'predefinidas' => ->(inv) { inv[:canned_groups].any? || inv[:sources].any? { |s| s[:source_type] == 'canned_response' } },
    'foro' => ->(inv) { inv[:sources].any? { |s| s[:source_type] == 'discourse' } },
    'articulo' => ->(inv) { inv[:sources].any? { |s| s[:source_type] == 'article' } }
  }.freeze

  def initialize(ficha, inventory:)
    @ficha = ficha
    @inventory = inventory
  end

  # [{ 'paso' => 1..4, 'que' => '…', 'tema' => '…'? , 'tipo' => '…'? }]
  # Marca antes en cada herramienta si la cuenta la tiene (ver annotate_tools!).
  def call
    annotate_tools!
    paso1 + paso2 + paso3 + paso4 + herramientas
  end

  # Marca en cada herramienta si la cuenta la tiene (true/false) o si no depende (nil).
  def annotate_tools!
    temas_herramientas.each do |herramienta|
      check = TOOL_CHECKS[herramienta['tipo']]
      herramienta['disponible'] = check ? check.call(@inventory) : nil
    end
    @ficha
  end

  private

  def temas = Array(@ficha['temas'])
  def temas_herramientas = Array(@ficha['herramientas'])

  def paso1
    faltas = []
    faltas << gap(1, 'temas') if temas.empty?
    faltas << gap(1, 'modo') if @ficha['modo'].blank?
    faltas
  end

  def paso2
    temas.select { |t| Array(t['frases_cliente']).empty? }.map { |t| gap(2, 'frases_cliente', tema: t['nombre']) }
  end

  def paso3
    temas.select { |t| t['fuente'].blank? && t['si_no_resuelve'].blank? }
         .map { |t| gap(3, 'fuente_o_escalamiento', tema: t['nombre']) }
  end

  # Una sola pregunta si ningún tema la trae: "¿una para todos o una por tema?"
  def paso4
    sin = temas.select { |t| t['etiqueta'].blank? }
    return [] if sin.empty?
    return [gap(4, 'etiquetas')] if sin.size == temas.size

    sin.map { |t| gap(4, 'etiqueta', tema: t['nombre']) }
  end

  def herramientas
    temas_herramientas.select { |h| h['disponible'] == false }
                      .map { |h| gap(3, 'herramienta_no_disponible', tipo: h['tipo'], para: h['para']) }
  end

  def gap(paso, que, **extra)
    { 'paso' => paso, 'que' => que }.merge(extra.compact.stringify_keys)
  end
end
