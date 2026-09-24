# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — OPTIMIZAR UN ENTRENAMIENTO (fase E de PROMPT STUDIO, §29)
# ================================================================================
# El modelo busca reglas redundantes, contradicciones y texto que se puede simplificar,
# y propone un Entrenamiento. La propuesta NUNCA se aplica sola: se muestra con su diff.
#
# LO QUE LA PROPUESTA NO PUEDE HACER, y se controla sin IA:
#   · cambiar el ruteo — las líneas @ruta y @ruta_por_defecto son comportamiento, no
#     redacción. Si las toca, esas piezas vuelven a como estaban (DraftPieces.restore).
#   · borrar secciones — "menos redundancia, MISMO comportamiento" (§19). Si quita una,
#     vuelve.
#   · dejarlo peor — si la propuesta tiene más bloqueantes que el original, se descarta
#     y quedan solo los hallazgos.
# Lo que se restauró se informa: una propuesta que tuvo que corregirse es un dato.
#
# ⚠ Y LAS REGLAS QUE SE PIERDEN (LostRules): medido sobre el v6.11, la propuesta pasó
# los tres controles y había borrado prohibiciones y ejemplos llamándolos redundantes.
# Cada regla que desaparece se busca en la propuesta; las que no aparecen en ningún
# lado se devuelven en `lost_rules`, para verlas antes de decidir.
# ================================================================================

class ContactTrackings::Assistant::Optimizer
  KINDS = %w[redundante contradiccion simplificable sobrante].freeze
  MAX_FINDINGS = 12

  def initialize(account, draft:, inbox: nil, progress: nil)
    @account = account
    @draft = draft.to_s
    @chat = ContactTrackings::Assistant::OpenaiChat.new(account: account, inbox: inbox)
    @progress = progress
  end

  def call
    return { error: :no_api_key } if @chat.api_key.blank?

    @progress&.call(:optimizing)
    reply = @chat.call([{ role: 'system', content: prompt }])
    return { error: :unavailable } unless reply.is_a?(Hash)

    { findings: findings(reply), summary: reply['resumen'].to_s.squish.truncate(300).presence }
      .merge(proposal(reply['entrenamiento'].to_s))
  end

  private

  def findings(reply)
    Array(reply['hallazgos']).first(MAX_FINDINGS).filter_map do |item|
      next unless item.is_a?(Hash) && KINDS.include?(item['tipo'].to_s)

      { kind: item['tipo'], where: item['donde'].to_s.squish.truncate(80),
        detail: item['detalle'].to_s.squish.truncate(300) }
    end
  end

  def proposal(texto)
    return { proposed_draft: nil, discarded: :empty } if texto.blank? || texto == @draft

    restauradas = protected_changes(texto)
    propuesta = ContactTrackings::Assistant::DraftPieces.restore(theirs: texto, mine: @draft,
                                                                 keys: restauradas.map(&:slug))
    return { proposed_draft: nil, discarded: :worse } if worse?(propuesta)

    perdidas = ContactTrackings::Assistant::LostRules.new(@draft, propuesta).call
    { proposed_draft: propuesta, restored: restauradas.map(&:key), lost_rules: perdidas,
      safe_draft: safe_draft(propuesta, perdidas), stats: stats(propuesta) }
  end

  # La propuesta con las secciones que perdían reglas devueltas a como estaban: se
  # queda lo optimizado que no quita nada. nil si no perdía ninguna, o si sin esas
  # secciones no queda nada que aplicar.
  def safe_draft(propuesta, perdidas)
    return nil if perdidas.empty?

    secciones = perdidas.pluck(:section).uniq
    segura = ContactTrackings::Assistant::DraftPieces.restore(theirs: propuesta, mine: @draft, keys: secciones)
    segura == @draft ? nil : segura
  end

  def stats(propuesta)
    { chars_before: @draft.size, chars_after: propuesta.size,
      lines_before: @draft.lines.size, lines_after: propuesta.lines.size }
  end

  # Ruteo y secciones borradas: lo que optimizar no tiene permitido tocar.
  def protected_changes(texto)
    ContactTrackings::Assistant::DraftDiff.new(@draft, texto).changes.select do |cambio|
      cambio.route || cambio.key == ContactTrackings::Assistant::DraftDiff::DEFAULT_KEY || cambio.kind == :removed
    end
  end

  def worse?(propuesta)
    blocking(propuesta) > blocking(@draft)
  end

  def blocking(texto)
    ContactTrackings::Assistant::ValidatorService.new(texto, account: @account).call[:blocking].size
  end

  def prompt
    <<~PROMPT
      Revisas el Entrenamiento de un agente de atención al cliente para dejarlo más claro, SIN cambiar lo que hace.

      Busca:
        redundante     reglas que dicen lo mismo con otras palabras, o repetidas en varias secciones
        contradiccion  reglas que se contradicen entre sí
        simplificable  reglas demasiado largas o específicas que se pueden decir en menos
        sobrante       etiquetas mencionadas que ninguna rama usa, secciones vacías, ejemplos repetidos

      Y propón el Entrenamiento optimizado, con estas reglas duras:
        · Las líneas que empiezan con @ruta( y @ruta_por_defecto van EXACTAMENTE igual, carácter por carácter.
        · No borres secciones: puedes acortar su texto, no quitarlas.
        · No agregues reglas nuevas ni cambies qué se permite o se prohíbe: solo dilo con menos redundancia.
        · NUNCA borres una regla que prohíbe u obliga (NUNCA, PROHIBIDO, SIEMPRE, SOLO, NO…) ni un ejemplo,
          aunque te parezca redundante. Si está repetida, reportala como hallazgo y déjala. Decir "ya está
          en otra sección" solo vale si esa otra sección dice LO MISMO: se va a verificar regla por regla.
        · Una contradicción NO la resuelvas eligiendo un lado: déjala como está y reportala.
        · Mismo idioma, mismos rótulos de sección.
      Si no hay nada que mejorar, devuelve el mismo texto y ningún hallazgo.

      Responde SOLO un JSON:
      {"hallazgos": [{"tipo": "redundante|contradiccion|simplificable|sobrante", "donde": "[SECCIÓN] o @ruta(nombre)", "detalle": "qué y por qué, en una frase"}],
       "resumen": "una frase con lo que cambiaría",
       "entrenamiento": "el Entrenamiento completo optimizado"}

      Escribe el detalle y el resumen en #{ContactTrackings::Assistant::Language.name_for}.

      ENTRENAMIENTO:
      <<<ENTRENAMIENTO
      #{@draft}
      ENTRENAMIENTO>>>
    PROMPT
  end
end
