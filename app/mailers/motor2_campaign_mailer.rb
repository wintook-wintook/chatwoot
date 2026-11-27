# frozen_string_literal: true

# Campaña con Vendedor IA — «Enviarme una prueba»: el correo del toque, a quien lo está armando, para verlo en su
# bandeja antes de lanzar. Va con el remitente del sistema (no por la bandeja de la campaña): no abre conversación.
class Motor2CampaignMailer < ActionMailer::Base # rubocop:disable Rails/ApplicationMailer
  default from: ENV.fetch('MAILER_SENDER_EMAIL', 'Kontrolya <accounts@chatwoot.com>')

  def test_touch(to:, subject:, body:, signature: nil)
    html = ChatwootMarkdownRenderer.new([body, signature.presence].compact.join("\n\n")).render_message
    mail(to: to, subject: "[Prueba] #{subject.presence || 'Correo de tu campaña'}") do |format|
      format.html { render html: html.to_s.html_safe } # rubocop:disable Rails/OutputSafety
    end
  end
end
