# frozen_string_literal: true

# GET /c/:token — un clic en una liga de un correo de campaña (TrackingCampaigns::ClickLink): se registra y
# se manda a la liga. Token inválido → la página principal.
class Public::CampaignClicksController < PublicController
  def show
    tracking_id, url = TrackingCampaigns::ClickLink.read(params[:token])
    tracking = ContactTracking.find_by(id: tracking_id) if tracking_id
    return redirect_to(ENV.fetch('FRONTEND_URL', '/'), allow_other_host: true) unless tracking && url.to_s.match?(%r{\Ahttps?://})

    record(tracking, url)
    redirect_to url, allow_other_host: true
  end

  private

  def record(tracking, url)
    return unless tracking.tracking_campaign_id

    TrackingCampaignClick.create!(account_id: tracking.account_id, tracking_campaign_id: tracking.tracking_campaign_id,
                                  contact_tracking_id: tracking.id, contact_id: tracking.contact_id, url: url.first(2000),
                                  created_at: Time.current)
  rescue StandardError => e
    Rails.logger.warn("[CampaignClicks] #{e.class}: #{e.message}")
  end
end
