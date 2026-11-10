# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — PROBAR EL AGENTE ANTES DE CREARLO
# ================================================================================
# Cada frase (TestPhrases) pasa por el clasificador REAL del motor sobre el borrador
# (DraftClassifier → BranchClassifierService): una llamada barata por frase, EN SERIE
# (ver DraftClassifier: en paralelo un pool agotado se leería como ruta por defecto).
#
#   { total:, passed:, per_route: [{ route:, key:, label:, results: [{ phrase:, got:, ok: }] }],
#     real: [{ phrase:, got:, route_label: }] }
#
# progress: ->(done, total) para la pantalla (TurnProgress).
# ================================================================================

class ContactTrackings::Ficha::Tester
  def initialize(account, draft:, routes:, offers:, inbox: nil, from_description: false) # rubocop:disable Metrics/ParameterLists
    @account = account
    @draft = draft
    @routes = routes
    @inbox = inbox
    @phrases = ContactTrackings::Ficha::TestPhrases.new(account, routes: routes, offers: offers, inbox: inbox,
                                                                 from_description: from_description).call
  end

  def call(progress: nil)
    @progress = progress
    @done = 0
    por_ruta = @phrases[:per_route].map { |entrada| route_result(entrada) }
    reales = @phrases[:real].map { |frase| real_result(frase) }
    pruebas = por_ruta.flat_map { |r| r[:results] }
    { total: pruebas.size, passed: pruebas.count { |r| r[:ok] }, per_route: por_ruta, real: reales,
      default_route: default_route, routes: @routes.map { |r| r.slice(:name, :key, :label) } }
  end

  private

  def total = @total ||= @phrases[:per_route].sum { |e| e[:phrases].size } + @phrases[:real].size

  def route_result(entrada)
    resultados = entrada[:phrases].map do |frase|
      got = classify(frase)
      { phrase: frase, got: got, got_label: label_of(got), ok: got == entrada[:route] }
    end
    entrada.except(:phrases).merge(results: resultados)
  end

  # Lo que de verdad escriben los clientes: sin ruta esperada. `fallback` = cayó en la ruta
  # por defecto (suele ser «no la entendió»): la pantalla ofrece mandarla a otra.
  def real_result(frase)
    got = classify(frase)
    { phrase: frase, got: got, got_label: label_of(got), fallback: got.nil? || got == default_route }
  end

  def default_route = @draft.to_s[ContactTrackings::RouteMap::DEFAULT_RE, 1]

  def classify(frase)
    @last = classifier.classify(frase)&.name
  ensure
    @done += 1
    @progress&.call(@done, total)
  end

  def label_of(nombre) = @routes.find { |r| r[:name] == nombre }&.dig(:label)

  def classifier
    @classifier ||= ContactTrackings::Assistant::DraftClassifier.new(@account, draft: @draft, inbox: @inbox)
  end
end
