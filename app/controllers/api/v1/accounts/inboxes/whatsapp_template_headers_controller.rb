# frozen_string_literal: true

# ================================================================================
# feat/plantillas_whatsapp_mejoras — EL ARCHIVO GUARDADO DE UNA PLANTILLA, PARA LA CONVERSACIÓN
# ================================================================================
#   GET inboxes/:inbox_id/whatsapp_template_header?name=&language=
#     → { available: true, media_type, media_name, preview_url }   lleva archivo y está guardado
#     → { available: false, media_type, error }                      lleva archivo y no se puede
#     → { available: false, media_type: nil }                        no lleva archivo
#   POST inboxes/:inbox_id/whatsapp_template_header   { media_type, file }
#     → { signed_id, filename, preview_url }   otro archivo, de la máquina del agente, para
#       este envío (va como header.source = 'upload'). Se revisa con los límites de Meta.
#
# El formulario de la conversación lo usa para traer ya puesto el archivo de la plantilla
# (el subido en la pantalla de plantillas): el agente solo da «Enviar». Lo puede ver
# cualquier agente de la bandeja (la API de plantillas es solo de administradores). No da
# la liga para Meta: esa la saca el envío al momento (SendOnWhatsappService).
# ================================================================================
class Api::V1::Accounts::Inboxes::WhatsappTemplateHeadersController < Api::V1::Accounts::BaseController
  before_action :set_inbox

  def show
    resultado = ContactTrackings::TemplateHeader.for(@inbox.channel, params[:name].to_s, params[:language].to_s)
    return render json: { available: false, media_type: nil } if resultado.nil?
    return render json: { available: false, media_type: template_media_type, error: resultado.error } if resultado.error.present?

    render json: { available: true, media_type: resultado.media[:type], media_name: resultado.media[:name],
                   preview_url: resultado.media[:preview_url] }
  end

  def create
    archivo = params[:file]
    error = Whatsapp::ResumableUploadService.file_error(archivo, params[:media_type])
    return render json: { error: error }, status: :unprocessable_entity if error

    blob = ActiveStorage::Blob.create_and_upload!(io: archivo, filename: archivo.original_filename,
                                                  content_type: archivo.content_type)
    render json: { signed_id: blob.signed_id, filename: blob.filename.to_s,
                   preview_url: Rails.application.routes.url_helpers.rails_blob_url(blob) }, status: :created
  end

  private

  def set_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    authorize @inbox, :show?
    head :unprocessable_entity unless @inbox.channel_type == 'Channel::Whatsapp'
  end

  def template_media_type
    ContactTrackings::TemplateHeader.media_type(@inbox.channel, params[:name].to_s)
  end
end
