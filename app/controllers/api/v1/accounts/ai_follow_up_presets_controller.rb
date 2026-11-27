# frozen_string_literal: true

# Plantillas de seguimiento — la receta de un Seguimiento IA para volver a usarla al delegar.
#   GET    …/ai_follow_up_presets            → las de la cuenta (con editable)
#   POST   …/ai_follow_up_presets            { name, objective, instructions, max_attempts, interval_value,
#                                              interval_unit, on_finish, template_name, template_language }
#   PATCH  …/ai_follow_up_presets/:id        (quien la creó o un administrador)
#   DELETE …/ai_follow_up_presets/:id        (quien la creó o un administrador)
class Api::V1::Accounts::AiFollowUpPresetsController < Api::V1::Accounts::BaseController
  before_action :set_preset, only: %i[update destroy]
  before_action :check_editable, only: %i[update destroy]

  def index
    render json: { payload: Current.account.ai_follow_up_presets.ordered.map { |preset| preset_json(preset) } }
  end

  def create
    preset = Current.account.ai_follow_up_presets.create!(preset_params.merge(created_by: current_user))
    render json: { payload: preset_json(preset) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def update
    @preset.update!(preset_params)
    render json: { payload: preset_json(@preset) }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def destroy
    @preset.destroy!
    head :no_content
  end

  private

  def set_preset
    @preset = Current.account.ai_follow_up_presets.find(params[:id])
  end

  def check_editable
    return if @preset.editable_by?(current_user, access_grant)

    render json: { error: I18n.t('ai_follow_up_presets.not_editable') }, status: :forbidden
  end

  def preset_params
    params.permit(:name, *AiFollowUpPreset::FIELDS)
  end

  def preset_json(preset)
    { id: preset.id, name: preset.name, summary: preset.summary, created_by: preset.created_by&.name,
      editable: preset.editable_by?(current_user, access_grant), updated_at: preset.updated_at }.merge(preset.fields)
  end
end
