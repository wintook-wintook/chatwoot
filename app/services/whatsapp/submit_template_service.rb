# frozen_string_literal: true

# @waba_templates
# Orquestador de alta/edición/borrado de plantillas contra Meta. Une validador + resumable
# upload + builder + provider + persistencia. Fail-soft: si Meta falla guarda DRAFT con el
# error para reintentar; si Meta acepta pero falla el guardado local, reporta DRIFT.
#
# DRY_RUN (WHATSAPP_TEMPLATES_DRY_RUN): crea la fila PENDING sin tocar la red, para probar
# el flujo completo sin una App real de Meta.
class Whatsapp::SubmitTemplateService
  Result = Struct.new(:success, :template, :error, :drift, keyword_init: true) do
    def success?
      success
    end
  end

  def initialize(channel: nil, template: nil, params: {})
    @template = template
    @channel = channel || template&.channel_whatsapp
    @account = @channel&.account || template&.account
    @params = normalize_params(params)
  end

  # --- crear -----------------------------------------------------------------
  # Idempotente: si ya existe una fila con ese name+language (un DRAFT de un intento
  # previo, o una fila importada/sincronizada) la REUTILIZA en vez de crear una nueva.
  # Así el save! post-Meta no choca con el índice único (channel,name,language) y se
  # evita el DRIFT "Meta creó la plantilla pero falló el guardado local".
  def create
    template = @channel.whatsapp_templates
                       .find_or_initialize_by(name: @params[:name], language: @params[:language])
    template.assign_attributes(@params.merge(account: @account))
    validation = Whatsapp::TemplateValidator.call(template)
    return invalid(validation) unless validation.valid?

    return dry_run_persist(template) if dry_run?

    submit_new(template)
  end

  # --- editar (PATCH) --------------------------------------------------------
  def update
    return failure('La plantilla no es editable en su estado actual') unless @template.editable?

    @template.assign_attributes(@params)
    validation = Whatsapp::TemplateValidator.call(@template)
    return invalid(validation) unless validation.valid?

    return dry_run_persist(@template) if dry_run?

    submit_edit(@template)
  end

  # --- borrar ----------------------------------------------------------------
  def destroy
    # Filas que nunca llegaron a Meta (draft local / dry-run) no llaman a la API.
    if @template.local_only?
      @template.destroy!
      return Result.new(success: true, template: @template)
    end

    return failure('meta_template_id inválido') unless safe_id?(@template.meta_template_id)

    result = provider.delete_template(name: @template.name, meta_template_id: @template.meta_template_id)
    return failure(result.error) unless result.success?

    @template.destroy!
    Result.new(success: true, template: @template)
  end

  private

  # Modo A: sin red. Fila PENDING con meta_template_id sintético.
  def dry_run_persist(template)
    template.assign_attributes(
      status: 'PENDING',
      meta_template_id: template.meta_template_id.presence || "dry-run-#{SecureRandom.uuid}",
      submission_error: nil,
      last_submitted_at: Time.current
    )
    template.save!
    Result.new(success: true, template: template)
  end

  def submit_new(template)
    upload = ensure_header_handle(template)
    return upload if upload.is_a?(Result) # error de subida

    result = provider.create_template(Whatsapp::TemplateComponentBuilder.call(template))
    result.success? ? persist_accepted(template, result) : persist_failed(template, result)
  end

  def submit_edit(template)
    upload = ensure_header_handle(template)
    return upload if upload.is_a?(Result)

    components = Whatsapp::TemplateComponentBuilder.new(template).components
    result = provider.edit_template(template.meta_template_id, components: components, category: template.category)
    return persist_failed(template, result) unless result.success?

    # Meta reemplaza los components y la vuelve a PENDING.
    template.assign_attributes(status: 'PENDING', submission_error: nil, last_submitted_at: Time.current)
    template.save!
    Result.new(success: true, template: template)
  end

  # Sube la imagen de cabecera si hace falta y setea el handle en la plantilla.
  def ensure_header_handle(template)
    return unless template.header_type == 'image' && template.header_handle.blank? && template.header_media_url.present?

    upload = Whatsapp::ResumableUploadService.new(channel: @channel, media_url: template.header_media_url).perform
    return failure(upload.error) unless upload.success?

    template.header_handle = upload.handle
    nil
  end

  # Meta aceptó: guardar meta_id + status. Si el guardado local falla → DRIFT explícito.
  def persist_accepted(template, result)
    template.assign_attributes(
      status: result.status.presence || 'PENDING',
      meta_template_id: result.meta_id,
      submission_error: nil,
      last_submitted_at: Time.current
    )
    template.save!
    Result.new(success: true, template: template)
  rescue StandardError => e
    Rails.logger.error "[waba_templates] drift: Meta creó #{result.meta_id} pero falló el guardado local: #{e.message}"
    Result.new(success: false, drift: true, template: template,
               error: "Meta creó la plantilla (#{result.meta_id}) pero falló el guardado local. Usa \"Sync\" para reconciliar.")
  end

  # Meta falló: guardar DRAFT + error para reintento.
  def persist_failed(template, result)
    template.assign_attributes(status: 'DRAFT', submission_error: result.error, last_submitted_at: Time.current)
    template.save
    Result.new(success: false, template: template, error: result.error)
  end

  def provider
    @channel.provider_service
  end

  def dry_run?
    ActiveModel::Type::Boolean.new.cast(GlobalConfigService.load('WHATSAPP_TEMPLATES_DRY_RUN', false))
  end

  # Meta usa hsm_id numérico; validamos un token seguro (evita inyección en el query).
  def safe_id?(id)
    id.to_s.match?(/\A[\w-]+\z/)
  end

  # Acepta ActionController::Parameters (permitidos) o un hash normal.
  def normalize_params(params)
    return {}.with_indifferent_access if params.blank?
    return params.to_unsafe_h.with_indifferent_access if params.respond_to?(:to_unsafe_h)

    params.with_indifferent_access
  end

  def invalid(validation)
    Result.new(success: false, error: validation.errors.join(' · '))
  end

  def failure(message)
    Result.new(success: false, error: message)
  end
end
