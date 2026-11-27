# frozen_string_literal: true

# Motor 2.0 — revisiones de «Atención a clientes» (Motor2::Skills::Areas) antes de mandar el mensaje
# (las corre Motor2::QuestionGuard#guard_turn):
#   - dice que ya levantó el caso, registró, agendó o lo pasó sin haber llamado la herramienta: se le
#     pide una vez que lo haga o no lo diga y, si insiste, se quitan esas frases;
#   - ya levantó el caso o registró lo que pidió: se quita «¿quieres que te pase con alguien?»;
#   - Comercial (información): lo que afirma debe estar en lo que trajeron las fuentes (Motor2::EvidenceCheck,
#     «fail closed»); si no, se reescribe con lo confirmado y diciendo que lo demás no se puede confirmar;
#   - «Atención a prospectos» también: dice que ya agendó la cita sin haberla agendado → se reescribe;
#   - todos: dice «te mando la foto / el catálogo» y no va ningún archivo → se le pide que lo mande con
#     enviar_archivo o que no lo diga; si insiste, se quita esa frase.
# Lo incluye Motor2::Runner (usa @mode, @decision, @trace, #run, #clean, #unsourced? y #find_skill).
module Motor2::AreaChecks
  private

  # «Atención a clientes»: dice que ya levantó, registró, agendó o lo pasó sin haber llamado la herramienta.
  # Solo en pasado («agendé la cita»): «¿quieres que te agende la cita?» no es decir que ya lo hizo.
  CLAIMED = /(levanté|registré|agendé|creé)\s+(tu|su|el|la|una?)\b|tu\s+folio|n[uú]mero\s+de\s+(caso|folio)|
             ya\s+(qued[oó]|est[aá])\s+(registrad|levantad|agendad)|te\s+(paso|pasé|canalicé)\s+con/xi
  ACTION_TOOLS = %w[crear_caso registrar_gestion canalizar pasar_a_humano agendar_cita mover_cita cancelar_cita estado_caso
                    le_interesa confirmar_asistencia guardar_respuesta cotizar agregar_a_cuenta quitar_de_cuenta ver_cuenta].freeze
  # «Vendedor de campaña»: dice que ya confirmó su lugar, lo agendó o lo pasó sin hacerlo.
  CAMPAIGN_CLAIMED = /(confirm[eé]\s+tu\s+(lugar|asistencia)|qued[oó]\s+confirmad|ya\s+est[aá]s\s+(confirmad|registrad|inscrit)|
                      \bagendé|te\s+(paso|pasé)\s+con|ya\s+le\s+(pasé|avisé))/xi
  NO_CLAIM = 'Dijiste que ya hiciste algo (levantar el caso, registrar, agendar o pasarlo) pero no llamaste la herramienta. ' \
             'Si toca hacerlo, llama la herramienta ahora (crear_caso, registrar_gestion, canalizar o agendar_cita) y luego ' \
             'contesta; si no toca, reescribe sin decir que ya lo hiciste.'

  # Ya levantó el caso o registró lo que pidió: no se ofrece pasarlo con alguien más («¿quieres que te pase con…?»).
  OFFER_HANDOFF = /\s*¿[^¿?]*\bte\s+(pase|paso|comunique)\s+con[^?]*\?/i

  NOT_CONFIRMED = 'Revisé tu respuesta contra lo que trajeron tus fuentes: %<falta>s no está confirmado. Reescríbela diciendo ' \
                  'SOLO lo que sí confirman las fuentes y, de lo demás, que no lo puedes confirmar (ofrece que alguien del equipo se ' \
                  'lo confirme). No ofrezcas otra cosa en lugar de lo que pidió.'
  FALLBACK = 'No te lo puedo confirmar por aquí. Si quieres, alguien del equipo te lo confirma.'

  def ensure_evidence(messages, text)
    return text unless evidence_needed?

    support = support_evidence?
    check = Motor2::EvidenceCheck.new(account: @account).call(question: @last_customer, reply: text, evidence: evidence_text, support: support)
    return text if check['veredicto'] == 'EXACTA'

    @trace.event(:evidencia, "#{check['veredicto']}: #{check['falta']}")
    rewrite_unconfirmed(messages, text, check['falta'].presence || 'parte', support)
  end

  # Se reescribe con lo confirmado; si no sale, el mensaje seguro (de ventas o de soporte).
  def rewrite_unconfirmed(messages, text, missing, support)
    note = format(support ? Motor2::SupportChecks::NOT_CONFIRMED_SUPPORT : NOT_CONFIRMED, falta: missing)
    messages << { role: 'assistant', content: text } << { role: 'system', content: note }
    again = clean(run(messages))
    return again if again.present? && !unsourced?(again)

    support ? Motor2::SupportChecks::FALLBACK_SUPPORT : FALLBACK
  end

  def evidence_needed?
    return true if support_evidence?

    areas = find_skill('areas')
    return false unless @mode == :reply && @decision.nil? && areas&.area_key == 'sales'

    (areas.now['gestion'].presence || 'info') == 'info'
  end

  # Lo que trajeron las fuentes, lo que la empresa escribió de su negocio (horario, dirección, pagos) y lo que el agente ya
  # le dijo en mensajes anteriores (ya pasó esta revisión): «caballero» después de «Corte de caballero $200» no se bloquea.
  def evidence_text
    business = @config.function.respond_to?(:business_evidence) ? @config.function.business_evidence : nil
    before = Array(@said_before).compact_blank.presence&.then { |list| "LO QUE YA LE DIJISTE (revisado): #{list.join(' | ')}" }
    [*@evidence, business, before].compact_blank.join("\n---\n").first(8000)
  end

  FILE_CLAIM = /\b(te|le)\s+(env[ií]o|mando|comparto|adjunto|dejo)\s+(aqu[ií]\s+)?(la|el|las|los|una|un|nuestr[oa]s?)?\s*
                (fotos?|im[aá]gen(es)?|archivos?|flyers?|cat[aá]logos?|pdf|fichas?|mapas?|videos?|documentos?|folletos?|brochures?)/xi
  NO_FILE = 'Dijiste que le mandas un archivo pero no va ninguno. Si tienes ese archivo, mándalo con enviar_archivo; si no, ' \
            'reescribe sin decir que lo mandas.'

  def ensure_file_claim(messages, text)
    return text unless file_claim?(text)

    @trace.event(:revision, "dijo que manda un archivo sin mandarlo: #{text[FILE_CLAIM]}")
    messages << { role: 'assistant', content: text } << { role: 'system', content: NO_FILE }
    again = clean(run(messages))
    return text if again.blank? || unsourced?(again)

    file_claim?(again) ? without_claims(again, FILE_CLAIM) : again
  end

  def file_claim?(text) = @mode == :reply && @attachments.empty? && text.match?(FILE_CLAIM)

  def ensure_area_action(messages, text)
    text = without_offer(text)
    pattern = claim_pattern
    return text unless claimed?(text, pattern)

    @trace.event(:revision, "dijo que lo hizo sin hacerlo: #{text[pattern]}")
    messages << { role: 'assistant', content: text } << { role: 'system', content: NO_CLAIM }
    again = clean(run(messages))
    return text if again.blank? || unsourced?(again)

    claimed?(again, pattern) ? without_claims(again, pattern) : again
  end

  def without_offer(text)
    return text unless find_skill('areas') && acted_now?

    text.gsub(OFFER_HANDOFF, '').strip.presence || text
  end

  # Si insiste, se quitan las frases que lo dicen (nunca se manda «ya levanté tu caso» sin caso).
  def without_claims(text, pattern)
    kept = text.split(/(?<=[.!?])\s+/).grep_v(pattern).join(' ').strip
    kept.presence || 'Con gusto te ayudo con eso. ¿Me confirmas los detalles?'
  end

  # «Atención a prospectos»: dice que la cita ya quedó sin haberla agendado.
  BOOKED = /(\bagendé|\bte\s+agendamos|ya\s+qued[oó]\s+(agendad|tu\s+cita|la\s+cita)|tu\s+cita\s+(qued[oó]|est[aá])\s+(agendad|confirmad|lista))/i

  # Qué revisar en este turno: Atención a clientes (casos, gestiones, canalizar) o la cita de prospectos; nil = nada.
  def claim_pattern
    return nil unless @mode == :reply && @decision.nil?

    areas = find_skill('areas')
    return areas.human_asked? ? nil : CLAIMED if areas

    other_claim_pattern
  end

  def other_claim_pattern
    return CAMPAIGN_CLAIMED if find_skill('campaign')

    BOOKED if find_skill('appointments') && find_skill('qualify')
  end

  def claimed?(text, pattern)
    return false if pattern.nil? || !text.match?(pattern)

    pattern == BOOKED ? @trace.tools.none? { |t| t['name'] == 'agendar_cita' && t['ok'] } : !acted_now?
  end

  def acted_now? = @trace.tools.any? { |t| ACTION_TOOLS.include?(t['name']) && t['ok'] }
end
