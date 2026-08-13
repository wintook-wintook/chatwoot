# ================================================================================
# proyecto@ai_agent_assistant - F7
# ================================================================================
# Servicio: AiAgentAssistant::AutoConversation
# Descripción: Un segundo modelo hace de cliente y conversa solo con el agente
#              durante N turnos.
#
# Para qué sirve de verdad: detectar BUCLES. Un agente puede sonar perfecto en un
# turno suelto y quedarse repitiendo la misma pregunta a partir del tercero — que
# es justo lo que un humano probando a mano no llega a ver, porque prueba uno o
# dos turnos y se cansa.
#
# Cuesta dinero real: dos llamadas por turno. Por eso el tope es duro.
# ================================================================================

class AiAgentAssistant::AutoConversation < Cases::Ai::BaseService
  MAX_TURNS = 8
  DEFAULT_TURNS = 5

  # La personalidad del cliente simulado. En español porque es lo que se le pasa
  # al modelo como instrucción, no una etiqueta de interfaz.
  PERSONAS = {
    'interested' => 'Estás interesado y quieres avanzar. Contestas corto y colaboras.',
    'skeptical' => 'Desconfías. Pides pruebas, precios y condiciones antes de comprometerte.',
    'annoyed' => 'Estás molesto porque ya te escribieron antes. Contestas seco y cortante.',
    'confused' => 'No entiendes bien de qué te hablan. Preguntas cosas fuera de tema.'
  }.freeze

  # Dos respuestas del agente con este parecido o más se consideran la misma.
  LOOP_SIMILARITY = 0.9

  def initialize(template, persona: 'interested', turns: DEFAULT_TURNS)
    super(account: template.account)
    @template = template
    @persona = PERSONAS.key?(persona.to_s) ? persona.to_s : 'interested'
    @turns = turns.to_i.clamp(1, MAX_TURNS)
  end

  def call
    return { 'error' => 'openai_not_configured', 'turns' => [] } if api_key.blank?

    opening = sandbox.opening
    return { 'error' => opening['error'], 'turns' => [] } if opening['error'].present?

    run(opening)
  end

  private

  attr_reader :template, :persona, :turns

  def sandbox
    @sandbox ||= AiAgentAssistant::SandboxService.new(template)
  end

  def run(opening)
    transcript = [{ 'role' => 'agent', 'turn' => 0 }.merge(opening)]
    agent_texts = [opening['text']]

    turns.times { |index| break unless exchange(transcript, agent_texts, index + 1) }

    { 'persona' => persona, 'turns' => transcript,
      'loop_detected' => looping?(agent_texts),
      'tokens_used' => transcript.sum { |entry| entry['tokens_used'].to_i } }
  end

  # Un intercambio: contesta el cliente simulado y luego el agente. Devuelve false
  # cuando ya no tiene sentido seguir (fallo del modelo o bucle detectado).
  def exchange(transcript, agent_texts, turn)
    customer = customer_turn(transcript)
    return false if customer.blank?

    transcript << { 'role' => 'customer', 'text' => customer, 'turn' => turn }
    answer = sandbox.reply(customer, history: history_of(transcript))
    return false if answer['error'].present?

    transcript << { 'role' => 'agent', 'turn' => turn }.merge(answer)
    agent_texts << answer['text']
    !looping?(agent_texts)
  end

  def customer_turn(transcript)
    system = <<~TEXT.strip
      Haces de CLIENTE en una prueba. #{PERSONAS[persona]}
      Responde como respondería una persona real por mensajería: una o dos frases, sin
      comillas, sin explicar que eres una simulación. No hagas de asistente.
    TEXT

    chat(system: system, user: history_of(transcript), temperature: 0.9, max_tokens: 120)
  end

  def history_of(transcript)
    transcript.map { |entry| "#{entry['role'] == 'agent' ? 'Agente' : 'Cliente'}: #{entry['text']}" }
              .join("\n")
  end

  # El bucle que importa no es el texto idéntico —el modelo varía la redacción— sino
  # el agente diciendo lo mismo con otras palabras. Jaccard sobre palabras lo capta.
  def looping?(texts)
    return false if texts.compact.size < 2

    recent = texts.compact.last(2)
    similarity(recent.first, recent.last) >= LOOP_SIMILARITY
  end

  def similarity(one, other)
    a = words(one)
    b = words(other)
    return 0.0 if a.empty? || b.empty?

    (a & b).size.to_f / (a | b).size
  end

  def words(text)
    text.to_s.downcase.gsub(/[^[:alnum:]\s]/, ' ').split.to_set
  end
end
