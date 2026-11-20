# frozen_string_literal: true

# Campaña con Vendedor IA — las ligas de los correos pasan por /c/:token para contar quién dio clic (los
# líderes dejaron de medir aperturas: los lectores de correo las abren solos). El token va firmado: lleva el
# seguimiento y la liga; no se puede alterar. Public::CampaignClicksController lo registra y redirige.
module TrackingCampaigns::ClickLink
  MARKDOWN = %r{\[([^\]]+)\]\((https?://[^\s)]+)\)}
  BARE = %r{(?<![(\[/])\bhttps?://[^\s<>)\]]+}

  module_function

  def wrap(text, tracking)
    return text if host.blank?

    linked = text.gsub(MARKDOWN) { "[#{Regexp.last_match(1)}](#{tracked(Regexp.last_match(2), tracking)})" }
    linked.gsub(BARE) { |url| url.start_with?(host) ? url : tracked(url, tracking) }
  end

  def tracked(url, tracking) = "#{host}/c/#{verifier.generate([tracking.id, url])}"

  # [tracking_id, url] o nil si el token no es válido.
  def read(token) = verifier.verified(token.to_s)

  def verifier = Rails.application.message_verifier(:campaign_click)

  def host = ENV.fetch('FRONTEND_URL', '').chomp('/')
end
