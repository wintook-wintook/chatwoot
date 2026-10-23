# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LAS SECCIONES QUE LA CUENTA YA ESCRIBIÓ
# ================================================================================
# Hermano de TrainingRouteCatalog, para el otro lado del árbol. TrainingSectionTitles
# ya ofrece NOMBRES de sección ("ROL", "ETIQUETAS"); esto trae las secciones ENTERAS,
# con su contenido, para copiar una de un agente que ya funciona.
#
# La diferencia importa: acertar el nombre es lo fácil. Lo que cuesta es escribir
# adentro —qué dice un [FIDELIDAD] que evita que el agente invente, cómo está escrito
# un [ETIQUETAS] que cierra bien los turnos—, y eso ya está resuelto en los agentes
# que andan. Medido sobre los 28 agentes del respaldo: 275 secciones escritas, con 110
# nombres distintos, así que el mismo nombre suele estar escrito de varias maneras.
#
# Se agrupan por nombre + contenido: dos secciones idénticas son una entrada que dice
# en qué agentes está; el mismo nombre con textos distintos son entradas separadas,
# que es justamente lo que se quiere comparar.
# ================================================================================

class ContactTrackings::TrainingSectionCatalog
  MAX_ENTRIES = 300
  # Una sección de un agente real llega a decenas de líneas; el tope es contra un
  # prompt raro, no contra un agente grande.
  MAX_BODY_CHARS = 6000
  Structure = ContactTrackings::TrainingStructure

  def initialize(account)
    @account = account
  end

  def call
    entradas = {}
    plantillas.each do |template|
      sections_in(template).each do |bloque|
        entrada = entradas[key_for(bloque)] ||= base_entry(bloque)
        entrada[:agents] |= [template.name]
      end
    end
    entradas.values.sort_by { |e| [e[:title], -e[:lines], e[:body]] }.first(MAX_ENTRIES)
  end

  private

  def plantillas
    @account.tracking_templates.where.not(complementary_prompt: [nil, '']).ordered
  end

  def sections_in(template)
    Structure.parse(template.complementary_prompt)['blocks']
             .select { |b| b['type'] == 'section' && b['title'].present? && b['body'].present? }
  end

  def key_for(bloque)
    [bloque['title'].to_s.upcase, bloque['body'].to_s.strip]
  end

  def base_entry(bloque)
    cuerpo = bloque['body'].to_s.strip.truncate(MAX_BODY_CHARS)
    { title: bloque['title'].to_s, body: cuerpo, style: bloque['style'].to_s,
      lines: cuerpo.lines.size, agents: [] }
  end
end
