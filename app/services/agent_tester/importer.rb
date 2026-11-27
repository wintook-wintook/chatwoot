# frozen_string_literal: true

# Probador de agentes — un lote desde preguntas que ya existen, para medir sin escribirlas a mano:
#
#   from_text  lo que se pega de una hoja (Excel o Google Sheets copia las celdas separadas por
#              tabulador; también se acepta «;»). Una fila por prueba:
#                mensajes del cliente | lo que se espera | variables (opcional)
#              Varios mensajes en la misma celda, separados por «|» («Hola | ¿cuánto cuesta?»).
#              Variables: «CARRERA=Licenciatura en Derecho; PLAN=Básico».
#              Una primera fila de títulos («pregunta», «esperado»…) se salta.
#   from_pila  la pila vieja del agente (TrackingTestCase: «Pruebas y diagrama» del 1.0).
#
# → { batch:, created:, skipped: [{ line:, reason: }] }
class AgentTester::Importer
  MAX_ROWS = 500
  HEADER_RE = /\A\s*(pregunta|mensaje|cliente|preguntas|mensajes)\b/i

  def initialize(template, user:)
    @template = template
    @account = template.account
    @user = user
  end

  def from_text(text, name: nil)
    filas = rows(text)
    batch = new_batch(name.presence || default_name)
    skipped = []
    created = filas.count do |linea, i|
      motivo = add_row(batch, linea)
      skipped << { line: i + 1, reason: motivo } if motivo
      motivo.nil?
    end
    { batch: batch, created: created, skipped: skipped }
  end

  def from_pila(name: nil)
    pila = TrackingTestCase.where(tracking_template_id: @template.id).ordered
    batch = new_batch(name.presence || "Pila del agente · #{@template.name}")
    created = pila.count do |prueba|
      esperado = prueba.check_text.presence || prueba.rule.presence ||
                 ("Que conteste lo de la ruta «#{prueba.expected_route}»" if prueba.expected_route.present?)
      create_case(batch, Array(prueba.customer_turns), esperado.to_s, {})
    end
    { batch: batch, created: created, skipped: [] }
  end

  private

  # [[renglón, índice], …] sin vacíos ni la fila de títulos.
  def rows(text)
    filas = text.to_s.lines.map(&:chomp).each_with_index.reject { |l, _| l.strip.empty? }.first(MAX_ROWS)
    filas.first && filas.first[0].match?(HEADER_RE) ? filas.drop(1) : filas
  end

  def default_name
    dia = AgentTester::AutoCase.today(@template)
    "Importadas · #{@template.name} · #{dia.day} #{AgentTester::AutoCase::MONTHS[dia.month - 1]}"
  end

  def new_batch(name)
    AgentTestBatch.create!(account: @account, tracking_template: @template, created_by: @user, name: name.first(120))
  end

  # nil si entró; si no, el motivo.
  def add_row(batch, linea)
    celdas = linea.include?("\t") ? linea.split("\t") : linea.split(';', 3)
    mensajes = celdas[0].to_s.split('|').map(&:strip).compact_blank
    esperado = celdas[1].to_s.strip
    return 'sin mensaje del cliente' if mensajes.empty?
    return 'sin lo que se espera' if esperado.empty?

    create_case(batch, mensajes, esperado, variables(celdas[2])) ? nil : 'no se pudo guardar'
  end

  def create_case(batch, mensajes, esperado, variables)
    batch.cases.create(account: @account, origin: 'import', name: esperado.first(120).presence || mensajes.first.first(120),
                       messages: mensajes.map { |m| m.first(1000) }.first(AgentTestCase::MAX_MESSAGES),
                       expected: esperado.first(2000), variables: variables).persisted?
  end

  # «CARRERA=Licenciatura en Derecho; PLAN=Básico» → { 'CARRERA' => 'Licenciatura en Derecho', … }
  def variables(texto)
    texto.to_s.split(/[;,]\s*(?=[[:alpha:]_]+\s*=)/).filter_map do |par|
      nombre, valor = par.split('=', 2).map { |v| v.to_s.strip }
      [ContactTrackings::ConversationVariables.key(nombre), valor] if nombre.present? && valor.present?
    end.to_h
  end
end
