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
  def initialize(ticket, config: nil, now: nil)
    @ticket  = ticket
    @account = ticket.account
    @config  = config || CaseFolioConfig.for_account(@account)
    @now     = now || ticket.created_at || Time.current
  end

  # Genera y retorna el folio (string). No persiste — el caller asigna ticket.folio.
  def generate
    return nil unless @config.enabled?

    seq = CaseFolioCounter.next_value!(@account.id, counter_key)
    render_template(seq)
  end

  private

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
