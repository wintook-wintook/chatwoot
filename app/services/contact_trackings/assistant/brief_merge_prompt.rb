# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LO QUE SE LE PIDE AL MODELO AL JUNTAR (ver BriefMerger)
# ================================================================================
# Aparte de BriefMerger solo por largo: el texto de las instrucciones es la mitad de la
# clase y se lee mejor solo.
# ================================================================================

module ContactTrackings::Assistant::BriefMergePrompt
  PROMPT = <<~PROMPT.freeze
    Juntas puntos sacados de distintas partes de UN MISMO encargo: el documento donde
    alguien describe cómo quiere a su agente de IA de atención por chat. Te llega solo
    una parte de la ficha; devuelve SOLO esas mismas categorías, con esta forma:

    #{ContactTrackings::Assistant::BriefFicha::SHAPE}
    Cada punto de la entrada trae "ids". En la salida, cada punto lleva en "ids" TODOS
    los ids de entrada que junta. Un punto de texto es {"texto": "…", "ids": [...]};
    identidad/objetivo/modo son {"texto": "…", "ids": [...]} (uno solo, o null); cada
    objeto (tema, herramienta, conocimiento, contradicción) lleva además su "ids".

    ═══ REGLAS ═══
    1. Une lo que dice lo mismo aunque esté escrito distinto: un punto, con todos sus ids.
    2. Temas: el mismo tema del cliente con distinto nombre es UNO; junta sus frases.
    3. Si dos puntos se contradicen (uno permite lo que otro prohíbe, dos plazos
       distintos), NO elijas: anotalo en "contradicciones" con lo que dice cada uno y
       los ids de ambos.
    4. No inventes nada que no esté en la entrada.
    5. Una prohibición sin gemela queda como está: no la borres por parecerte obvia.
    6. Cada punto es UNA idea corta, en una línea.
    7. "modo": si una parte dice que contesta y otra que deriva siempre, es una
       contradicción.
    8. La salida tiene que ser BASTANTE más corta que la entrada: es una ficha para
       escribir un agente, no un índice del documento. Junta con decisión lo parecido
       (variantes de un mismo procedimiento, ejemplos de una misma regla) y resume
       "conocimiento" en pocas líneas por tema.

    Contesta SOLO el JSON.
  PROMPT

  TIGHTEN = <<~TXT
    ⚠ Esta parte de la ficha es demasiado larga para usarla. Apriétala: une con más
    decisión los puntos parecidos y acorta textos, sin perder ninguna prohibición y sin
    inventar.
  TXT
end
