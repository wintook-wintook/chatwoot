# frozen_string_literal: true

# Eventos — enlaces para captar en la expo «acercando el celular» (etiqueta NFC).
#   GET    …/events/:event_id/capture_links        → enlaces del evento + bandejas de WhatsApp posibles
#   POST   …/events/:event_id/capture_links        { inbox_id, user_id?, message }
#   DELETE …/events/:event_id/capture_links/:id
# Permisos: área Campañas (AccessAreaGuard; para crear o borrar hay que poder escribir).
class Api::V1::Accounts::EventCaptureLinksController < Api::V1::Accounts::BaseController
  before_action :set_event

  def index
    links = @event.capture_links.includes(:inbox, :user).order(:created_at)
    render json: { links: links.map { |link| link_json(link) }, inboxes: whatsapp_inboxes,
                   default_message: I18n.t('events.capture.default_message', event: @event.name) }
  end

  def create
    link = @event.capture_links.new(link_params.merge(account: Current.account))
    if link.save
      render json: { link: link_json(link) }, status: :created
    else
      render json: { error: link.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def destroy
    @event.capture_links.find(params[:id]).destroy!
    head :no_content
  end

  private

  def set_event
    @event = Current.account.events.find(params[:event_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: I18n.t('events.errors.not_found') }, status: :not_found
  end

  def link_params
    attrs = params.permit(:inbox_id, :user_id, :message).to_h
    attrs[:inbox_id] = Current.account.inboxes.find_by(id: attrs[:inbox_id])&.id
    attrs[:user_id] = Current.account.users.find_by(id: attrs[:user_id])&.id
    attrs
  end

  def whatsapp_inboxes
    Current.account.inboxes.where(channel_type: 'Channel::Whatsapp').includes(:channel).filter_map do |inbox|
      phone = inbox.channel.try(:phone_number)
      { id: inbox.id, name: inbox.name, phone: phone } if phone.present?
    end
  end

  def link_json(link)
    { id: link.id, code: link.code, message: link.message, url: link.url, captures: link.captures_count,
      inbox: { id: link.inbox_id, name: link.inbox.name }, user: link.user && { id: link.user.id, name: link.user.name },
      label: Events::CaptureMatcher.label_for(@event), created_at: link.created_at }
  end
end
