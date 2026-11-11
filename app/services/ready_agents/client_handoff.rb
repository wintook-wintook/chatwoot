# frozen_string_literal: true

# Agentes listos — a quien ya es cliente no lo atiende como prospecto: le contesta una vez
# («te comunico con Ana, en un momento te escribe»), se lo pasa a su responsable fijo (o a
# quien se eligió al activar), deja una nota y se hace a un lado. No entra al embudo.
class ReadyAgents::ClientHandoff
  def initialize(session)
    @session = session
    @agent = session.ready_agent
    @conversation = session.conversation
    @contact = @conversation.contact
  end

  def call
    sender = ReadyAgents::ClientHandoff.sender(@agent)
    outcomes = ReadyAgents::Outcomes.new(@session, sender: sender)
    outcomes.assign_client
    who = @conversation.reload.assignee&.name
    send_message(sender, greeting(who))
    outcomes.note("Es cliente#{" (#{@contact.organization.name})" if @contact&.organization}: se pasó a #{who || 'una persona del equipo'}.")
    @session.finish!('client', who)
  end

  # A nombre de quién salen los mensajes del agente (WhatsApp muestra el nombre del agente).
  def self.sender(agent)
    agent.created_by || agent.account.administrators.first || agent.account.users.first
  end

  private

  def greeting(who)
    name = @contact&.name.to_s.split.first
    hello = name.present? ? "¡Hola #{name}!" : '¡Hola!'
    with = who.present? ? "con #{who.split.first}" : 'con alguien de nuestro equipo'
    "#{hello} Te comunico #{with}, #{off_hours? ? 'te escribe en cuanto abramos' : 'en un momento te escribe'}."
  end

  def off_hours?
    inbox = @conversation.inbox
    inbox.respond_to?(:out_of_office?) && inbox.out_of_office?
  end

  def send_message(sender, text)
    message = Messages::MessageBuilder.new(sender, @conversation,
                                           { content: text, private: false, ai_agent: { name: @agent.name } }).perform
    message.content_attributes[:ready_agent_session_id] = @session.id
    message.save!
  end
end
