# frozen_string_literal: true

require 'rails_helper'

# Seguimiento IA — el agente nuevo. OpenAI no se llama: se simulan sus respuestas
# (AiFollowUps::Runner#complete y el embedding de la búsqueda).
RSpec.describe AiFollowUps::Runner do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Mario Pérez') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:follow_up) do
    AiFollowUps::Creator.new(account: account, user: user, conversation: conversation,
                             params: { objective: 'Que confirme la cotización 1520' }).call
  end

  def tool_call(name, args)
    { 'role' => 'assistant', 'content' => nil,
      'tool_calls' => [{ 'id' => "call_#{name}", 'type' => 'function',
                         'function' => { 'name' => name, 'arguments' => args.to_json } }] }
  end

  def answer(text) = { 'role' => 'assistant', 'content' => text }

  def stub_model(*replies)
    allow_any_instance_of(described_class).to receive(:complete).and_return(*replies) # rubocop:disable RSpec/AnyInstance
  end

  def incoming(text)
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: text)
  end

  def agent_messages
    follow_up.messages.where(private: false)
  end

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
  end

  describe 'crear' do
    it 'queda activo, avisa y encola el primer mensaje' do
      expect { follow_up }.to have_enqueued_job(AiFollowUps::RunJob).with(kind_of(Integer), 'scheduled')
      expect(follow_up.status).to eq('active')
      expect(follow_up.next_run_at).to be <= Time.current
    end

    it 'no deja delegar si la conversación ya tiene un seguimiento de siempre activo' do
      template = TrackingTemplate.create!(account: account, name: 'Cobranza', objective: 'cobrar')
      ContactTracking.new(account: account, contact: contact, conversation: conversation, inbox: inbox,
                          tracking_template: template, objective: 'cobrar', status: 'active',
                          scheduled_for: 1.hour.from_now).save!(validate: false)

      expect { follow_up }.to raise_error(ArgumentError, /Cobranza/)
    end

    it 'no deja dos Seguimientos IA vivos en la misma conversación' do
      follow_up
      expect do
        AiFollowUps::Creator.new(account: account, user: user, conversation: conversation,
                                 params: { objective: 'otro' }).call
      end.to raise_error(ArgumentError, /ya tiene/)
    end
  end

  describe 'un turno' do
    it 'escribe el primer mensaje y gasta un intento' do
      stub_model(answer('Hola Mario, ¿pudiste revisar la cotización 1520?'))
      described_class.new(follow_up, trigger: :scheduled).call

      expect(agent_messages.last.content).to eq('Hola Mario, ¿pudiste revisar la cotización 1520?')
      expect(follow_up.reload.attempts).to eq(1)
      expect(follow_up.next_run_at).to be > 23.hours.from_now
    end

    it 'busca en las respuestas predefinidas y contesta; al responder el cliente los intentos vuelven a cero' do
      create(:canned_response, account: account, short_code: 'entrega', content: 'La entrega tarda 3 días.')
      follow_up.update!(attempts: 2)
      incoming('¿Cuánto tarda la entrega?')
      stub_model(tool_call('buscar_respuesta_predefinida', pregunta: 'tiempo de entrega'), answer('La entrega tarda 3 días.'))

      described_class.new(follow_up, trigger: :reply).call

      expect(agent_messages.last.content).to eq('La entrega tarda 3 días.')
      expect(follow_up.reload.attempts).to eq(0)
      expect(follow_up.log.pluck('kind')).to include('canned', 'sent')
    end

    it 'marca cumplido, se despide y avisa con nota privada' do
      incoming('Sí, ya la confirmo, mándame la factura')
      stub_model(tool_call('marcar_cumplido', resumen: 'Confirmó la cotización'), answer('¡Gracias, Mario!'))

      described_class.new(follow_up, trigger: :reply).call

      expect(follow_up.reload.status).to eq('done')
      expect(follow_up.outcome).to eq('Confirmó la cotización')
      expect(agent_messages.last.content).to eq('¡Gracias, Mario!')
      expect(conversation.messages.where(private: true).last.content).to include('cumplió el objetivo')
    end

    it 'programa el siguiente contacto cuando el cliente lo pide' do
      incoming('Háblame el lunes')
      monday = 3.days.from_now.change(hour: 10).in_time_zone(follow_up.zone)
      stub_model(tool_call('programar_siguiente_contacto', cuando: monday.strftime('%Y-%m-%dT%H:%M')),
                 answer('Claro, te escribo el lunes.'))

      described_class.new(follow_up, trigger: :reply).call

      expect(follow_up.reload.next_run_at).to be_within(1.minute).of(monday)
    end

    it 'sin mensaje no envía nada' do
      stub_model(answer(AiFollowUps::Runner::NO_MESSAGE))
      expect { described_class.new(follow_up, trigger: :scheduled).call }.not_to(change(agent_messages, :count))
    end

    it 'se acaba sin respuesta al llegar al tope de intentos' do
      follow_up.update!(attempts: 3)
      stub_model(answer('no debería'))
      described_class.new(follow_up, trigger: :scheduled).call

      expect(follow_up.reload.status).to eq('no_response')
      expect(agent_messages).to be_empty
    end

    it 'se pausa si una persona le escribió al cliente' do
      follow_up
      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing,
                       sender: user, content: 'Yo te atiendo')
      stub_model(answer('no debería'))
      described_class.new(follow_up, trigger: :scheduled).call

      expect(follow_up.reload.status).to eq('paused')
      # Sin caso, el aviso no manda a reanudarlo «desde el caso».
      note = conversation.messages.where(private: true).last.content
      expect(note).to include('en la conversación o en la ficha del contacto')
      expect(note).not_to include('desde el caso')
    end

    it 'si el modelo falla reintenta en 15 minutos sin gastar intento' do
      stub_model(nil)
      described_class.new(follow_up, trigger: :scheduled).call

      expect(follow_up.reload.status).to eq('active')
      expect(follow_up.attempts).to eq(0)
      expect(follow_up.next_run_at).to be_within(1.minute).of(15.minutes.from_now)
    end
  end

  describe 'mensaje del cliente' do
    it 'con Seguimiento IA vivo contesta él, no el agente de siempre' do
      follow_up
      expect { incoming('hola') }.to have_enqueued_job(AiFollowUps::ReplyJob)
      expect(ContactTrackingResponseAnalyzerJob).not_to have_been_enqueued
    end

    it 'sin Seguimiento IA sigue el agente de siempre' do
      expect { incoming('hola') }.to have_enqueued_job(ContactTrackingResponseAnalyzerJob)
      expect(AiFollowUps::ReplyJob).not_to have_been_enqueued
    end
  end
end
