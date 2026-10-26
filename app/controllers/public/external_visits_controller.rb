# Plan-Trabajo-Campo R5 — la visita de un técnico externo (sin usuario), por un
# enlace que sirve hasta que termina o vence: ver la orden, Llegué (con
# ubicación), notas y fotos, y Terminé con la conformidad y firma del cliente.
class Public::ExternalVisitsController < PublicController
  layout 'public_document'

  before_action :set_order
  around_action :use_account_locale

  def show
    @entry = @order.time_entries.visit.running.find_by(user_id: nil)
    @logs = @order.work_logs.ordered.includes(file_attachment: :blob)
  end

  def arrive
    Field::Visit.new(@order, nil).arrive!(location_param).update!(note: technician_name)
    redirect_to public_external_visit_path(params[:token])
  end

  # Nota o foto; si viene vacía no se guarda nada.
  def log
    build_log.save
    redirect_to public_external_visit_path(params[:token])
  rescue ArgumentError
    redirect_to public_external_visit_path(params[:token])
  end

  def finish
    Field::Visit.new(@order, nil).finish!(location_param, conformity_params)
    @order.close_external_link!
    render :done
  rescue ServiceReports::Incomplete, ActiveRecord::RecordInvalid => e
    flash.now[:error] = e.message
    show
    render :show, status: :unprocessable_entity
  end

  private

  # Vencido o ya terminado: lo dice en el idioma de la cuenta (el around_action aún no corre).
  def set_order
    @order = CaseTicket.includes(:account, :contact).find_by(external_token: params[:token])
    @account = @order&.account
    return if @order&.external_link_active?

    use_account_locale { render :expired, status: :gone }
  end

  def build_log
    log = @order.work_logs.new(account: @order.account, kind: log_kind, tag: params[:tag].presence,
                               content: params[:content].to_s.strip.presence)
    log.file.attach(params[:file]) if params[:file].present?
    log
  end

  def technician_name
    @order.external_technician['name']
  end

  def log_kind
    return :note if params[:file].blank?

    params[:file].content_type.to_s.start_with?('image/') ? :photo : :document
  end

  def location_param
    return {} if params[:lat].blank? || params[:lng].blank?

    { lat: params[:lat].to_f, lng: params[:lng].to_f, accuracy: params[:accuracy]&.to_f, at: Time.current.iso8601 }.compact
  end

  def conformity_params
    data = params[:signature].to_s
    { received_by: params[:received_by].to_s.strip, conformity_note: params[:conformity_note].to_s.strip,
      signature: (data if data.start_with?('data:image/png;base64,') && data.size < 400_000) }
  end

  def use_account_locale(&)
    I18n.with_locale(@account&.locale.presence || I18n.default_locale, &)
  end
end
