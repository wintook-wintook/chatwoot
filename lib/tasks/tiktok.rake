# Tareas de mantenimiento del canal de TikTok.
#
# El registro del webhook es por APLICACIÓN y para toda la instalación, no por cuenta como
# en Meta. Si falta, no llega ni un mensaje y no hay ningún error visible en ninguna parte:
# de ahí que valga la pena tener un comando para hacerlo y otro para comprobarlo.
namespace :tiktok do
  desc 'Comprueba si el canal de TikTok puede funcionar (config, webhook, canales y tokens)'
  task doctor: :environment do
    puts Tiktok::ReadinessService.new.report
  end

  desc 'Registra en TikTok la URL de webhook de esta instalación (idempotente)'
  task register_webhook: :environment do
    url = Tiktok::AuthClient.webhook_url
    puts "Registrando #{url} ..."
    Tiktok::AuthClient.update_webhook_callback
    puts '✔ Registrado. Compruébalo con `rake tiktok:doctor`.'
  rescue Tiktok::AuthClient::TiktokApiError => e
    # Sin abortar con backtrace: el error de TikTok es lo único útil aquí.
    abort "✘ TikTok rechazó el registro: #{e.message}"
  end
end
