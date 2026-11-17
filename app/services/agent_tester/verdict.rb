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
    when 'model' then model
    else engine(trainer)
    end
  end

  private

  def prompt
    where = @cause['where'].presence || @cause['field'].presence || 'el prompt'
    text = @cause['text'].presence || @cause['replace']
    base = { kind: 'prompt', where: where, suggestion: text, engine: @v2 ? '2' : '1' }
    if @v2
      base.merge(cause: @cause.slice('field', 'find', 'replace', 'label', 'value', 'summary').merge('replace' => text),
                 text: "Es del prompt: falta indicarle esto en «#{where}». Pulsa «Aplicar» y pruébalo de nuevo.")
    else
      base.merge(text: "Es del prompt: agrega esto en «#{where}» de su Entrenamiento y pruébalo de nuevo.")
    end
  end

  def content
    canned = @template.account.canned_responses.find_by(short_code: @cause['item'].to_s.split(':').first.to_s.strip)
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
  def search
    canned = @template.account.canned_responses.find_by(short_code: @cause['item'].to_s.split(':').first.to_s.strip)
    arrived = Array(@cause['arrived']).compact_blank.first(3)
    { kind: 'search', item: @cause['item'], arrived: arrived, add: @cause['text'], canned_id: canned&.id, can_fix: canned.present?,
      text: "Es de la búsqueda: «#{@cause['item']}» sí tiene el dato, pero con lo que escribió el cliente no llegó " \
            "(llegaron #{arrived.map { |a| "«#{a}»" }.join(', ').presence || 'otras'}). Agrega al inicio de esa respuesta " \
            'cómo lo pregunta el cliente, guárdala y pruébalo de nuevo.' }
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
