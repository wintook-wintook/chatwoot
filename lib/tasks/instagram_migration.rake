# Migración de inboxes de Instagram desde la ruta legacy (Channel::FacebookPage) al canal
# nativo. Ver docs/instagram_plan.md §6 F7
#
#   # 1. Ver qué cuentas siguen con Instagram dentro de un inbox de Messenger
#   bundle exec rake instagram:pending
#
#   # 2. Simular la migración de un par concreto (NO cambia nada)
#   bundle exec rake instagram:migrate LEGACY_INBOX_ID=12 NATIVE_INBOX_ID=34
#
#   # 3. Aplicarla de verdad
#   bundle exec rake instagram:migrate LEGACY_INBOX_ID=12 NATIVE_INBOX_ID=34 APPLY=true
#
# El orden correcto es conectar primero la cuenta por Instagram Login y migrar después:
# durante el solapamiento los mensajes llegan por las dos rutas y el dedupe los absorbe.
# Al revés se abre un hueco en el que los DMs no llegan a ningún sitio.
namespace :instagram do
  desc 'Lista los inboxes que todavía sirven Instagram a través de un Channel::FacebookPage'
  task pending: :environment do
    puts Instagram::MigrationService.pending_report
  end

  desc 'Comprueba si la instalación está lista para conectar Instagram. ACCOUNT_ID=n para revisar también el flag'
  task doctor: :environment do
    account = ENV['ACCOUNT_ID'].present? ? Account.find(ENV.fetch('ACCOUNT_ID')) : nil
    puts Instagram::ReadinessService.new(account: account).report
    puts ''
  end

  desc 'Mueve las conversaciones de Instagram del inbox legacy al nativo. Simula salvo que APPLY=true'
  task migrate: :environment do
    apply = ActiveModel::Type::Boolean.new.cast(ENV.fetch('APPLY', false))

    report = Instagram::MigrationService.new(
      legacy_inbox: Inbox.find(ENV.fetch('LEGACY_INBOX_ID')),
      native_inbox: Inbox.find(ENV.fetch('NATIVE_INBOX_ID')),
      apply: apply
    ).perform

    puts apply ? "\n=== MIGRACIÓN APLICADA ===" : "\n=== SIMULACRO (nada se ha modificado) ==="
    report.each { |key, value| puts format('  %-38<key>s %<value>s', key: key, value: value.inspect) }
    puts apply ? "\nHecho. El inbox legacy conserva Messenger y ya no reclama el IGSID." : "\nPara aplicarla, repite añadiendo APPLY=true"
  end
end
