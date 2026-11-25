# frozen_string_literal: true

# Campaña con Vendedor IA — «Imágenes y archivos de esta oferta» (la foto del producto, el flyer del evento…). Van en
# ai_agent_attachments ligados a la campaña, con su regla:
#   rules { about     de qué es (el vendedor no ve la imagen: solo esto)
#           attempts  en qué toques va (1..6)
#           interest  cuando muestre interés · ask cuando lo pida · confirm cuando confirme (Invitar) }
# Los generales (catálogo, presentación de la empresa) siguen en el vendedor.
#
#   GET    motor2_campaigns/:motor2_campaign_id/files
#   POST   motor2_campaigns/:motor2_campaign_id/files          { file, about } (multipart) | { catalog_item_id } (Ofrecer:
#          la foto del producto del Catálogo, sin volver a subirla; va «cuando muestre interés»)
#   PATCH  motor2_campaigns/:motor2_campaign_id/files/:id      { rules }
#   DELETE motor2_campaigns/:motor2_campaign_id/files/:id
class Api::V1::Accounts::Motor2Campaigns::FilesController < Api::V1::Accounts::BaseController
  MAX_FILES = 10
  FLAGS = %w[interest ask confirm].freeze

  before_action :set_campaign
  before_action :set_file, only: %i[update destroy]

  def index = render(json: { files: @campaign.files.order(:id).map { |f| file_json(f) } })

  def create
    return render_error("Una campaña lleva hasta #{MAX_FILES} archivos.") if @campaign.files.count >= MAX_FILES
    return product_photo if params[:catalog_item_id].present?
    return render_error('Elige un archivo.') if params[:file].blank?

    file = new_file
    return render_error(file.errors.full_messages.to_sentence) unless file.save

    render json: file_json(file), status: :created
  end

  def update
    @file.update!(rules: rules(params.require(:rules).permit(:about, :interest, :ask, :confirm, attempts: []).to_h))
    render json: file_json(@file)
  end

  def destroy
    @file.destroy!
    head :ok
  end

  private

  def set_campaign
    @campaign = Current.account.tracking_campaigns.real.where(engine: '2').find(params[:motor2_campaign_id])
  end

  def set_file = @file = @campaign.files.find(params[:id])

  def new_file
    file = @campaign.files.new(account: Current.account, name: unique_name(params[:file].original_filename),
                               rules: rules(params.permit(:about, :interest, :ask, :confirm, attempts: []).to_h))
    file.file.attach(params[:file])
    file
  end

  # La foto del producto (Ofrecer): el mismo archivo del Catálogo; si ya está, no se repite.
  def product_photo
    item = Current.account.catalog_items.find(params[:catalog_item_id])
    return render_error('Ese producto no tiene foto.') unless item.image.attached?

    existing = @campaign.files.joins(file_attachment: :blob).find_by(active_storage_blobs: { id: item.image.blob.id })
    return render(json: file_json(existing)) if existing

    file = photo_file(item)
    file.save ? render(json: file_json(file), status: :created) : render_error(file.errors.full_messages.to_sentence)
  end

  def photo_file(item)
    file = @campaign.files.new(account: Current.account, name: unique_name(item.name),
                               rules: rules('about' => "Foto de #{item.name}", 'interest' => true))
    file.file.attach(item.image.blob)
    file
  end

  def render_error(message) = render(json: { error: message }, status: :unprocessable_entity)

  def rules(raw)
    max = TrackingCampaigns::Motor2Brief::MAX_TOUCHES
    { 'about' => raw['about'].to_s.squish.first(300),
      'attempts' => Array(raw['attempts']).map(&:to_i).select { |n| n.between?(1, max) }.uniq.sort }
      .merge(FLAGS.index_with { |flag| ActiveModel::Type::Boolean.new.cast(raw[flag]) || false })
  end

  # «Promo Noviembre.jpg» → «promo-noviembre» (sin repetir dentro de la campaña).
  def unique_name(filename)
    base = File.basename(filename.to_s, '.*').parameterize.first(50).presence || 'archivo'
    taken = @campaign.files.pluck(:name).map(&:downcase)
    name = base
    n = 1
    name = "#{base}-#{n += 1}" while taken.include?(name.downcase)
    name
  end

  def file_json(file)
    blob = file.file.attached? ? file.file : nil
    { id: file.id, name: file.name, rules: file.rules, filename: blob&.filename.to_s, content_type: blob&.content_type,
      byte_size: blob&.byte_size, url: blob ? url_for(blob) : nil, image: blob&.content_type.to_s.start_with?('image/') }
  end
end
