# frozen_string_literal: true

# WhatsApp de prueba (no envía): una bandeja de WhatsApp con plantillas aprobadas de ejemplo, para armar y probar
# campañas (plantillas, variables, vista previa, revisión, Simular, Casos, Chatear) sin un número real.
# No manda nada: su token es falso (Meta lo rechaza) y la revisión antes de lanzar no deja lanzar con ella
# (provider_config['sandbox'], TrackingCampaigns::Motor2Check).
#
#   bin/rails "whatsapp:test_inbox[1]"         # la crea o le pone las plantillas al día (cuenta 1)
#   bin/rails "whatsapp:test_inbox:remove[1]"  # la quita
module WhatsappTestInbox
  PHONE = '+5210000000000'
  NAME = 'WhatsApp de prueba (no envía)'

  def self.template(name, category, body, example)
    { 'id' => "test_#{name}", 'name' => name, 'status' => 'APPROVED', 'language' => 'es_MX', 'category' => category,
      'components' => [{ 'type' => 'BODY', 'text' => body, 'example' => { 'body_text' => [example] } }] }
  end

  TEMPLATES = [
    template('invitacion_evento', 'MARKETING',
             'Hola {{1}} 👋 Te invitamos a {{2}} el {{3}}. ¿Te cuento de qué se trata?', ['Mario', 'Expo Industrial', '30 de noviembre']),
    template('recordatorio_evento', 'UTILITY',
             'Hola {{1}}, te recordamos que {{2}} es {{3}}. ¡Te esperamos!', ['Mario', 'Expo Industrial', 'mañana a las 10:00']),
    template('oferta_promocion', 'MARKETING',
             'Hola {{1}} 👋 Tenemos {{2}} con precio especial hasta el {{3}}. ¿Te mando la información?',
             ['Mario', 'Mantenimiento preventivo', '30 de noviembre']),
    template('reactivar_cliente', 'MARKETING',
             'Hola {{1}}, hace tiempo que no sabemos de ti. Tenemos {{2}} para ti. ¿Te interesa?', ['Mario', '20% de descuento']),
    template('encuesta_servicio', 'UTILITY',
             'Hola {{1}}, ¿nos ayudas con 3 preguntas sobre tu servicio? Te toma un minuto.', ['Mario']),
    template('vencimiento_contrato', 'UTILITY',
             'Hola {{1}}, tu {{2}} vence el {{3}}. ¿Te ayudo a renovarlo?', ['Mario', 'póliza anual', '15 de diciembre']),
    template('toque_seguimiento', 'MARKETING',
             '{{1}}, ¿pudiste ver lo que te mandamos de {{2}}?', ['Mario', 'la promoción']),
    template('toque_ultimo', 'MARKETING',
             'Hola {{1}}, es nuestro último mensaje sobre {{2}}. Si te interesa, contéstame aquí.', ['Mario', 'la promoción'])
  ].freeze
end

namespace :whatsapp do
  desc 'Crea (o pone al día) la bandeja «WhatsApp de prueba (no envía)» con plantillas de ejemplo'
  task :test_inbox, [:account_id] => :environment do |_t, args|
    account = Account.find(args[:account_id] || 1)
    channel = Channel::Whatsapp.find_or_initialize_by(account: account, phone_number: WhatsappTestInbox::PHONE)
    channel.assign_attributes(provider: 'whatsapp_cloud', message_templates: WhatsappTestInbox::TEMPLATES,
                              message_templates_last_updated: Time.current,
                              provider_config: { 'api_key' => 'prueba-no-envia', 'phone_number_id' => '0', 'business_account_id' => '0',
                                                 'sandbox' => true })
    new_channel = channel.new_record?
    # Sin validar (no hay número real que revisar con Meta) y sin traer plantillas de Meta al crearla.
    channel.define_singleton_method(:sync_templates) { nil }
    channel.save!(validate: false)
    inbox = channel.inbox || Inbox.new(account: account, channel: channel)
    inbox.name = WhatsappTestInbox::NAME
    inbox.save!(validate: false)
    account.administrators.each { |user| InboxMember.find_or_create_by!(inbox: inbox, user: user) }
    puts "#{new_channel ? 'Creada' : 'Al día'}: «#{inbox.name}» (bandeja #{inbox.id}) con #{WhatsappTestInbox::TEMPLATES.size} plantillas."
  end

  namespace :test_inbox do
    desc 'Quita la bandeja «WhatsApp de prueba (no envía)»'
    task :remove, [:account_id] => :environment do |_t, args|
      channel = Channel::Whatsapp.find_by(account_id: args[:account_id] || 1, phone_number: WhatsappTestInbox::PHONE)
      next puts('No hay bandeja de prueba.') unless channel

      channel.inbox&.destroy!
      channel.reload.destroy! if Channel::Whatsapp.exists?(channel.id)
      puts 'Quitada.'
    end
  end
end
