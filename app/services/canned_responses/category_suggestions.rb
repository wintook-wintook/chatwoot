# frozen_string_literal: true

# ================================================================================
# proyecto@respuestas_predefinidas R3 (D3) — CATEGORÍAS SUGERIDAS POR LOS NOMBRES
# ================================================================================
# Hoy la gente ya escribe la categoría al principio del nombre («PATITAS HORARIO»,
# «01.VENTAS precios») y los agentes buscan por ese principio
# (@buscar_predefinidas(PATITAS)). Esto propone esas categorías; la persona acepta cuáles.
#
#   · el principio del nombre hasta el primer espacio, «_» o «-» («01.VENTAS» queda entero);
#   · solo entre las predefinidas que todavía no tienen categoría;
#   · al menos MIN_COUNT, con alguna letra, sin palabras comunes («La», «Cómo», «Error»:
#     son el principio de una frase, no una categoría);
#   · primero las que ya usan los agentes de la cuenta en @buscar_predefinidas(…).
# Sin IA.
# ================================================================================

class CannedResponses::CategorySuggestions
  MIN_COUNT = 2
  MAX = 15
  PREFIX_RE = /\A[^\s_-]+/
  COMMON = %w[
    a al como con cual cuando de del el en error errores es esta este falla fallas la las lo los mi no para
    por problema problemas que se si sin su tu un una crear registrar hola gracias ver video manual
  ].freeze

  def initialize(account)
    @account = account
  end

  # [{ name:, count:, canned_ids:, agents: }]
  def call
    tomadas = @account.canned_response_categories.pluck(:name).to_set { |n| key(n) }
    grupos = groups_by_prefix.reject { |nombre, _| tomadas.include?(key(nombre)) }
    grupos.map { |nombre, ids| { name: nombre, count: ids.size, canned_ids: ids, agents: agents_using(nombre) } }
          .sort_by { |s| [-s[:agents], -s[:count], s[:name]] }.first(MAX)
  end

  private

  def groups_by_prefix
    grupos = Hash.new { |h, k| h[k] = { nombre: nil, ids: [] } }
    @account.canned_responses.where(category_id: nil).pluck(:id, :short_code).each do |id, nombre|
      prefijo = nombre.to_s.strip[PREFIX_RE]
      next unless usable?(prefijo)

      grupo = grupos[key(prefijo)]
      grupo[:nombre] ||= prefijo
      grupo[:ids] << id
    end
    grupos.values.select { |g| g[:ids].size >= MIN_COUNT }.to_h { |g| [g[:nombre], g[:ids]] }
  end

  def usable?(prefijo)
    prefijo.present? && prefijo.length >= 3 && prefijo.match?(/\p{L}/) && COMMON.exclude?(key(prefijo))
  end

  # Cuántos agentes buscan ya con ese grupo.
  def agents_using(nombre)
    @agent_groups ||= @account.tracking_templates.pluck(:complementary_prompt).map do |texto|
      texto.to_s.scan(KnowledgeBase::Directives::CANNED_RE).flatten.compact.to_set { |g| key(g.delete_prefix('!')) }
    end
    @agent_groups.count { |grupos| grupos.include?(key(nombre)) }
  end

  def key(texto) = I18n.transliterate(texto.to_s).downcase.strip
end
