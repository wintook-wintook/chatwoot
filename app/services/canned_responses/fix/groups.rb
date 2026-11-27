# frozen_string_literal: true

# ================================================================================
# proyecto@arreglar_predefinidas — LOS GRUPOS QUE NO SE PUEDEN ROMPER
# ================================================================================
# Un agente puede buscar solo en un grupo: @buscar_predefinidas(GRUPO). El grupo es una
# CATEGORÍA fija (General, Ficha, Objeción) o el PRINCIPIO del nombre
# (KnowledgeBase::CannedGroup). La categoría la heredan las partes solas; el principio del
# nombre no: si la original se llama
# «SOPORTE Alta de empresa» y un agente busca en SOPORTE, cada parte tiene que empezar
# también con «SOPORTE» o ese agente deja de encontrarla.
#
# Se leen los grupos que de verdad usan los agentes de la cuenta (su Entrenamiento y los
# recursos de su ficha), no se adivina un prefijo.
# ================================================================================

class CannedResponses::Fix::Groups
  def initialize(account)
    @account = account
  end

  # Los prefijos con que tiene que empezar el nombre de cada parte.
  def required_prefixes(short_code)
    nombre = key(short_code)
    used.reject { |g| category?(g) }.select { |g| nombre.start_with?(key(g)) }
  end

  # Todos los grupos (sin «!») que nombra algún agente de la cuenta.
  def used
    @used ||= begin
      nombres = @account.tracking_templates.pluck(:complementary_prompt, :resources).flat_map { |t, r| groups_of(t, r) }
      nombres.reject { |g| g.blank? || g.start_with?('!') }.uniq { |g| key(g) }
    end
  end

  private

  # Los de @buscar_predefinidas(…) en el Entrenamiento y los de la ficha (resources).
  def groups_of(texto, recursos)
    directivas = texto.to_s.scan(KnowledgeBase::Directives::CANNED_RE).flatten.compact
    partes = Array(recursos.is_a?(Hash) ? recursos['items'] : nil).flat_map { |i| i.is_a?(Hash) ? Array(i['parts']) : [] }
    (directivas + partes).map { |g| g.to_s.strip }
  end

  def category?(name) = KnowledgeBase::CannedGroup.kind_named(name).present?
  def key(texto) = ActiveSupport::Inflector.transliterate(texto.to_s).downcase.strip
end
