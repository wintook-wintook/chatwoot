# frozen_string_literal: true

# ================================================================================
# proyecto@arreglar_predefinidas — LOS CANDADOS DE UNA PROPUESTA
# ================================================================================
# Sin IA (bloquean «Aceptar»):
#   size      cada parte ≤ MAX_CHARS («nombre: contenido», lo que recibe el agente)
#   data      ningún dato duro del original falta (Fix::HardData)
#   groups    cada nombre empieza con los prefijos de grupo que usan los agentes
#   names     nombres no repetidos entre las partes ni con otra predefinida de la cuenta
#
# Sin IA, avisa:
#   coverage    frases del original (renglones de COVERAGE_MIN_CHARS o más) cuyas palabras
#               casi no están en las partes: lo que se perdió aunque no fuera un dato duro
#               (un paso de un procedimiento, una condición). Al condensar es normal perder
#               relleno; al dividir, no debería salir nada.
#
# F2 (unir, separar, redacción, contradicción):
#   resolved    bloquea: el dato equivocado no quedó en ninguna parte y el correcto sí
#               (Fix::Resolution). Se puede saltar con force, igual que `data`: el mismo
#               monto puede ser legítimo en otra frase de la misma respuesta.
#   changes     avisa: cuánto cambió cada parte contra su original (Fix::Diff). En
#               redacción y contradicción más de MAX_CHANGE es reescribir de más.
#   pair        avisa (separar temas): la similitud entre las dos tiene que bajar.
#
# Con vectores (avisan, no bloquean: dependen del resto de la base):
#   duplicates  partes casi iguales entre sí, o a otra predefinida de la cuenta (≥ 0.95)
#   search      cada pregunta de prueba encuentra su parte entre las TOP_K que recibiría
#               el agente, buscando en la base real de la cuenta (sin la original, que se
#               reemplaza) más las partes nuevas. Es el candado que dice si el arreglo
#               sirve, sin importar de qué trate.
#
# `corpus`: para el banco de pruebas, que no tiene la base de esas cuentas; por omisión,
# los vectores de la cuenta (knowledge_items).
# ================================================================================

class CannedResponses::Fix::Checks
  MAX_CHARS = KnowledgeBaseResponseService::MAX_ITEM_CHARS
  TOP_K = KnowledgeBaseResponseService::DEFAULTS['max_results']
  DUPLICATE = 0.95
  COVERAGE_MIN_CHARS = 25
  COVERAGE_WORDS = 0.7
  MAX_DROPPED = 10
  COVERAGE_CONDENSE_LOSS = 0.2
  BLOCKING = %w[size data groups names resolved].freeze
  # Lo que se puede aceptar marcando «ya no aplica».
  FORCEABLE = %w[data resolved coverage].freeze
  MAX_CHANGE = 0.15
  # En un texto corto, cambiar 3 palabras ya es 20 %: solo cuenta si además cambiaron más
  # de estas (medido en el banco F2: «Timbres», 133 caracteres, 23 % por corregir el tono).
  MIN_CHANGED_WORDS = 12

  # originals: las predefinidas que la propuesta reemplaza (fuera de la búsqueda y de los
  # nombres ocupados). `original:` sigue sirviendo para una sola.
  def initialize(account, reference_text:, prefixes:, api_key:, original: nil, originals: nil, corpus: nil, # rubocop:disable Metrics/ParameterLists
                 forbidden: [], required: [], baselines: nil, compare_pair: false, measure_changes: false,
                 coverage_blocks: false)
    @account = account
    @originals = Array(originals || original).compact
    @reference = reference_text
    @prefixes = prefixes
    @embedder = CannedResponses::Fix::Embedder.new(api_key)
    @corpus = corpus || method(:account_corpus)
    @forbidden = forbidden
    @required = required
    @baselines = baselines
    @compare_pair = compare_pair
    @measure_changes = measure_changes
    @coverage_blocks = coverage_blocks
  end

  def call(parts, questions, embeddings: true)
    out = { 'size' => size(parts), 'data' => data(parts), 'groups' => groups(parts), 'names' => names(parts),
            'coverage' => coverage(parts) }
    out['resolved'] = resolved(parts) if @forbidden.any? || @required.any?
    out['changes'] = changes(parts) if @baselines && @measure_changes
    out.merge!(vector_checks(parts, questions)) if embeddings
    bloquean = BLOCKING.select { |k| out[k] && !out[k]['ok'] }
    bloquean << 'coverage' if @coverage_blocks && !out['coverage']['ok']
    out.merge('blocking' => bloquean)
  end

  def original_ids = @originals.filter_map(&:id)

  # Para la segunda vuelta de la IA: lo que falló, en frases. Las frases perdidas cuentan
  # siempre al dividir; al condensar, solo si se perdió más de COVERAGE_CONDENSE_LOSS.
  def self.problems(checks, action = 'split')
    out = []
    cobertura = checks['coverage'] || {}
    perdidas = cobertura['dropped_count'].to_i
    tolerable = action == 'condense' ? cobertura['lines'].to_i * COVERAGE_CONDENSE_LOSS : 0
    out << "Estas frases del original no quedaron en ninguna parte; inclúyelas: #{Array(cobertura['dropped']).join(' | ')}" if perdidas > tolerable
    checks.dig('size', 'parts')&.each_with_index do |p, i|
      if p['chars'] > CannedResponses::Fix::Proposer::TARGET_CHARS
        out << "La parte #{i + 1} mide #{p['chars']} caracteres; el máximo es #{CannedResponses::Fix::Proposer::TARGET_CHARS}."
      end
    end
    faltan = Array(checks.dig('data', 'missing')).pluck('text')
    out << "Faltan estos datos, escritos igual: #{faltan.join(' | ')}" if faltan.any?
    Array(checks.dig('groups', 'bad')).each { |i| out << "El nombre de la parte #{i + 1} no empieza con el prefijo obligatorio." }
    out << "Nombres repetidos o ya usados en la cuenta: #{checks.dig('names', 'bad').join(' | ')}" if checks.dig('names', 'bad').present?
    quedan = Array(checks.dig('resolved', 'still_wrong')).pluck('text')
    out << "Todavía aparece el dato equivocado; quítalo: #{quedan.join(' | ')}" if quedan.any?
    sin = Array(checks.dig('resolved', 'missing_right')).pluck('text')
    out << "Falta el dato correcto: #{sin.join(' | ')}" if sin.any?
    out
  end

  private

  def chars(part) = CannedResponse.agent_text(part['short_code'], part['content']).size

  # Con baselines (redacción, separar, resolver) una parte que ya pasaba del tope antes del
  # arreglo no bloquea si no creció: el arreglo no la empeoró (para eso está «pasa del tope»).
  def size(parts)
    medidas = parts.each_with_index.map do |p, i|
      antes = @baselines && @baselines[i]&.size
      { 'chars' => chars(p), 'before' => antes }.compact
    end
    ok = medidas.all? { |m| m['chars'] <= MAX_CHARS || (m['before'] && m['chars'] <= m['before']) }
    { 'ok' => ok, 'max' => MAX_CHARS, 'parts' => medidas }
  end

  # Los datos prohibidos (el equivocado de una contradicción) no cuentan como faltantes.
  def data(parts)
    prohibidas = @forbidden.filter_map { |i| i['key'] }.to_set
    obligatorios = CannedResponses::Fix::HardData.extract(@reference).reject { |i| prohibidas.include?(i['key']) }
    texto = joined(parts)
    faltan = obligatorios.reject { |i| CannedResponses::Fix::HardData.new(texto).present?(i) }
    { 'ok' => faltan.empty?, 'total' => obligatorios.size, 'missing' => faltan }
  end

  # El dato equivocado se busca en el contenido: el nombre no lo cambia el arreglo (en el
  # banco F2, «Folleto MB10» contra «Folleto MB10 VL» quedaba «presente» en un nombre).
  def resolved(parts)
    texto = joined(parts)
    contenido = parts.pluck('content').join("\n\n")
    quedan = @forbidden.select { |i| CannedResponses::Fix::Resolution.present?(i, contenido) }
    faltan = @required.reject { |i| CannedResponses::Fix::Resolution.present?(i, texto) }
    { 'ok' => quedan.empty? && faltan.empty?, 'still_wrong' => quedan, 'missing_right' => faltan }
  end

  def changes(parts)
    medidas = parts.each_with_index.map do |p, i|
      antes = @baselines[i]
      next nil unless antes

      despues = CannedResponse.agent_text(p['short_code'], p['content'])
      { 'ratio' => CannedResponses::Fix::Diff.ratio(antes, despues).round(3),
        'words' => CannedResponses::Fix::Diff.changed_words(antes, despues) }
    end
    de_mas = medidas.compact.select { |m| m['ratio'] > MAX_CHANGE && m['words'] > MIN_CHANGED_WORDS }
    { 'ok' => de_mas.empty?, 'max' => MAX_CHANGE, 'parts' => medidas }
  end

  def joined(parts) = parts.map { |p| CannedResponse.agent_text(p['short_code'], p['content']) }.join("\n\n")

  def coverage(parts)
    palabras = words(parts.map { |p| "#{p['short_code']} #{p['content']}" }.join(' ')).to_set
    renglones = @reference.split(/\n+|(?<=[.!?])\s+/).map(&:strip).select { |l| l.size >= COVERAGE_MIN_CHARS }
    perdidos = renglones.reject do |linea|
      propias = words(linea)
      propias.empty? || propias.count { |w| palabras.include?(w) } >= COVERAGE_WORDS * propias.size
    end
    { 'ok' => perdidos.empty?, 'lines' => renglones.size, 'dropped' => perdidos.first(MAX_DROPPED).map { |l| l.truncate(160) },
      'dropped_count' => perdidos.size }
  end

  def words(texto) = ActiveSupport::Inflector.transliterate(texto.to_s.downcase).scan(/[a-z0-9]{4,}/).uniq

  def groups(parts)
    malas = parts.each_index.reject do |i|
      nombre = key(parts[i]['short_code'])
      @prefixes.all? { |pre| nombre.start_with?(key(pre)) }
    end
    { 'ok' => malas.empty?, 'prefixes' => @prefixes, 'bad' => malas }
  end

  def names(parts)
    nombres = parts.map { |p| p['short_code'].to_s.strip }
    repetidos = nombres.select { |n| nombres.count { |m| key(m) == key(n) } > 1 }.uniq
    ocupados = @account.canned_responses.where.not(id: original_ids)
                       .where('lower(short_code) IN (?)', nombres.map(&:downcase)).pluck(:short_code)
    malos = (repetidos + ocupados).uniq
    { 'ok' => malos.empty?, 'bad' => malos }
  end

  # ── con vectores ────────────────────────────────────────────────────────────
  def vector_checks(parts, questions)
    textos = parts.map { |p| CannedResponse.agent_text(p['short_code'], p['content']) }
    antes = @compare_pair ? Array(@baselines).first(2) : []
    vectores = @embedder.call(textos + questions.pluck('text') + antes)
    return { 'duplicates' => { 'ok' => true, 'skipped' => true }, 'search' => { 'ok' => true, 'skipped' => true } } if vectores.nil?

    de_partes = vectores.first(parts.size)
    de_preguntas = vectores[parts.size, questions.size]
    out = { 'duplicates' => duplicates(parts, de_partes), 'search' => search(parts, de_partes, questions, de_preguntas) }
    out['pair'] = pair(vectores.last(2), de_partes) if @compare_pair && antes.size == 2 && de_partes.size >= 2
    out
  end

  # Separar temas: las dos tienen que parecerse menos que antes.
  def pair(antes, despues)
    previa = CannedResponses::Fix::Embedder.cosine(*antes)
    nueva = CannedResponses::Fix::Embedder.cosine(despues[0], despues[1])
    { 'ok' => nueva < previa - 0.02, 'before' => previa.round(3), 'after' => nueva.round(3) }
  end

  def duplicates(_parts, vectores)
    entre = vectores.each_index.to_a.combination(2).filter_map do |i, j|
      sim = CannedResponses::Fix::Embedder.cosine(vectores[i], vectores[j])
      { 'a' => i, 'b' => j, 'similarity' => sim.round(3) } if sim >= DUPLICATE
    end
    con_base = vectores.each_with_index.filter_map do |v, i|
      nombre, sim = @corpus.call(v, 1).first
      { 'part' => i, 'short_code' => nombre, 'similarity' => sim.round(3) } if sim && sim >= DUPLICATE
    end
    { 'ok' => entre.empty? && con_base.empty?, 'pairs' => entre, 'existing' => con_base }
  end

  def search(parts, vectores_partes, questions, vectores_preguntas)
    resultados = questions.zip(vectores_preguntas).map do |q, v|
      propias = vectores_partes.each_with_index.map { |vp, i| [parts[i]['short_code'], CannedResponses::Fix::Embedder.cosine(v, vp), i] }
      ajenas = @corpus.call(v, TOP_K).map { |nombre, sim| [nombre, sim, nil] }
      top = (propias + ajenas).sort_by { |_, sim, _| -sim }.first(TOP_K)
      { 'text' => q['text'], 'part' => q['part'], 'found' => top.any? { |_, _, i| i == q['part'] },
        'top' => top.map { |nombre, sim, _| { 'short_code' => nombre, 'similarity' => sim.round(3) } } }
    end
    { 'ok' => resultados.all? { |r| r['found'] }, 'total' => resultados.size,
      'found' => resultados.count { |r| r['found'] }, 'questions' => resultados }
  end

  # [[nombre, similitud]] de la base real, sin la original (la propuesta la reemplaza).
  def account_corpus(vector, limit)
    KnowledgeItem.where(account_id: @account.id, source_type: 'canned_response')
                 .where.not(source_id: original_ids).where.not(embedding: nil)
                 .nearest_neighbors(:embedding, vector, distance: 'cosine').limit(limit)
                 .map { |item| [item.title, 1 - item.neighbor_distance] }
  end

  def key(texto) = ActiveSupport::Inflector.transliterate(texto.to_s).downcase.strip
end
