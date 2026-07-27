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
    rows = Instagram::MigrationService.pending

    if rows.empty?
      puts 'No queda ningún inbox con Instagram dentro de un Channel::FacebookPage.'
      next
    end

    puts format('%-8<a>s %-9<b>s %-26<c>s %-30<d>s %<e>s', a: 'INBOX', b: 'CUENTA', c: 'IGSID', d: 'NOMBRE', e: 'CANAL NATIVO')
    rows.each do |row|
      target = row[:native_inbox_id] ? "inbox #{row[:native_inbox_id]}" : "SIN CONECTAR (#{row[:instagram_conversations]} conv. de IG)"
      puts format('%-8<a>s %-9<b>s %-26<c>s %-30<d>s %<e>s',
                  a: row[:inbox_id], b: row[:account_id], c: row[:instagram_id], d: row[:name].to_s.truncate(28), e: target)
    end
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
