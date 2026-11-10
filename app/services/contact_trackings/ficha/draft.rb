# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — LO QUE MANDA LA PANTALLA, ARMADO
# ================================================================================
# Un solo lugar que convierte lo capturado en la ficha (agente nuevo) en tarjetas,
# ofertas y el Entrenamiento generado. Lo usan el controlador (vista previa, crear,
# proponer con IA) y el job de prueba (FichaTestJob), así no hay dos versiones.
#
#   name, inbox_id, items[], skip[], files[] ({ name }), phrases ({ oferta => [frases] }),
#   objective, business, tone
#
# Lee SOLO esas llaves (lo demás se ignora).
# ================================================================================

class ContactTrackings::Ficha::Draft
  def initialize(account, params)
    @account = account
    @params = (params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h).with_indifferent_access
  end

  def name = @params[:name].to_s.squish

  def inbox
    return @inbox if defined?(@inbox)

    @inbox = @params[:inbox_id].present? ? @account.inboxes.find_by(id: @params[:inbox_id]) : nil
  end

  def cards = @cards ||= ContactTrackings::Ficha::Catalog.new(@account, inbox: inbox).call

  # [{ 'key' => 'google_sheet:12' }, { 'key' => 'canned_response', 'parts' => ['PATITAS'] }]
  def items
    @items ||= Array(@params[:items]).filter_map do |item|
      h = item.to_h.stringify_keys
      next if h['key'].blank?

      { 'key' => h['key'].to_s, 'parts' => Array(h['parts']).map(&:to_s).presence,
        'sheet' => only(h['sheet'], %w[purpose search_by answer_with]),
        'ticket' => only(h['ticket'], %w[reasons priority]) }.compact
    end
  end

  # La configuración de una tarjeta (hoja, ticket) con solo esas llaves, o nil.
  def only(config, llaves) = config.presence && config.to_h.stringify_keys.slice(*llaves)

  def skipped = Array(@params[:skip]).map(&:to_s)

  # Los archivos que la persona eligió subir, con su regla de envío:
  #   [{ name:, ask: true, welcome: false, attempts: [2] }]
  def files
    Array(@params[:files]).filter_map do |archivo|
      h = archivo.to_h.stringify_keys
      next unless h['name'].to_s.match?(/\A[a-zA-Z0-9_-]{1,60}\z/)

      { 'name' => h['name'].to_s, 'ask' => h.key?('ask') ? ActiveModel::Type::Boolean.new.cast(h['ask']) : true,
        'welcome' => ActiveModel::Type::Boolean.new.cast(h['welcome']) || false,
        'attempts' => Array(h['attempts']).map(&:to_i).select(&:positive?).uniq.sort }
    end
  end

  # { 'catalogo' => { 'ask' => true, 'welcome' => false, 'attempts' => [2] } } (TrackingTemplate#file_rules)
  def file_rules = files.to_h { |f| [f['name'], f.except('name')] }

  def welcome_files = files.select { |f| f['welcome'] }.pluck('name')

  # Frases que la persona agregó a una ruta desde la prueba: { 'google_sheet:12' => ['¿cuánto…?'] }
  def phrases
    (@params[:phrases] || {}).to_h.transform_keys(&:to_s).transform_values { |v| Array(v).map(&:to_s).compact_blank }
  end

  def offers
    @offers ||= ContactTrackings::Ficha::Offers.new(cards, items, phrases: phrases).call +
                ContactTrackings::Ficha::Offers.pending_files(@params[:files])
  end

  def active_offers = offers.reject { |o| skipped.include?(o[:key]) }

  # { prompt:, objective:, ai_context:, routes:, validation:, offers: [... on:] }
  def result
    @result ||= begin
      generado = ContactTrackings::Ficha::Generator.new(
        account: @account, name: name, offers: active_offers,
        objective: @params[:objective], business: @params[:business], tone: @params[:tone],
        welcome: @params[:welcome], welcome_files: welcome_files
      ).call
      generado.merge(offers: offers.map { |o| o.except(:route).merge(on: skipped.exclude?(o[:key])) })
    end
  end

  attr_reader :params
end
