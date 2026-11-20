# frozen_string_literal: true

# Campaña con Vendedor IA — el correo del toque que escribió la empresa en la campaña (touches['emails'][n]):
# sale tal cual, con {{contacto}} (primer nombre) y {{empresa}} llenos y las ligas con conteo de clics
# (TrackingCampaigns::ClickLink). nil si no es una campaña 2.0 de correo o ese toque no trae texto: entonces lo
# escribe el agente (Motor2::Attempt). Lo usa Motor2::AttemptHook; la firma la pone ContactTrackingJob.
module Motor2::CampaignTouch
  module_function

  def text(tracking)
    campaign = tracking.tracking_campaign
    return unless campaign&.motor2? && tracking.inbox&.email?

    body = TrackingCampaigns::Motor2Brief.email_body(campaign, tracking.attempt_count + 1)
    body && TrackingCampaigns::ClickLink.wrap(fill(body, tracking.contact), tracking)
  end

  def fill(body, contact)
    first = contact&.name.to_s.strip.split(/\s+/).first.to_s
    attrs = contact&.additional_attributes || {}
    company = (attrs['company_name'].presence || attrs['company'].presence).to_s.strip
    body.gsub(/\{\{\s*contacto\s*\}\}/i, first).gsub(/\{\{\s*empresa\s*\}\}/i, company).gsub(/[ \t]+([,.;:!?])/, '\1')
  end
end
