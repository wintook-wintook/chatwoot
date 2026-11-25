# frozen_string_literal: true

# «Archivos con regla» — los archivos del agente (ai_agent_attachments) con la misma regla por
# archivo que la ficha 1.0 (tracking_templates.resources['files']):
#   { 'brochure' => { 'about' => 'folleto con los 3 paquetes y sus precios', 'ask' => true, 'welcome' => false,
#                     'attempts' => [2], 'booking' => true, 'tickets' => ['*'], 'interest' => true, 'confirm' => true } }
# «Cuando lo pidan o le sirva» es la herramienta enviar_archivo; con la bienvenida, al agendar y al levantar
# un caso los manda el código; en el intento N, ContactTrackings::AttemptFiles (el del 1.0). Del Vendedor de
# campaña: 'interest' (al mostrar interés, en el relevo) y 'confirm' (al confirmar el evento).
# El modelo no ve la imagen: solo su descripción ('about'), así sabe cuándo sirve y no inventa lo que trae.
# Nunca se manda dos veces el mismo archivo salvo que el cliente lo vuelva a pedir; máximo MAX_PER_MESSAGE.
class Motor2::Skills::Files < Motor2::Skills::Base
  MAX_PER_MESSAGE = 2

  def self.key = 'files'

  def on? = askable.any?

  def tools
    [fn('enviar_archivo', "Manda un archivo al cliente cuando lo pida o le sirva: #{catalog_text}.",
        { nombre: { type: 'string', enum: askable }, reenviar: { type: 'boolean', description: 'Solo si pide que se lo mandes otra vez' } },
        %w[nombre])]
  end

  def instructions
    '- Archivos: mándalos con enviar_archivo (no escribas «te envío la foto» sin usarla). No ves lo que hay dentro: ' \
      'de un archivo di solo lo que dice su descripción. Máximo 2 por mensaje.'
  end

  def call(_name, args)
    name = args['nombre'].to_s
    return { error: "No hay un archivo «#{name}»." } unless askable.include?(name)
    return { ya_enviado: true, nota: 'Ya se lo mandaste: dile que está arriba en la plática.' } if sent?(name) && !args['reenviar']
    return { error: "Ya van #{MAX_PER_MESSAGE} en este mensaje: manda los demás después si los pide." } if full?

    @turn.attach(name) ? { ok: true, nota: 'Se manda junto con tu mensaje.' } : { error: 'No se pudo adjuntar.' }
  end

  # Los nombres con la regla (p. ej. 'interest' o 'confirm') que sí están subidos. source: lo que tiene #file_rules
  # (la Config, que junta los de la campaña y los del vendedor, o el agente).
  def self.with_rule(source, rule, attachments)
    names_where(source) { |r| r[rule.to_s] } & attachments.pluck(:name)
  end

  # Los de una regla («interest», «confirm») que aún no se le mandan, al mensaje de este turno. En correo, los de
  # «interest» ya fueron adjuntos al primer correo (ContactTrackings::AttemptFiles): no se repiten.
  def self.attach_unsent(turn, config, state, rule)
    return [] if rule.to_s == 'interest' && sent_by_email?(turn.tracking)

    names = with_rule(config, rule, config.attachments)
    ids = config.attachments.where(name: names).pluck(:name, :id).to_h
    names.reject { |name| state.files_sent.include?(ids[name]) }.first(MAX_PER_MESSAGE).each { |name| turn.attach(name) }
  end

  def self.sent_by_email?(tracking) = tracking&.inbox&.email? && tracking.attempt_count.to_i.positive?

  # Los archivos que van con la bienvenida (los manda Motor2::Reply).
  def self.welcome_names(template) = names_where(template) { |rule| rule['welcome'] }

  def self.names_where(template, &)
    template.file_rules.select { |_name, rule| yield(rule.to_h) }.keys
  end

  private

  def askable
    @askable ||= self.class.with_rule(config, 'ask', config.attachments)
  end

  # «folleto (los 3 paquetes y sus precios), mapa (cómo llegar al evento)»
  def catalog_text
    rules = config.file_rules
    askable.map { |name| [name, rules.dig(name, 'about').presence].compact.then { |n, a| a ? "#{n} (#{a})" : n } }.join(', ')
  end

  def full? = @turn.attachments.size >= MAX_PER_MESSAGE

  def sent?(name)
    attachment = config.attachments.find_by(name: name)
    attachment && state.files_sent.include?(attachment.id)
  end
end
