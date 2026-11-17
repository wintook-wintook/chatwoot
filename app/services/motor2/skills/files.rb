# frozen_string_literal: true

# «Archivos con regla» — los archivos del agente (ai_agent_attachments) con la misma regla por
# archivo que la ficha 1.0 (tracking_templates.resources['files']):
#   { 'brochure' => { 'ask' => true, 'welcome' => false, 'attempts' => [2], 'booking' => true, 'tickets' => ['*'] } }
# «Cuando lo pidan» es la herramienta enviar_archivo; con la bienvenida, al agendar y al levantar
# un caso los manda el código; en el intento N, ContactTrackings::AttemptFiles (el del 1.0).
# Nunca se manda dos veces el mismo archivo salvo que el cliente lo vuelva a pedir.
class Motor2::Skills::Files < Motor2::Skills::Base
  MAX_PER_MESSAGE = 5

  def self.key = 'files'

  def on? = askable.any?

  def tools
    [fn('enviar_archivo', "Manda un archivo al cliente cuando lo pida o le sirva: #{askable.join(', ')}.",
        { nombre: { type: 'string', enum: askable }, reenviar: { type: 'boolean', description: 'Solo si pide que se lo mandes otra vez' } },
        %w[nombre])]
  end

  def instructions
    '- Archivos: mándalos con enviar_archivo (no escribas «te envío el archivo» sin usarla).'
  end

  def call(_name, args)
    name = args['nombre'].to_s
    return { error: "No hay un archivo «#{name}»." } unless askable.include?(name)
    return { ya_enviado: true, nota: 'Ya se lo mandaste: dile que está arriba en la plática.' } if sent?(name) && !args['reenviar']

    @turn.attach(name) ? { ok: true, nota: 'Se manda junto con tu mensaje.' } : { error: 'No se pudo adjuntar.' }
  end

  # Los archivos que van con la bienvenida (los manda Motor2::Reply).
  def self.welcome_names(template) = names_where(template) { |rule| rule['welcome'] }

  def self.names_where(template, &)
    template.file_rules.select { |_name, rule| yield(rule.to_h) }.keys
  end

  private

  def askable
    @askable ||= self.class.names_where(config.template) { |rule| rule['ask'] } &
                 config.template.ai_agent_attachments.pluck(:name)
  end

  def sent?(name)
    attachment = config.template.ai_agent_attachments.find_by(name: name)
    attachment && state.files_sent.include?(attachment.id)
  end
end
