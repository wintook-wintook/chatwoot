# frozen_string_literal: true

# ================================================================================
# proyecto@crear_agente_conversando — F4: EXPORTAR LAS INSTRUCCIONES DEL AGENTE
# ================================================================================
# Plan: docs/creacion_conversacional_agentes_plan.md §8. Un .md para pegar en ChatGPT,
# Claude u otra IA, que se entienda solo:
#
#   # Instrucciones del agente: Kontrolya demos
#   > aviso: qué solo funciona dentro del sistema (D5: las directivas van tal cual)
#   ## Objetivo · ## Contexto
#   ## Lo que recuerda de cada cliente      ← [VARIABLES] explicadas en palabras
#   ## Entrenamiento                         ← con los %DATOS FIJOS% ya sustituidos
#
# Sin Entrenamiento todavía (se está armando conversando), en su lugar van las
# instrucciones iniciales y los Datos fijos en una lista: no hay texto donde sustituirlos.
#
# La sustitución es la del motor (PromptConstants.expand): el archivo dice exactamente lo
# que el modelo del sistema lee. Sin IA.
# ================================================================================

class ContactTrackings::Assistant::AgentExport
  Definition = ContactTrackings::ConversationVariables::Definition

  NOTICE = <<~TXT.strip
    > Este archivo salió del sistema el %<fecha>s. Para usarlo en ChatGPT, Claude u otra IA, pégalo como sus instrucciones.
    >
    > **Lo que solo funciona dentro del sistema:** las líneas que empiezan con `@` (las rutas `@ruta(…)` y acciones
    > como `@crear_ticket` o `@agendar_calendar`) y lo que va entre `{{ }}` (consultas a las hojas, documentos y fuentes
    > de la cuenta). Fuera del sistema no hacen nada: léelas como «aquí el agente consulta…» o «aquí abre un caso…», y
    > dale a la otra IA esa información de otra forma. Lo que el agente recuerda de cada cliente (las Variables) lo
    > guarda el sistema en cada conversación.
  TXT

  # fields: { 'objective', 'ai_context', 'variables', 'datos_fijos' } (DraftingFields).
  def initialize(name:, draft: nil, instructions: nil, fields: {})
    @name = name.to_s.strip.presence || 'agente'
    @draft = draft.to_s.strip
    @instructions = instructions.to_s.strip
    @fields = fields.to_h.stringify_keys
  end

  # { content:, filename: }
  def call
    partes = [title, format(NOTICE, fecha: Time.zone.today.strftime('%d/%m/%Y')), *body].compact
    { content: "#{partes.join("\n\n")}\n", filename: "instrucciones_#{slug}.md" }
  end

  private

  def title = "# Instrucciones del agente: #{@name}"

  def body
    [section('Objetivo', @fields['objective']), section('Contexto', @fields['ai_context']), remembers,
     *(@draft.present? ? [training] : [constants, initial_instructions])]
  end

  def section(titulo, texto)
    texto.to_s.strip.present? ? "## #{titulo}\n\n#{texto.to_s.strip}" : nil
  end

  # Las del Entrenamiento si hay; si no, las de la conversación.
  def remembers
    definicion = Definition.parse(@draft.presence || "[VARIABLES]\n#{@fields['variables']}")
    return nil if definicion.blank?

    lineas = definicion.variables.map { |clave, v| "- **#{v[:name]}**: #{values_text(v)}#{starts(definicion, clave, v)}" }
    "## Lo que recuerda de cada cliente\n\n#{lineas.join("\n")}"
  end

  def values_text(variable)
    opciones = variable[:options]
    libre = 'lo que escriba el cliente'
    return libre if opciones.empty?

    texto = opciones.size == 1 ? opciones.first : "#{opciones[0..-2].join(', ')} o #{opciones.last}"
    variable[:free] ? "#{texto}, o #{libre}" : "uno de #{texto}"
  end

  def starts(definicion, clave, variable)
    inicial = definicion.initial[clave].to_s
    inicial.present? && variable[:options].any? ? ". Empieza en #{inicial}." : ''
  end

  def training
    "## Entrenamiento\n\n#{ContactTrackings::PromptConstants.expand(@draft).strip}"
  end

  def constants
    datos = ContactTrackings::PromptConstants.parse("[DATOS FIJOS]\n#{@fields['datos_fijos']}")
    return nil if datos.empty?

    lineas = datos.values.map do |d|
      guarda = d[:saves_to] ? " (la respuesta se recuerda en #{d[:saves_to]})" : ''
      "- **#{d[:name]}**#{" — #{d[:type]}" unless d[:type] == 'texto'}: #{d[:value]}#{guarda}"
    end
    "## Datos fijos y preguntas\n\n#{lineas.join("\n")}"
  end

  # Las instrucciones iniciales traen su propio título: se baja un nivel todo.
  def initial_instructions
    return nil if @instructions.blank?

    texto = @instructions.sub(/\A#[^#\n][^\n]*\n+/, '').gsub(/^(#+) /) { "#{::Regexp.last_match(1)}# " }
    "## Instrucciones iniciales\n\n#{texto.strip}"
  end

  def slug
    I18n.transliterate(@name).downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\A_+|_+\z/, '').first(40).presence || 'agente'
  end
end
