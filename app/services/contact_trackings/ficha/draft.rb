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
        'sheet' => only(h['sheet'], %w[purpose search_by answer_with remember]),
        'ticket' => only(h['ticket'], %w[reasons priority escalate_from]) }.compact
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

      { 'name' => h['name'].to_s }.merge(ContactTrackings::Ficha::Settings.rule(h))
    end
  end

  # { 'catalogo' => { 'ask' => true, … 'routes' => ['consultar_precios'] } } (TrackingTemplate#file_rules).
  # En la pantalla la ruta se elige por su recurso (la llave de la oferta); aquí ya tiene nombre.
  def file_rules
    nombres = result[:routes].to_h { |r| [r[:key].to_s, r[:name]] }
    files.to_h { |f| [f['name'], f.except('name').merge('routes' => f['routes'].filter_map { |k| nombres[k] || k })] }
  end

  # { 'google_sheet:12' => ['lista-precios'] } — archivos que van al contestar esa ruta.
  def route_files
    files.each_with_object(Hash.new { |h, k| h[k] = [] }) do |f, acc|
      f['routes'].each { |key| acc[key] << f['name'] }
    end
  end

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
      generado = ContactTrackings::Ficha::Generator.new(account: @account, name: name, offers: active_offers, **generator_options).call
      generado.merge(offers: offers.map { |o| o.except(:route).merge(on: skipped.exclude?(o[:key])) })
    end
  end

  def generator_options
    { objective: @params[:objective], business: @params[:business], tone: @params[:tone], tone_adjust: @params[:tone_adjust],
      welcome: @params[:welcome], welcome_files: welcome_files, route_files: route_files,
      questions: ContactTrackings::Ficha::Questions.clean(@params[:questions]), questions_when: @params[:questions_when],
      variables: ContactTrackings::Ficha::Memory.clean(@params[:variables]),
      business_data: ContactTrackings::Ficha::BusinessData.clean(@params[:business_data]) }
  end

  attr_reader :params
end
