# frozen_string_literal: true

# ================================================================================
# proyecto@crear_agente_conversando — F3: CÓMO SE LE PIDEN AL MODELO LAS PESTAÑAS
# ================================================================================
# El texto que DraftingChat suma a su PROMPT para que la conversación llene Definición,
# Variables y Datos fijos, y lo que ya hay en ellas para el turno siguiente. Lo que el
# modelo devuelve lo limpia DraftingFields.
# ================================================================================

module ContactTrackings::Assistant::DraftingFieldsPrompt
  # Las llaves del JSON que se suman al contrato de DraftingChat (y al del tool loop).
  CONTRACT_KEYS = '"definicion": {"objetivo": "…", "contexto": "…"} | null, ' \
                  '"variables": [{"nombre", "valores", "libre", "inicial"}] | null, ' \
                  '"datos_fijos": [{"nombre", "tipo", "contenido", "guarda_en"}] | null'

  PROMPT = <<~PROMPT
    ═══ LO QUE LLENAS APARTE: DEFINICIÓN, VARIABLES Y DATOS FIJOS ═══
    Junto a las instrucciones, la persona ve tres pestañas que tú vas llenando. Llénalas desde
    que haya con qué, con lo que la persona dijo o aceptó (nunca datos del negocio inventados):
    1. "definicion": {"objetivo": una frase con lo que el agente tiene que lograr,
       "contexto": quién es el negocio y lo que el agente debe saber SIEMPRE (qué vende, a quién,
       dónde), máximo 800 caracteres}. Lo que se consulta en una fuente no va aquí.
    2. "variables": lo que el agente RECUERDA de cada cliente para decidir después: en qué paso
       va, qué contestó a una pregunta clave, si ya recibió la liga. Cada una:
       {"nombre": "SISTEMA" (mayúsculas, sin espacios), "valores": ["CONTPAQi", "Aspel", "Otro"]
       (las opciones, si son cerradas), "libre": true si guarda lo que el cliente escriba (un
       nombre, un correo), "inicial": el valor con el que arranca o null}. Solo las que sirven
       para decidir algo; si nada depende de recordarlo, no es variable.
    3. "datos_fijos": lo que se escribe UNA vez y el agente usa igual en varias partes: el
       nombre de la empresa, una liga, un mensaje que siempre sale igual, y las preguntas de un
       cuestionario. Cada uno: {"nombre": "EMPRESA", "tipo": "texto" | "liga" | "pregunta" |
       "numero", "contenido": "el texto exacto", "guarda_en": "SISTEMA" (solo una pregunta cuya
       respuesta se recuerda en una variable) | null}. Las preguntas del cuestionario se llaman
       Q1, Q2… en el orden en que se hacen; su "contenido" es la pregunta tal como la leerá el
       cliente.
    - Devuelve cada una COMPLETA cuando cambie, partiendo de la que ya está (la persona pudo
      corregirla a mano: respeta sus cambios); null si en este turno no cambió.
    - En "mensaje" e "instrucciones" se habla de ellas en palabras simples («guardo qué sistema
      usa», «la pregunta 1»), nunca con %NOMBRE% ni nombres en MAYÚSCULAS.
  PROMPT

  module_function

  # Lo que ya está en las pestañas, para el modelo: lo edita, no lo reescribe de memoria.
  # fields: { 'objective', 'ai_context', 'variables', 'datos_fijos' } (texto de cada sección).
  def context_text(fields)
    f = fields.to_h.stringify_keys
    partes = [("Objetivo: #{f['objective']}" if f['objective'].present?),
              ("Contexto: #{f['ai_context']}" if f['ai_context'].present?),
              ("Variables:\n#{f['variables']}" if f['variables'].present?),
              ("Datos fijos:\n#{f['datos_fijos']}" if f['datos_fijos'].present?)].compact
    return nil if partes.empty?

    "DEFINICIÓN, VARIABLES Y DATOS FIJOS HASTA AHORA (como los escribe el motor; tú contéstalos en el JSON):\n\n" \
      "#{partes.join("\n\n")}"
  end
end
