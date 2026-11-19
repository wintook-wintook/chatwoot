# frozen_string_literal: true

# Probador de agentes — lo que el entrenador comprueba él mismo en vez de creerle al modelo
# (proyecto@predefinidas_que_contestan). Lo incluye AgentTester::Trainer, que da @trace, @reply,
# @messages, @template, #arrived_titles y #prompt_text.
module AgentTester::TrainerFacts
  # Títulos iguales aunque la traza los haya recortado.
  TITLE_KEY = 60

  private

  def normalize(text) = I18n.transliterate(text.to_s).downcase.gsub(/[^a-z0-9]+/, ' ').squish

  # nil sin la búsqueda nueva; 'escoger' si estuvo entre las candidatas; 'juntar' si ni eso.
  def stage_for(item)
    return nil if @trace['seleccion'].blank?

    clave = normalize(item).first(TITLE_KEY)
    candidatas = Array(@trace.dig('seleccion', 'candidatas_titulos'))
    candidatas.any? { |t| normalize(t).first(TITLE_KEY) == clave } ? 'escoger' : 'juntar'
  end

  # ¿La indicación que se propone ya está en el Entrenamiento? (7 de cada 10 de sus palabras
  # largas). Pasó: «solo menciona la primera beca» con el PASO 2 ya escrito así.
  def already_written?(text)
    palabras = normalize(text).split.select { |w| w.size > 4 }.uniq
    return false if palabras.size < 4

    prompt = normalize(prompt_text.to_json)
    palabras.count { |w| prompt.include?(w) } >= (palabras.size * 0.7).ceil
  end

  # Lo que la respuesta trae y el agente no vio (KnowledgeBase::DataGuard).
  def invented
    @invented ||= KnowledgeBase::DataGuard.invented(@reply, AgentTester::Seen.new(@template).text(@messages, @trace))
  rescue StandardError
    []
  end

  def arrived?(title)
    clave = normalize(title).first(TITLE_KEY)
    arrived_titles.any? { |t| normalize(t).first(TITLE_KEY) == clave }
  end

  # 2.0: qué hay en cada fuente del agente (lo mismo que lee el agente para saber dónde buscar).
  def source_map
    return [] unless @v2

    Motor2::SourceMap.new(@account).lines(Motor2::Config.new(@template).sources)
  end

  # La fuente que nombró el entrenador, con lo que dice hoy su «¿Qué hay aquí?» (si es de las del agente).
  def where_facts(name)
    entry = Motor2::SourceMap.new(@account).entries(Motor2::Config.new(@template).sources)
                             .find { |e| e[:name].to_s.casecmp?(name.to_s.strip) }
    entry ? { 'source' => entry[:name], 'source_id' => entry[:id], 'about' => entry[:about] } : {}
  end
end
