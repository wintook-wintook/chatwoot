# frozen_string_literal: true

# Probador de agentes — lo que se le dice al usuario por cada causa del entrenador. Nada se aplica
# aquí: el usuario corrige el prompt o la fuente (en el 2.0, con «Aplicar»).
class AgentTester::Verdict
  def initialize(template, user, cause)
    @template = template
    @user = user
    @cause = cause
    @v2 = Motor2.on?(template)
  end

  def message(trainer)
    case @cause['kind']
    when 'prompt' then prompt
    when 'content' then content
    when 'search' then search
    when 'category' then category
    when 'where' then where
    when 'model' then model
    else engine(trainer)
    end
  end

  private

  def prompt
    where = @cause['where'].presence || @cause['field'].presence || 'el prompt'
    text = @cause['text'].presence || @cause['replace']
    base = { kind: 'prompt', where: where, suggestion: text, engine: @v2 ? '2' : '1', already: @cause['already'] == true }
    return base.merge(text: already_text) if @cause['already']

    if @v2
      base.merge(cause: @cause.slice('field', 'find', 'replace', 'label', 'value', 'summary').merge('replace' => text),
                 text: "Es del prompt: falta indicarle esto en «#{where}». Pulsa «Aplicar» y pruébalo de nuevo.#{wizard_hint}")
    else
      base.merge(text: "Es del prompt: agrega esto en «#{where}» de su Entrenamiento y pruébalo de nuevo.")
    end
  end

  # Buscó en la fuente equivocada: se propone cómo debe decir el «¿Qué hay aquí?» de la fuente donde
  # sí estaba (Bases de conocimiento). Con «Cambiarlo» se guarda ahí mismo.
  def where
    text = @cause['text'].to_s.squish.first(300)
    { kind: 'where', source: @cause['source'], source_id: @cause['source_id'], before: @cause['about'], suggestion: text,
      can_fix: @cause['source_id'].present? && text.present?,
      text: "Es de dónde busca: «#{@cause['source']}» sí tenía el dato, pero lo que dice de ella («¿Qué hay aquí?») no lo deja " \
            'ver, y el agente buscó en otra. Propuesta para su «¿Qué hay aquí?»:' }
  end

  # Agente de una función (Atención a prospectos…): se edita con su asistente, no con la ficha 2.0.
  # Lo que aplica el entrenador cae en el paso «Indicaciones» (motor2['instructions']).
  def wizard_hint
    title = @template.try(:function_title)
    return '' unless title

    " Queda en el paso «Indicaciones» del asistente de «#{title}» (Agentes listos), donde puedes revisarlo."
  end

  # La indicación que propondría ya está escrita: agregarla otra vez no cambia nada (pasó con «solo
  # menciona la primera beca», que ya era el PASO 2). El modelo no la siguió.
  def already_text
    'Eso ya está escrito en las instrucciones del agente: el modelo no lo siguió. Revisa que esa parte no choque ' \
      'con otra indicación; si está clara y aun así falla, prueba con un modelo mayor.'
  end

  def content
    canned = canned_for(@cause['item'])
    { kind: 'content', source: @cause['source'], item: @cause['item'], found: @cause['found'], should: @cause['should'],
      canned_id: canned&.id, can_fix: canned.present?,
      text: if @cause['found'].blank?
              "Es del contenido: tu fuente «#{@cause['source']}» no tiene ese dato. Agrégalo y pruébalo de nuevo."
            else
              "Es del contenido: el agente contestó con lo que dice «#{@cause['source']}». Corrígelo ahí y pruébalo de nuevo."
            end }
  end

  # El dato SÍ está en una fuente, pero la búsqueda no la trajo con lo que escribió el cliente: otro
  # saludo u otras palabras y entra o no (cuenta 1128, 17/11/2026: «Hola» sí, «Hola buenos días» no).
  #
  # proyecto@predefinidas_que_contestan: con la búsqueda nueva se sabe en qué paso se perdió
  # (stage): «juntar» = ni siquiera estuvo entre las candidatas (el nombre o la primera línea no
  # dicen cómo lo pregunta el cliente); «escoger» = estuvo y la IA no la escogió (su nombre o su
  # categoría la confunden).
  def search
    canned = canned_for(@cause['item'])
    arrived = Array(@cause['arrived']).compact_blank.first(3)
    llegaron = arrived.map { |a| "«#{a}»" }.join(', ').presence || 'otras'
    { kind: 'search', item: @cause['item'], arrived: arrived, add: @cause['text'], canned_id: canned&.id, can_fix: canned.present?,
      stage: @cause['stage'], canned_kind: canned&.kind,
      text: search_text(llegaron) }
  end

  def search_text(llegaron)
    case @cause['stage']
    when 'escoger'
      "Es de la búsqueda: «#{@cause['item']}» sí tiene el dato y estuvo entre las candidatas, pero no se escogió " \
      "(llegaron #{llegaron}). Revisa que su nombre diga de qué trata y que su categoría sea la correcta."
    when 'juntar'
      "Es de la búsqueda: «#{@cause['item']}» sí tiene el dato, pero ni siquiera estuvo entre las candidatas. Ponle un " \
      'nombre que diga de qué trata y agrega al inicio cómo lo pregunta el cliente; guárdala y pruébalo de nuevo.'
    else
      "Es de la búsqueda: «#{@cause['item']}» sí tiene el dato, pero con lo que escribió el cliente no llegó " \
      "(llegaron #{llegaron}). Agrega al inicio de esa respuesta cómo lo pregunta el cliente, guárdala y pruébalo de nuevo."
    end
  end

  KIND_NAMES = { 'general' => 'General', 'ficha' => 'Ficha', 'objecion' => 'Objeción' }.freeze

  # Llegó una respuesta de otro sujeto (o una objeción usada como dato): su categoría está mal.
  def category
    canned = canned_for(@cause['item'])
    destino = @cause['should_kind'].to_s.presence_in(CannedResponse::KINDS) || 'ficha'
    { kind: 'category', item: @cause['item'], canned_id: canned&.id, can_fix: canned.present?, current_kind: canned&.kind,
      should_kind: destino, why: @cause['why'],
      text: "Es de la categoría: «#{@cause['item']}» está como «#{KIND_NAMES[canned&.kind] || 'General'}» y debe ser " \
            "«#{KIND_NAMES[destino]}» (#{@cause['why']}). Cámbiala y pruébalo de nuevo." }
  end

  # La predefinida del fragmento: por su nombre exacto o, si la traza lo recortó, por su principio.
  def canned_for(item)
    nombre = item.to_s.sub(/(\.\.\.|…)\z/, '').strip
    return nil if nombre.blank?

    respuestas = @template.account.canned_responses
    respuestas.find_by(short_code: nombre) ||
      respuestas.where('short_code ILIKE ?', "#{ActiveRecord::Base.sanitize_sql_like(nombre)}%").first ||
      respuestas.find_by(short_code: nombre.split(':').first.to_s.strip)
  end

  def model
    where = @v2 ? 'Ajustes de Dali › Modelo' : 'Ajustes › Integraciones › Bot de seguimientos › Modelo de IA (de su bandeja)'
    { kind: 'model', why: @cause['why'], where: where,
      text: "Es del modelo: la indicación y el dato estaban, pero no los siguió (#{@cause['why']}). Prueba con un modelo " \
            "mayor en #{where}; si con ese sale bien, déjalo así." }
  end

  def engine(trainer)
    report = Motor2::Reporter.new(@template, @user).call(kind: @cause['type'] == 'ignored' ? 'ignored' : 'missing_skill',
                                                         turns: trainer.messages, reply: trainer.reply,
                                                         expected: trainer.feedback, diagnosis: @cause['what'],
                                                         trace: trainer.trace)
    { kind: 'engine', report_id: report.id, what: @cause['what'],
      text: "Es del motor (#{@cause['what']}). No es algo que tú puedas corregir: ya quedó registrado y el equipo de " \
            'Kontrolya lo revisa. Te avisamos cuando quede.' }
  end
end
