# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LAS RAMAS QUE LA CUENTA YA ESCRIBIÓ
# ================================================================================
# Para armar un agente nuevo hace falta ver cómo están escritas las ramas de los que
# ya funcionan: qué frases de cliente usan, con qué fuente, qué escalan. Medido sobre
# los 28 agentes del respaldo: 33 ramas escritas, y la mitad de los agentes nuevos
# repiten un tema que ya existe en otro (soporte, comercial, humano).
#
# Se devuelven agrupadas por CÓMO ESTÁN ESCRITAS, no por nombre: dos agentes con una
# rama "soporte" idéntica son una sola entrada que dice en cuáles está; si difieren en
# la fuente o en las frases, son dos entradas, porque elegir una u otra no da lo mismo.
#
# Cada entrada trae también su línea de [ALCANCE POR RAMA] en el agente de donde sale:
# una rama son las dos mitades juntas (ver RouteModal), así que copiarla tiene que
# copiar las dos.
# ================================================================================

class ContactTrackings::TrainingRouteCatalog
  MAX_ENTRIES = 200
  Routes = ContactTrackings::TrainingRoutes
  Structure = ContactTrackings::TrainingStructure
  SCOPE_RE = /ALCANCE|SCOPE/i

  def initialize(account)
    @account = account
  end

  def call
    entradas = {}
    plantillas.each do |template|
      bloques = Structure.parse(template.complementary_prompt)['blocks']
      alcances = scope_lines(bloques)
      routes_in(bloques).each do |rama|
        entrada = entradas[key_for(rama)] ||= base_entry(rama, alcances)
        entrada[:agents] |= [template.name]
      end
    end
    entradas.values.sort_by { |e| [e[:name], e[:description]] }.first(MAX_ENTRIES)
  end

  private

  def plantillas
    @account.tracking_templates.where.not(complementary_prompt: [nil, '']).ordered
  end

  def routes_in(bloques)
    bloques.select { |b| b['type'] == 'routes' }
           .flat_map { |b| b['lines'].to_a }
           .select { |linea| linea['kind'] == 'route' && linea['name'].present? }
  end

  # La misma rama escrita igual es una sola entrada. La etiqueta no entra en la
  # comparación: es de la cuenta donde vive y se elige aparte.
  def key_for(rama)
    rama.values_at('name', 'description', 'source', 'escalation').map(&:to_s)
  end

  def base_entry(rama, alcances)
    { name: rama['name'], tag: rama['tag'].to_s, description: rama['description'].to_s,
      source: rama['source'].to_s, escalation: rama['escalation'].to_s,
      action: rama['action'].to_s, case_type: rama['case_type'].to_s, priority: rama['priority'].to_s,
      scope: alcances[rama['name']].to_s, agents: [] }
  end

  # "nombre: qué atiende" de la sección de alcance, por nombre de rama.
  def scope_lines(bloques)
    seccion = bloques.find { |b| b['type'] == 'section' && b['title'].to_s.match?(SCOPE_RE) }
    return {} if seccion.nil?

    seccion['body'].to_s.lines.each_with_object({}) do |linea, acc|
      nombre, texto = linea.split(':', 2)
      next if texto.blank?

      acc[nombre.to_s.strip.downcase] = texto.strip
    end
  end
end
