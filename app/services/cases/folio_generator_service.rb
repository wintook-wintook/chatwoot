# frozen_string_literal: true

# ================================================================================
# @tickets_cases
# ================================================================================
# Servicio: Cases::FolioGeneratorService
# Responsabilidad: Generar el folio de un CaseTicket según la plantilla de la cuenta.
#
# Tokens soportados en la plantilla:
#   {PREFIX}   → prefijo del tipo de caso del ticket (case_type.prefix)
#   {SEQ}      → consecutivo sin padding
#   {SEQ:n}    → consecutivo con n dígitos, ceros a la izquierda
#   {YYYY}     → año (4 dígitos)   {YY} → año (2 dígitos)
#   {MM}       → mes (2 dígitos)   {DD} → día (2 dígitos)
#
# El "alcance" del consecutivo lo definen per_type y reset_period de la config:
#   counter_key = [type:<id> | global] + [: <período> si reset_period != never]
# El consecutivo se incrementa de forma ATÓMICA (CaseFolioCounter.next_value!).
# ================================================================================

class Cases::FolioGeneratorService
  # Reintentos acotados ante colisión de folio (contador desincronizado).
  RETRY_LIMIT = 10

  def initialize(ticket, config: nil, now: nil)
    @ticket  = ticket
    @account = ticket.account
    @config  = config || CaseFolioConfig.for_account(@account)
    @now     = now || ticket.created_at || Time.current
  end

  # Genera y retorna el folio (string). No persiste — el caller asigna ticket.folio.
  # Robusto a colisiones: si el folio candidato ya existe (p.ej. el contador quedó
  # detrás de folios sembrados/importados a mano), adelanta el contador al máximo
  # real y reintenta de forma acotada. Si aun así no resuelve, retorna nil (el folio
  # es opcional y el índice único es parcial sobre NOT NULL) para no bloquear el alta.
  def generate
    return nil unless @config.enabled?

    folio = render_next
    return folio unless folio_taken?(folio)

    fast_forward_counter! # contador detrás del máximo real → resincroniza una vez
    RETRY_LIMIT.times do
      folio = render_next
      return folio unless folio_taken?(folio)
    end

    Rails.logger.warn("[Folio] no se pudo generar folio único (cuenta #{@account.id}, key #{counter_key})")
    nil
  end

  private

  def render_next
    render_template(CaseFolioCounter.next_value!(@account.id, counter_key))
  end

  def folio_taken?(folio)
    folio.present? && @account.case_tickets.exists?(folio: folio)
  end

  # Eleva el contador al mayor consecutivo numérico ya presente en los folios de la
  # cuenta (lee los dígitos finales). Atómico; nunca baja el contador.
  def fast_forward_counter!
    max_seq = @account.case_tickets.where.not(folio: nil).pluck(:folio)
                      .filter_map { |f| f[/(\d+)\s*\z/, 1]&.to_i }.max.to_i
    CaseFolioCounter.set_min_value!(@account.id, counter_key, max_seq)
  end

  def counter_key
    parts = []
    parts << (@config.per_type? ? "type:#{@ticket.case_type_id || 'none'}" : 'global')
    parts << period_token unless @config.reset_period == 'never'
    parts.join(':')
  end

  def period_token
    case @config.reset_period
    when 'daily'   then @now.strftime('%Y%m%d')
    when 'monthly' then @now.strftime('%Y%m')
    when 'yearly'  then @now.strftime('%Y')
    else ''
    end
  end

  def render_template(seq)
    @config.template.gsub(/\{(\w+)(?::(\d+))?\}/) do
      token = Regexp.last_match(1)
      pad   = Regexp.last_match(2)&.to_i
      resolve_token(token, pad, seq)
    end
  end

  def resolve_token(token, pad, seq)
    case token
    when 'PREFIX' then @ticket.case_type&.prefix.to_s
    when 'SEQ'    then pad ? seq.to_s.rjust(pad, '0') : seq.to_s
    when 'YYYY'   then @now.strftime('%Y')
    when 'YY'     then @now.strftime('%y')
    when 'MM'     then @now.strftime('%m')
    when 'DD'     then @now.strftime('%d')
    else ''
    end
  end
end
