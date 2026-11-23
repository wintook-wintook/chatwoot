# frozen_string_literal: true

# Va como `prepend` en Whatsapp::TemplateParamsProcessor (config/initializers/motor2.rb): en un toque de una Campaña
# con Vendedor IA, las variables de la plantilla salen de lo que eligió la campaña (TrackingCampaigns::TemplateVars).
# Sin mapa, o si falta algún dato, se llena como siempre.
module Motor2::CampaignTemplateVarsHook
  def process
    campaign = @tracking&.tracking_campaign
    mapped = campaign&.motor2? && @template ? TrackingCampaigns::TemplateVars.parameters(campaign, @contact, @template) : nil
    mapped || super
  end
end
