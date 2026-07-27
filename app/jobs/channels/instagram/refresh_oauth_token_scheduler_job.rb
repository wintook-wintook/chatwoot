# Los tokens de larga duración de Instagram caducan a los 60 días. Meta exige renovarlos
# antes de que venzan (y con al menos 24 h de vida), así que se actúa con margen: no se
# espera al último día. Ver docs/instagram_plan.md §4
class Channels::Instagram::RefreshOauthTokenSchedulerJob < ApplicationJob
  queue_as :low

  def perform
    # Los de expires_at nulo entran también: si Meta no informó la duración, no sabemos
    # cuándo caducan y dejarlos fuera sería condenarlos a morir en silencio a los 60 días.
    Channel::Instagram.where('expires_at <= ? OR expires_at IS NULL', Channel::Instagram::TOKEN_REFRESH_THRESHOLD.from_now)
                      .limit(Limits::BULK_EXTERNAL_HTTP_CALLS_LIMIT)
                      .each do |channel|
      Channels::Instagram::RefreshOauthTokenJob.perform_later(channel)
    end
  end
end
