# frozen_string_literal: true

# proyecto@automatizacion_campanas — los parámetros de una campaña CONTINUA, al crearla o al
# modificarla mientras está Guardada (Api::V1::Accounts::TrackingCampaignsController).
module TrackingCampaignContinuousParams
  extend ActiveSupport::Concern

  private

  def continuous_template
    template = Current.account.tracking_templates.find_by(id: params[:tracking_template_id])
    return [nil, 'Plantilla no encontrada'] unless template
    return [nil, "La plantilla '#{template.name}' no tiene un inbox configurado."] if template.inbox_id.blank?

    error = TrackingCampaigns::ProspectingRules.error_for(purpose: purpose_param, daily_cap: params[:daily_cap],
                                                          email_subject: params[:email_subject], inbox: template.inbox)
    error ? [nil, error] : [template]
  end

  # Sin inicio = desde ahora. Con inicio futuro nace Programada (la abre WindowJob).
  def continuous_attributes(template)
    starts = parse_time(params[:scheduled_for]) || Time.current
    {
      name: params[:name].to_s.strip, tracking_template: template, inbox_id: template.inbox_id,
      objective: template.objective, mode: 'continuous', scheduled_for: starts,
      # launch=false → Guardada: no acepta inscripciones hasta que la pongan en curso.
      status: ActiveModel::Type::Boolean.new.cast(params.fetch(:launch, true)) ? TrackingCampaign.status_for(starts) : 'saved'
    }.merge(window_attributes, subject_test_attributes)
  end

  def window_attributes
    {
      ends_at: parse_time(params[:ends_at]),
      entry_delay_minutes: params[:entry_delay_minutes].presence&.to_i || 0,
      # prospeccion V3: en Prospección siempre días hábiles y horario de atención
      respect_working_hours: purpose_param == 'prospecting' || ActiveModel::Type::Boolean.new.cast(params.fetch(:respect_working_hours, true)),
      daily_cap: params[:daily_cap].presence&.to_i,
      email_subject: params[:email_subject].to_s.strip.presence, # prospeccion F1
      purpose: purpose_param # prospeccion V0
    }
  end

  # prospeccion P3: el asunto B de la prueba A/B, solo en Prospección.
  def subject_test_attributes
    { email_subject_b: purpose_param == 'prospecting' ? params[:email_subject_b].to_s.strip.presence : nil }
  end

  # prospeccion V0: seguimiento por omisión si no viene o no se reconoce.
  def purpose_param
    TrackingCampaign::PURPOSES.include?(params[:purpose].to_s) ? params[:purpose].to_s : 'follow_up'
  end

  def parse_time(value)
    value.present? ? Time.zone.parse(value.to_s) : nil
  rescue ArgumentError, TypeError
    nil
  end
end
