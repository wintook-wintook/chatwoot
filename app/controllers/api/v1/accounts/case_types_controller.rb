# frozen_string_literal: true

# ================================================================================
# @tickets_cases
# ================================================================================
# Controller: Api::V1::Accounts::CaseTypesController
#
# GET    /api/v1/accounts/:account_id/case_types       → index (crea defaults si vacío)
# POST   /api/v1/accounts/:account_id/case_types       → create
# PATCH  /api/v1/accounts/:account_id/case_types/:id   → update
# DELETE /api/v1/accounts/:account_id/case_types/:id   → destroy
#
# Clase de caso (Plan-Clase-Comercial F1): `?case_class=` filtra el index. La
# clase se elige al crear y es fija (hoja de ruta E1.4): `update` la rechaza (422).
# El prefijo también queda fijo en cuanto el tipo tiene casos (validación del modelo).
# ================================================================================

class Api::V1::Accounts::CaseTypesController < Api::V1::Accounts::BaseController
  before_action :set_type, only: %i[update destroy change_class]
  before_action :check_admin_authorization?, only: :change_class

  # Clases que la UI ofrece y el flag de cuenta que exige cada una.
  OFFERED_CLASSES = %w[support commercial work_order project].freeze
  CLASS_FLAGS = { 'commercial' => 'case_commercial', 'work_order' => 'case_work_order',
                  'project' => 'case_project' }.freeze

  def index
    types = CaseType.ensure_defaults_for(Current.account)
    types = types.where(case_class: params[:case_class]) if CaseType.case_classes.key?(params[:case_class].to_s)
    render json: { case_types: types.map { |t| type_json(t) } }
  end

  def create
    return render_class_error if class_error(type_params[:case_class])

    type = Current.account.case_types.build(type_params)
    type.position ||= Current.account.case_types.count
    if type.save
      render json: { case_type: type_json(type) }, status: :created
    else
      render json: { error: type.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if class_change_requested?
      return render json: { error: 'Para cambiar la clase usa «Cambiar de clase»' },
                    status: :unprocessable_entity
    end

    if @type.update(type_params)
      render json: { case_type: type_json(@type) }
    else
      render json: { error: @type.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /case_types/:id/change_class { case_class }
  # Con casos: crea el tipo en la otra clase y retira este (sus casos se quedan tal
  # cual); sin casos: cambia directo. Ver Cases::TypeClassChange.
  def change_class
    return render json: { error: class_error(params[:case_class]) }, status: :unprocessable_entity if class_error(params[:case_class])

    result = Cases::TypeClassChange.new(@type, params[:case_class]).call
    render json: { case_type: type_json(result.type), retired: result.retired && type_json(result.retired),
                   kept_cases: result.kept_cases, automations: result.automations, rules: result.rules }
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    # Los tickets asociados quedan con case_type_id = null (dependent: :nullify)
    @type.destroy
    head :no_content
  end

  private

  def set_type
    @type = Current.account.case_types.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Tipo no encontrado' }, status: :not_found
  end

  def type_params
    params.require(:case_type).permit(:name, :color, :position, :prefix, :public, :itil_enabled, :case_class,
                                      field_settings: CaseType::FIELD_DEFAULTS.keys) # Plan-Trabajo-Campo R1
  end

  # nil = válida. Comercial y Orden de trabajo solo con su flag en la cuenta.
  def class_error(value)
    return nil if value.blank?
    return 'Clase de caso inválida' unless OFFERED_CLASSES.include?(value.to_s)

    flag = CLASS_FLAGS[value.to_s]
    return 'Esta clase de caso no está activa en esta cuenta' if flag && !Current.account.feature_enabled?(flag)

    nil
  end

  def render_class_error
    render json: { error: class_error(type_params[:case_class]) }, status: :unprocessable_entity
  end

  def class_change_requested?
    new_class = type_params[:case_class]
    new_class.present? && new_class.to_s != @type.case_class
  end

  def type_json(type)
    {
      id: type.id,
      name: type.name,
      prefix: type.prefix,
      # Hoja de ruta E1.4 — con casos el prefijo queda fijo (entra en el folio).
      prefix_locked: type.prefix_locked?,
      color: type.color,
      position: type.position,
      # @tickets_cases — User Portal: visible en el formulario público del cliente.
      public: type[:public],
      # @tickets_cases — modo ITIL propio del tipo (antes era un ajuste global de cuenta).
      itil_enabled: type.itil_enabled,
      field_settings: type.field_settings_effective, # Plan-Trabajo-Campo R1
      # @tickets_cases — clase del tipo (support/commercial/…); el ticket la hereda.
      case_class: type.case_class,
      # Retirado (cambió de clase): conserva sus casos, ya no se usa para crear nuevos.
      retired: type.retired?,
      retired_at: type.retired_at,
      cases_count: cases_counts[type.id] || 0,
      # @tickets_cases 2K — campos personalizados para render dinámico en alta/detalle.
      custom_fields: type.case_type_fields.ordered.map { |f| field_json(f) },
      # @tickets_cases — columnas del Kanban propias del tipo (Opción A+). Viajan
      # aquí para que el tablero no haga un round-trip extra al cargar los tipos.
      columns: type.case_type_columns.ordered.map { |c| column_json(c) },
      created_at: type.created_at,
      updated_at: type.updated_at
    }
  end

  def cases_counts
    @cases_counts ||= CaseTicket.where(account_id: Current.account.id).group(:case_type_id).count
  end

  def field_json(field)
    {
      id: field.id,
      key: field.key,
      label: field.label,
      field_type: field.field_type,
      options: field.options,
      required: field.required,
      position: field.position
    }
  end

  def column_json(column)
    {
      id: column.id,
      label: column.label,
      color: column.color,
      position: column.position,
      statuses: column.statuses
    }
  end
end
