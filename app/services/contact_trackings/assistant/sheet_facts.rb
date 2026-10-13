# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — ¿ESE DATO ESTÁ EN SUS HOJAS? (P2 · 3.4a)
# ================================================================================
# El juez no sabe qué datos tenía el agente. Con Grúas (13/10/2026) dijo «inventó las
# placas 92UN8A» y la placa está en su hoja de remolques; aunque se le pidió no hacerlo,
# lo siguió marcando por el «nunca inventar información técnica» de su [PROHIBIDO].
#
# Antes de preguntarle, el código saca de la respuesta los datos con números (placas,
# modelos, toneladas, folios: «92UN8A», «TP-55», «40.8») y los busca en las hojas de
# Google de la cuenta. Lo que sí está se le pasa al juez como dato real.
# ================================================================================

class ContactTrackings::Assistant::SheetFacts
  TOKEN_RE = %r{(?<![\p{L}\d])[\p{L}\d][\p{L}\d.\-/]*\d[\p{L}\d.\-/]*(?![\p{L}\d])}
  MIN_LENGTH = 3
  MAX_TOKENS = 15

  def initialize(account)
    @account = account
  end

  # { '92UN8A' => 'Remolques', … } — solo los que están en alguna hoja.
  def call(texto)
    tokens(texto).each_with_object({}) do |token, encontrados|
      hoja = sheet_with(token)
      encontrados[token] = hoja if hoja
    end
  end

  private

  def tokens(texto)
    texto.to_s.scan(TOKEN_RE).map { |t| t.sub(%r{[.\-/]+\z}, '') }.select { |t| t.length >= MIN_LENGTH }.uniq.first(MAX_TOKENS)
  end

  def sheet_with(token)
    GoogleSheetRow.where(account_id: @account.id).joins(:knowledge_source)
                  .where('google_sheet_rows.data::text ILIKE ?', "%#{ActiveRecord::Base.sanitize_sql_like(token)}%")
                  .pick('knowledge_sources.name')
  end
end
