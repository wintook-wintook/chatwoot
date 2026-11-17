# frozen_string_literal: true

# «Tickets» — levantar un caso o decir cómo va. Los tipos que puede levantar y cuándo vienen de
# la ficha; no repite un caso abierto de la misma clase (anti-duplicado del 1.0) y corre las
# reglas del caso (Cases::RuleEngineService). Los archivos del tipo salen después
# (ContactTrackings::EventFiles, el del 1.0).
#
#   skills.tickets = { 'on' => true, 'types' => [{ 'case_type_id' => 4, 'when' => 'reporta una falla' }],
#                      'priority' => 'medium' }
class Motor2::Skills::Tickets < Motor2::Skills::Base
  PRIORITIES = %w[low medium high urgent].freeze

  def self.key = 'tickets'

  def on? = super && types.any?

  def tools
    [fn('crear_caso', "Levanta un caso para que el equipo lo atienda. Tipos: #{types.map { |t| "«#{t[:name]}» (#{t[:when]})" }.join('; ')}. " \
                      'Antes pide los datos que hagan falta para atenderlo.',
        { tipo: { type: 'string', enum: types.pluck(:name) }, titulo: STR, descripcion: STR }, %w[tipo titulo descripcion]),
     fn('estado_caso', 'Cómo va el caso abierto del cliente (folio, estado).')]
  end

  def instructions
    '- Casos: levántalo con crear_caso cuando aplique y dale al cliente el folio que te regrese; para «¿cómo va?» usa estado_caso.'
  end

  def call(name, args)
    name == 'estado_caso' ? status : create(args)
  end

  private

  def types
    @types ||= Array(setting(:types)).filter_map do |t|
      t = t.to_h.stringify_keys
      type = config.account.case_types.active.find_by(id: t['case_type_id'])
      { id: type.id, name: type.name, case_class: type.case_class, when: t['when'].presence || 'cuando aplique' } if type
    end
  end

  def orchestrator
    Cases::OrchestratorService.new(account: config.account, contact: @turn.conversation&.contact, conversation: @turn.conversation)
  end

  def status
    return { prueba: true, nota: 'En la prueba no hay casos reales.' } if test?

    ticket = orchestrator.find_active_ticket
    return { nota: 'No tiene casos abiertos.' } unless ticket

    { folio: ticket.try(:folio) || ticket.id, titulo: ticket.title, estado: ticket.status }
  end

  def create(args)
    type = types.find { |t| t[:name] == args['tipo'] }
    return { error: 'Ese tipo de caso no está en la ficha.' } unless type
    return { ok: true, prueba: true, folio: 'PRUEBA-1' } if test?

    existing = orchestrator.find_active_ticket(case_class: type[:case_class])
    return { ya_existe: true, folio: existing.try(:folio) || existing.id, nota: 'Ya tiene ese caso abierto: no levantes otro.' } if existing

    ticket = build(type, args)
    trace.event(:caso, "#{type[:name]}: #{ticket.title}")
    { ok: true, folio: ticket.try(:folio) || ticket.id }
  end

  def build(type, args)
    message = @turn.conversation.messages.incoming.last
    ticket = orchestrator.create_from_ai(message: message, tracking: @turn.tracking, title: args['titulo'].to_s.first(200),
                                         description: args['descripcion'].to_s.first(4000), case_type_id: type[:id],
                                         priority: setting(:priority).presence_in(PRIORITIES))
    state['case_id'] = ticket.id
    @turn.after_send { after_created(ticket, message, type) }
    ticket
  end

  def after_created(ticket, message, type)
    Cases::RuleEngineService.new(ticket, trigger_message: message).evaluate!
    ContactTrackings::EventFiles.send_for(@turn.tracking, :ticket, conversation: @turn.conversation,
                                                                   sender: Motor2::Delivery.sender(config.account), case_type: type[:name])
  end
end
