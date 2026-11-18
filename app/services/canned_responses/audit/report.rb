# frozen_string_literal: true

# ================================================================================
# proyecto@auditoria_predefinidas — LO QUE ENSEÑA LA PESTAÑA «AUDITORÍA»
# ================================================================================
# El tamaño se calcula en vivo (no es un hallazgo guardado): cambia en cuanto se edita y
# no cuesta nada. Cuenta lo mismo que recibe el agente: «nombre: contenido».
#
#   ≤ WARN_CHARS            cabe completa
#   WARN_CHARS…MAX_CHARS    cerca del tope
#   > MAX_CHARS             el agente ve solo el nombre y las secciones que más se
#                           parecen a la pregunta (KnowledgeBase::SectionFit)
#
# Los bloques de cada una (párrafos, como los parte SectionFit) van con su tamaño, para
# ver qué parte conviene llevar a otra predefinida.
# ================================================================================

class CannedResponses::Audit::Report
  MAX_CHARS = KnowledgeBaseResponseService::MAX_ITEM_CHARS
  WARN_CHARS = (MAX_CHARS * 0.8).to_i
  LENGTH_SQL = "(char_length(COALESCE(canned_responses.short_code, '')) + 2 + " \
               "char_length(COALESCE(canned_responses.content, '')))"

  def self.length_sql = LENGTH_SQL

  def initialize(account)
    @account = account
  end

  def call(status: 'open')
    hallazgos = @account.canned_response_findings.where(status: status == 'dismissed' ? 'dismissed' : 'open')
                        .includes(:canned_response, :other_canned_response)
                        .order(Arel.sql("CASE severity WHEN 'high' THEN 0 WHEN 'medium' THEN 1 ELSE 2 END"), :kind, :id)
    { summary: summary, limits: { max: MAX_CHARS, warn: WARN_CHARS }, oversize: oversize,
      findings: hallazgos.map(&:as_audit_json), audit: last_audit }
  end

  def summary
    abiertos = @account.canned_response_findings.unresolved.group(:kind).count
    {
      'oversize' => sized.where("#{LENGTH_SQL} > ?", MAX_CHARS).count,
      'near_limit' => sized.where("#{LENGTH_SQL} > ? AND #{LENGTH_SQL} <= ?", WARN_CHARS, MAX_CHARS).count,
      'dismissed' => @account.canned_response_findings.dismissed.count
    }.merge(CannedResponseFinding::KINDS.index_with { |k| abiertos[k] || 0 })
  end

  private

  def sized = @account.canned_responses

  def oversize
    sized.where("#{LENGTH_SQL} > ?", MAX_CHARS).order(Arel.sql("#{LENGTH_SQL} DESC")).map do |r|
      r.form_json.merge(
        'blocks' => KnowledgeBase::SectionFit.blocks_of(r.agent_text).map { |b| { chars: b.size, preview: b.truncate(90) } }
      )
    end
  end

  def last_audit
    @account.canned_response_audits.order(:id).last&.as_audit_json
  end
end
