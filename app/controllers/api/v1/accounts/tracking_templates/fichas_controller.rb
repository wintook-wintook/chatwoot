# frozen_string_literal: true

# ================================================================================
# feat/ficha_agente_ia — LA FICHA DEL AGENTE
# ================================================================================
# Plan: docs/ficha_agente_ia_plan.md. Solo administradores (igual que el Asistente).
#
# Agente nuevo (sin id):
#   GET  tracking_templates/ficha_catalog?inbox_id=   las tarjetas para marcar
#   POST tracking_templates/ficha_preview             ofertas + Entrenamiento generado + comprobador
#   POST tracking_templates/ficha_create              crea el agente con todo eso (sin IA)
#     params: name, inbox_id, items[], skip[] (ofertas apagadas), objective, business, tone,
#             customer_display_name, files[] ({ name }: archivos que la pantalla sube al crear)
#
# Agente que ya existe:
#   GET   tracking_templates/:id/ficha        tarjetas + lo marcado + cambios contra el prompt
#   PATCH tracking_templates/:id/ficha        guarda lo marcado (items) y devuelve los cambios
#   POST  tracking_templates/:id/ficha/apply  aplica al prompt add[] (ofertas) y remove[] (rutas)
# ================================================================================

class Api::V1::Accounts::TrackingTemplates::FichasController < Api::V1::Accounts::BaseController
  INVALID = 'El Entrenamiento tiene errores que impiden guardarlo.'

  before_action :check_authorization
  before_action :fetch_tracking_template, only: [:show, :update, :apply]

  def catalog
    render json: { cards: catalog_for(inbox).call }
  end

  def preview
    render json: build(catalog_for(inbox).call)
  end

  def show
    render json: ficha_json
  end

  def create
    resultado = build(catalog_for(inbox).call)
    return render json: resultado.merge(error: INVALID), status: :unprocessable_entity unless resultado[:validation][:valid]

    template = Current.account.tracking_templates.create!(new_template_attributes(resultado))
    render json: resultado.merge(id: template.id), status: :created
  end

  def update
    @tracking_template.update!(resources: resources_for(items), calendar_integration_ids: calendar_ids(items),
                               version_note: 'Ficha actualizada')
    render json: ficha_json
  end

  def apply
    texto = edited_prompt
    validacion = ContactTrackings::Assistant::ValidatorService.new(texto, account: Current.account).call
    return render json: { error: INVALID, validation: validacion.slice(:blocking) }, status: :unprocessable_entity unless validacion[:valid]

    @tracking_template.update!(complementary_prompt: texto, version_note: 'Cambios de la ficha')
    render json: ficha_json
  end

  private

  def new_template_attributes(resultado)
    { name: params[:name].to_s.squish, inbox_id: inbox&.id, user: Current.user,
      objective: resultado[:objective], ai_context: resultado[:ai_context].presence,
      complementary_prompt: resultado[:prompt], resources: resources_for(items),
      calendar_integration_ids: calendar_ids(items), version_note: 'Creado desde la ficha',
      customer_display_name: params[:customer_display_name].presence }
  end

  # El prompt con lo que la persona aceptó: add[] = ofertas de la ficha, remove[] = rutas.
  def edited_prompt
    editor = ContactTrackings::Ficha::PromptEditor.new(@tracking_template.complementary_prompt, name: @tracking_template.name)
    Array(params[:add]).filter_map { |key| template_offers[key.to_s] }.each { |oferta| editor.add(oferta) }
    Array(params[:remove]).each { |ruta| editor.remove(ruta.to_s) }
    editor.text
  end

  def template_offers
    cards = catalog_for(@tracking_template.inbox, @tracking_template).call
    ContactTrackings::Ficha::Offers.new(cards, current_items).call.index_by { |o| o[:key] }
  end

  def check_authorization
    render json: { error: I18n.t('errors.unauthorized') }, status: :unauthorized unless Current.account_user&.administrator?
  end

  def fetch_tracking_template
    @tracking_template = Current.account.tracking_templates.find(params[:tracking_template_id])
  end

  def inbox
    return @inbox if defined?(@inbox)

    @inbox = params[:inbox_id].present? ? Current.account.inboxes.find_by(id: params[:inbox_id]) : nil
  end

  def catalog_for(bandeja, template = nil)
    ContactTrackings::Ficha::Catalog.new(Current.account, inbox: bandeja, template: template)
  end

  # [{ 'key' => 'google_sheet:12' }, { 'key' => 'canned_response', 'parts' => ['PATITAS'] }]
  def items
    lista = Array(params[:items]).map { |item| item_from(item) }
    lista.select { |i| i['key'].present? }
  end

  def item_from(item)
    h = item.respond_to?(:permit) ? item.permit(:key, parts: []).to_h : item.to_h
    { 'key' => h['key'].to_s, 'parts' => Array(h['parts']).map(&:to_s).presence }.compact
  end

  def current_items
    ContactTrackings::Ficha::Changes.new(@tracking_template).items
  end

  def resources_for(lista)
    { 'items' => lista, 'confirmed_at' => Time.current.iso8601 }
  end

  def calendar_ids(lista)
    lista.filter_map { |i| i['key'][/\Acalendar:(\d+)\z/, 1]&.to_i }
  end

  def offers_for(cards)
    ContactTrackings::Ficha::Offers.new(cards, items).call + ContactTrackings::Ficha::Offers.pending_files(params[:files])
  end

  def build(cards)
    apagadas = Array(params[:skip]).map(&:to_s)
    ofertas = offers_for(cards)
    generado = ContactTrackings::Ficha::Generator.new(
      account: Current.account, name: params[:name], offers: ofertas.reject { |o| apagadas.include?(o[:key]) },
      **params.permit(:objective, :business, :tone).to_h.symbolize_keys
    ).call
    generado.merge(offers: ofertas.map { |o| o.except(:route).merge(on: apagadas.exclude?(o[:key])) })
  end

  def ficha_json
    @tracking_template.reload
    cards = catalog_for(@tracking_template.inbox, @tracking_template).call
    cambios = ContactTrackings::Ficha::Changes.new(@tracking_template, cards: cards)
    { cards: cards, items: cambios.items, changes: cambios.call.except(:deduced) }
  end
end
