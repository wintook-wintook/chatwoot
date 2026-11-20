# frozen_string_literal: true

require 'rails_helper'

# Función «Atención a clientes» sobre el motor 2.0 (Plan-Motor-Agentes §11.15). OpenAI no se llama:
# se simulan el clasificador (Motor2::Triage), la revisión de evidencia y las respuestas del modelo.
RSpec.describe Motor2::Functions::Customers do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator, name: 'John') }
  let(:support_user) { create(:user, account: account, role: :agent, name: 'Sara Soporte') }
  let(:billing_user) { create(:user, account: account, role: :agent, name: 'Ana Cobranza') }
  let(:seller) { create(:user, account: account, role: :agent, name: 'Víctor Ventas') }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Mario Pérez') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, assignee: nil) }
  let(:areas) do
    { 'support' => { 'on' => true, 'user_id' => support_user.id }, 'admin' => { 'on' => true, 'user_id' => billing_user.id },
      'sales' => { 'on' => true, 'user_id' => seller.id, 'quote' => 'opportunity' } }
  end
  let(:settings) { { 'business_what' => 'Software de facturación', 'areas' => areas } }
  let!(:agent) { save_agent(settings) }

  def save_agent(answers, template: nil, kind: 'customers', name: 'Clientes')
    Motor2::Functions::Form.new(account, { kind: kind, name: name, enabled: true, inbox_ids: [inbox.id], settings: answers },
                                user: admin, template: template).save
  end

  def tool_call(name, args)
    { 'role' => 'assistant', 'content' => nil,
      'tool_calls' => [{ 'id' => "call_#{name}", 'type' => 'function', 'function' => { 'name' => name, 'arguments' => args.to_json } }] }
  end

  def answer(text) = { 'role' => 'assistant', 'content' => text }

  def stub_model(*replies)
    allow_any_instance_of(Motor2::Runner).to receive(:complete).and_return(*replies) # rubocop:disable RSpec/AnyInstance
  end

  def triage(area, **extra)
    result = { 'atender' => { 'area' => area, 'intencion' => extra.delete(:intencion) || 'algo', 'suficiente' => true }.merge(extra.stringify_keys),
               'pendientes' => [] }
    allow_any_instance_of(Motor2::Triage).to receive(:call).and_return(result) # rubocop:disable RSpec/AnyInstance
  end

  def incoming(text)
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: text, sender: contact)
  end

  def reply_to(message) = Motor2::ReplyJob.perform_now(message.id)

  # Ya se sabe de qué empresa es (Motor2::Skills::Identity no pide preguntarlo antes del caso).
  def identified!(name = 'Ferretería Sol') = contact.update!(organization: account.organizations.create!(name: name))

  def tracking = ContactTracking.find_by(conversation_id: conversation.id)

  def tools_for(state = Motor2::State.new, history = [{ role: 'user', content: 'hola' }])
    runner = Motor2::Runner.new(Motor2::Config.new(agent.reload), state: state, history: history)
    skills = Motor2::Skills.for(runner)
    runner.instance_variable_set(:@skills, skills)
    skills.each { |s| s.prepare(history) }
    skills.flat_map(&:tools).map { |t| t.dig(:function, :name) }
  end

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })
    allow_any_instance_of(Motor2::AnswerCheck).to receive_messages(answers?: true, about_business?: true) # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(Motor2::AnswerExtractor).to receive(:call).and_return({}) # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(Motor2::EvidenceCheck).to receive(:call).and_return({ 'veredicto' => 'EXACTA', 'falta' => '' }) # rubocop:disable RSpec/AnyInstance
  end

  it 'se guarda como agente 2.0 de «Atención a clientes» con las áreas de la matriz ya llenas' do
    expect(agent).to have_attributes(engine: '2', agent_function: 'customers', attending: true)
    saved = agent.motor2.dig('answers', 'areas')
    expect(saved['support']).to include('on' => true, 'action' => 'case', 'examples_yes' => include('No puedo enviar una cotización a pedido'))
    expect(saved['sales']).to include('quote' => 'opportunity', 'examples_no' => include('La cotización no se genera'))
    expect(saved['other']).to include('on' => false)
  end

  it 'cada área trae solo sus herramientas; Administrativo no busca en las fuentes y Finish no aplica' do
    create(:canned_response, account: account, short_code: 'horario', content: 'De 9 a 6')
    triage('admin')
    expect(tools_for).to include('canalizar', 'estado_caso')
    expect(tools_for).not_to include('buscar_en_fuentes', 'registrar_gestion', 'objetivo_cumplido', 'descartar', 'pasar_a_humano')
    triage('sales', gestion: 'info')
    expect(tools_for).to include('buscar_en_fuentes', 'registrar_gestion', 'canalizar')
    expect(tools_for).not_to include('crear_caso')
    triage('support')
    expect(tools_for).to include('buscar_en_fuentes', 'crear_caso')
  end

  it 'si falta aclarar: no busca, hace una sola pregunta y la recuerda para el siguiente mensaje (continuidad)' do
    create(:canned_response, account: account, short_code: 'horario', content: 'De 9 a 6')
    triage('sales', suficiente: false, aclaracion: '¿Qué deseas cotizar?', intencion: 'cotización', gestion: 'cotizacion')
    state = Motor2::State.new
    expect(tools_for(state)).not_to include('buscar_en_fuentes')
    expect(state['pendiente']).to include('area' => 'sales', 'aclaracion' => '¿Qué deseas cotizar?')
  end

  it 'si ya se le pidió aclarar y contestó, no pregunta otra vez: busca con lo que hay' do
    create(:canned_response, account: account, short_code: 'horario', content: 'De 9 a 6')
    triage('none', suficiente: false, aclaracion: '¿En qué sistema?', intencion: 'dar de alta un cliente')
    state = Motor2::State.new
    tools_for(state)
    expect(state['pendiente']).to include('intencion' => 'dar de alta un cliente')

    expect(tools_for(state)).to include('buscar_en_fuentes') # sigue «falta aclarar», pero ya se aclaró una vez
    expect(state['triage']).to include('suficiente' => true)
  end

  it 'si el agente preguntó algo (aunque no lo pidiera el clasificador) y contestó, no vuelve a preguntar: busca' do
    create(:canned_response, account: account, short_code: 'alta', content: 'Catálogos › Clientes')
    triage('support', suficiente: false, aclaracion: '¿En qué sistema?', intencion: 'dar de alta un cliente')
    history = [{ role: 'user', content: 'cómo doy de alta un cliente' }, { role: 'assistant', content: '¿En qué sistema estás trabajando?' },
               { role: 'user', content: 'comercial premium' }]
    state = Motor2::State.new
    expect(tools_for(state, history)).to include('buscar_en_fuentes')
    expect(state['triage']).to include('suficiente' => true)
  end

  it 'Soporte: no lo pasa ni levanta el caso sin antes buscar la solución en sus fuentes' do
    create(:canned_response, account: account, short_code: 'alta', content: 'Para dar de alta un cliente ve a Catálogos › Clientes.')
    triage('support', intencion: 'dar de alta un cliente', severidad: 3)
    stub_model(tool_call('canalizar', { motivo: 'alta de cliente' }), answer('Te paso con soporte.'))
    reply_to(incoming('cómo doy de alta un cliente'))

    tools = conversation.messages.outgoing.where(private: false).last.content_attributes.dig('motor2', 'tools')
    expect(tools.first).to include('name' => 'canalizar', 'ok' => false)
    expect(tracking.reload.status).to eq('active') # no se pasó
  end

  it 'Administrativo: canaliza al equipo de esa área, con nota, y el agente se pausa' do
    triage('admin', intencion: 'corregir RFC de una factura')
    stub_model(tool_call('canalizar', { motivo: 'Corregir el RFC de la factura A-1' }),
               answer('Le paso tu solicitud a nuestro equipo administrativo, en cuanto puedan te atienden.'))
    reply_to(incoming('Mi factura tiene mal el RFC'))

    expect(conversation.reload.assignee_id).to eq(billing_user.id)
    expect(tracking.reload.status).to eq('paused')
    expect(conversation.messages.where(private: true).last.content).to include('Administrativo', 'RFC')
  end

  it 'Soporte: pregunta primero; con su respuesta levanta el caso con la prioridad de su severidad y el responsable del área' do
    identified!
    account.case_types.create!(name: 'Soporte', case_class: :support)
    triage('support', severidad: 2, intencion: 'no se genera la cotización')
    stub_model(tool_call('crear_caso', { titulo: 'No se genera la cotización', descripcion: 'Desde ayer' }),
               answer('¿Desde cuándo te pasa?'))
    reply_to(incoming('La cotización no se genera'))
    expect(CaseTicket.where(contact: contact).count).to eq(0) # primero una pregunta

    stub_model(tool_call('crear_caso', { titulo: 'No se genera la cotización', descripcion: 'Desde ayer' }),
               answer('Listo, tu folio es el que te di.'))
    reply_to(incoming('desde ayer'))
    ticket = CaseTicket.find_by(contact: contact)
    expect(ticket).to have_attributes(priority: 'high', assignee_id: support_user.id)
    expect(tracking.reload.motor2_state['case_folio']).to be_present
  end

  it 'Soporte: con el folio manda el instructivo de «al levantar un caso»' do
    account.case_types.create!(name: 'Soporte', case_class: :support)
    create(:ai_agent_attachment, tracking_template: agent, account: account, name: 'instructivo')
    agent.update!(resources: { 'files' => { 'instructivo' => { 'about' => 'Pasos para entrar', 'tickets' => ['*'] } } })
    triage('support', severidad: 1, intencion: 'no abre el sistema')
    stub_model(tool_call('crear_caso', { titulo: 'No abre', descripcion: 'No abre' }), answer('Tu folio es el que te di.'))
    reply_to(incoming('el sistema no abre, no puedo operar'))

    expect(conversation.messages.outgoing.where(private: false).last.attachments.count).to eq(1)
  end

  it 'Comercial: la cotización se registra como oportunidad con el vendedor; no se abre otra si ya tiene una' do
    account.case_types.create!(name: 'Oportunidad', case_class: :commercial)
    triage('sales', gestion: 'cotizacion', intencion: 'cotización de 10 usuarios')
    stub_model(tool_call('registrar_gestion', { tipo: 'cotizacion', detalle: '10 usuarios' }), answer('Listo, tu vendedor te da seguimiento.'))
    reply_to(incoming('Quiero cotización para 10 usuarios'))
    reply_to(incoming('y también para otra sucursal'))

    tickets = CaseTicket.where(contact: contact)
    expect(tickets.count).to eq(1)
    expect(tickets.first).to have_attributes(assignee_id: seller.id)
  end

  it 'no dice que ya levantó el caso si no llamó la herramienta (se reescribe)' do
    triage('support', intencion: 'falla')
    stub_model(answer('Ya levanté tu caso, tu folio es 123.'), answer('¿Desde cuándo te pasa?'))
    reply_to(incoming('No abre el sistema'))
    expect(conversation.messages.outgoing.last.content).to eq('¿Desde cuándo te pasa?')
  end

  it 'pide una persona sin decir para qué: le pregunta una vez y luego lo pasa al equipo del área' do
    triage('none', pide_persona: true)
    stub_model(answer('Con gusto, ¿qué necesitas para pasarte con quien corresponde?'))
    reply_to(incoming('Quiero hablar con una persona'))
    expect(tracking.reload.status).to eq('active')

    triage('admin', intencion: 'factura')
    stub_model(answer('Claro.'), tool_call('canalizar', { motivo: 'factura' }), answer('Te paso con administración.'))
    reply_to(incoming('es por mi factura'))
    expect(conversation.reload.assignee_id).to eq(billing_user.id)
  end

  # Del prompt del Coordinador Kontrolya v5.6: solución exacta tal cual, fuentes reales, RESUELTO / ESCALAR y etiquetas.
  describe 'Soporte con evidencia' do
    let(:link) { 'https://foro.example.com/t/no-se-habilita-el-boton/340' }
    let(:found) do
      [{ fuente: 'Foro', tipo: 'discourse',
         resultados: [{ titulo: 'No se habilita el botón', informacion: '1. Edita el prospecto 2. Clic en "Convertir a Cliente"', liga: link }] }]
    end

    def result_check(tipo, usar: [0])
      allow_any_instance_of(Motor2::ResultCheck).to receive(:call) # rubocop:disable RSpec/AnyInstance
        .and_return({ 'tipo' => tipo, 'usar' => usar, 'motivo' => '', 'pregunta' => '' })
    end

    def last_sent = conversation.messages.outgoing.where(private: false).last

    before do
      create(:canned_response, account: account, short_code: 'alta', content: 'Algo')
      allow_any_instance_of(Motor2::Search).to receive(:call).and_return(found) # rubocop:disable RSpec/AnyInstance
      triage('support', severidad: 2, intencion: 'no se habilita el botón de enviar a pedido')
    end

    it 'con la solución exacta no lo pasa: da los pasos, las fuentes reales y RESUELTO / ESCALAR; deja las etiquetas' do
      result_check('exacta')
      stub_model(tool_call('buscar_en_fuentes', { pregunta: 'botón enviar a pedido' }), tool_call('canalizar', { motivo: 'botón' }),
                 answer("1. Edita el prospecto.\n2. Clic en \"Convertir a Cliente\".\nMás información: #{link}\n¿Te funcionó?"))
      reply_to(incoming('no se habilita el botón de enviar a pedido'))

      text = last_sent.content
      expect(text).to include('Convertir a Cliente', "Fuentes relacionadas:\n- #{link}", 'RESUELTO — si quedó atendido', 'ESCALAR —')
      expect(text.scan(link).size).to eq(1)
      expect(text).not_to include('¿Te funcionó?', 'Más información')
      expect(tracking.reload.status).to eq('active') # canalizar se rechazó: primero la solución
      expect(conversation.reload.label_list).to include('soporte-falla', 'respondida')
      expect(account.labels.find_by(title: 'respondida')).to be_present
    end

    it 'ESCALAR después de la solución: lo pasa ya, sin volver a clasificar ni buscar' do
      result_check('exacta')
      stub_model(tool_call('buscar_en_fuentes', { pregunta: 'botón' }), answer('1. Edita el prospecto.'))
      reply_to(incoming('no se habilita el botón de enviar a pedido'))

      expect_any_instance_of(Motor2::Triage).not_to receive(:call) # rubocop:disable RSpec/AnyInstance
      stub_model(tool_call('canalizar', { motivo: 'Ya convirtió a cliente y sigue igual' }), answer('Te paso con soporte.'))
      reply_to(incoming('ESCALAR'))
      expect(tracking.reload.status).to eq('paused')
      expect(conversation.reload.label_list).to include('canalizada')
    end

    it 'RESUELTO: se despide y la conversación queda con la etiqueta «resuelto»' do
      result_check('exacta')
      stub_model(tool_call('buscar_en_fuentes', { pregunta: 'botón' }), answer('1. Edita el prospecto.'))
      reply_to(incoming('no se habilita el botón de enviar a pedido'))
      stub_model(answer('¡Qué gusto! Aquí estoy para lo que necesites.'))
      reply_to(incoming('ya quedó, gracias'))

      expect(conversation.reload.label_list).to include('resuelto')
      expect(last_sent.content).not_to include('RESUELTO —')
    end

    it 'sin documentación: lo dice, levanta el caso con el servicio que eligió la empresa y queda «sin-respuesta»' do
      identified!
      account.case_types.create!(name: 'Soporte', case_class: :support)
      service = account.case_services.create!(name: 'Integración Microsip')
      save_agent(settings.merge('areas' => areas.deep_merge('support' => { 'action' => 'case', 'details' => false,
                                                                           'default_service_id' => service.id })), template: agent)
      result_check('ninguna', usar: [])
      stub_model(tool_call('buscar_en_fuentes', { pregunta: 'botón' }), tool_call('crear_caso', { titulo: 'Botón', descripcion: 'No se habilita' }),
                 answer('No encontré documentación específica para darte una respuesta segura. Tu folio es el 1.'))
      reply_to(incoming('no se habilita el botón de enviar a pedido'))

      expect(CaseTicket.find_by(contact: contact)).to have_attributes(affected_service_id: service.id)
      expect(conversation.reload.label_list).to include('soporte-falla', 'caso-levantado', 'sin-respuesta')
    end

    it 'no supone causas: «probablemente…» se reescribe' do
      result_check('ninguna', usar: [])
      stub_model(tool_call('buscar_en_fuentes', { pregunta: 'botón' }), answer('Probablemente es tu conexión.'),
                 answer('No encontré documentación específica para darte una respuesta segura sobre este caso.'))
      reply_to(incoming('no se habilita el botón de enviar a pedido'))
      expect(last_sent.content).not_to include('Probablemente')
    end
  end

  # El contacto ya lo crea Kontrolya solo; falta saber de qué empresa es (Motor2::Skills::Identity).
  describe 'lo que comparten los tres agentes' do
    def catalog_item(name, price) = account.catalog_items.create!(name: name, price: price, kind: :product)

    it 'cotizar en borrador: arma la cotización con precios del Catálogo, con su oportunidad, y avisa al vendedor' do
      identified!
      catalog_item('Licencia anual', 5000)
      account.case_types.create!(name: 'Ventas', case_class: :commercial)
      save_agent(settings.merge('quote' => { 'mode' => 'draft' }, 'price_source' => 'catalog', 'areas' => areas), template: agent)
      triage('sales', gestion: 'cotizacion', intencion: 'cotizar licencias')
      stub_model(tool_call('cotizar', { partidas: [{ producto: 'licencia anual', cantidad: 3 }] }), answer('En un momento te la manda tu asesor.'))
      reply_to(incoming('quiero cotización de 3 licencias anuales'))

      quote = account.quotes.last
      expect(quote).to have_attributes(status: 'draft', assignee_id: seller.id)
      expect(quote.items.first).to have_attributes(quantity: 3, unit_price: 5000)
      expect(quote.opportunity).to be_present
      expect(conversation.messages.where(private: true).pluck(:content).join).to include('🧾', quote.folio, 'revísala')
      expect(conversation.reload.label_list).to include('cotizacion')
    end

    it 'cotizar: lo que no está en el Catálogo no se inventa' do
      save_agent(settings.merge('quote' => { 'mode' => 'send' }), template: agent)
      triage('sales', gestion: 'cotizacion')
      stub_model(tool_call('cotizar', { partidas: [{ producto: 'nave espacial' }] }), answer('¿Me dices qué producto es?'))
      reply_to(incoming('cotízame una nave espacial'))
      expect(account.quotes.count).to eq(0)
    end

    it 'seguimiento: si le dio la solución y no contesta, le pregunta si se resolvió y al final queda «resuelto-sin-confirmar»' do
      save_agent(settings.merge('follow_up' => { 'nudges' => 1 }), template: agent)
      triage('support', severidad: 3)
      stub_model(answer("1. Abre Catálogos.\n\nPara avanzar responde:\nRESUELTO — si quedó atendido\nESCALAR — para pasarlo"))
      message = incoming('cómo doy de alta un cliente')
      expect { reply_to(message) }.to have_enqueued_job(Motor2::FollowUpJob).with(kind_of(Integer), message.id, 0)
      tracking.update_columns(motor2_state: tracking.motor2_state.merge('opciones' => true)) # rubocop:disable Rails/SkipsModelValidations

      allow_any_instance_of(Motor2::Attempt).to receive(:message).and_return('¿Se resolvió con los pasos?') # rubocop:disable RSpec/AnyInstance
      expect { Motor2::FollowUpJob.perform_now(tracking.id, message.id, 0) }
        .to have_enqueued_job(Motor2::FollowUpJob).with(tracking.id, message.id, Motor2::FollowUp::END_STEP)
      Motor2::FollowUpJob.perform_now(tracking.id, message.id, Motor2::FollowUp::END_STEP)
      expect(conversation.reload.label_list).to include('resuelto-sin-confirmar')
      expect(Motor2::FollowUp.next_touch(tracking.reload)).to be_nil
    end

    it 'seguimiento: si solo se despidió (sin pregunta), no se le busca' do
      save_agent(settings.merge('follow_up' => { 'nudges' => 2 }), template: agent)
      triage('none')
      stub_model(answer('¡Con gusto! Que tengas buen día.'))
      expect { reply_to(incoming('gracias')) }.not_to have_enqueued_job(Motor2::FollowUpJob)
    end

    it 'al pasarlo a un área arranca el plazo del equipo' do
      save_agent(settings.merge('attend_hours' => 2), template: agent)
      triage('admin', intencion: 'corregir RFC')
      stub_model(tool_call('canalizar', { motivo: 'RFC' }), answer('Te paso con administración.'))
      reply_to(incoming('Mi factura tiene mal el RFC'))
      expect(tracking.reload.handoff_due_at).to be > tracking.handed_off_at
    end

    it 'métricas: por las etiquetas, qué pide y qué se hizo, y el % que resolvió sin pasarlo' do
      conversation.update_labels(%w[soporte-duda respondida])
      other = create(:conversation, account: account, inbox: inbox, contact: create(:contact, account: account))
      other.update_labels(%w[administrativo canalizada])
      [conversation, other].each do |conv|
        ContactTracking.create!(account: account, inbox_id: inbox.id, tracking_template: agent, objective: 'Atender clientes',
                                max_attempts: 1, scheduled_for: 1.day.from_now, contact: conv.contact, conversation: conv)
      end
      metrics = Motor2::AgentMetrics.new(agent).call
      expect(metrics).to include(kind: 'customers', total: 2, rate: 50)
      expect(metrics[:results]).to include('respondida' => 1, 'canalizada' => 1)
      expect(metrics[:groups]).to include('soporte-duda' => 1, 'administrativo' => 1)
    end

    it '«Cómo habla tu empresa»: manda en el prompt, y lo que el agente cambió es solo para él' do
      AgentBase::CompanyVoice.update!(account, { 'tone' => 'Formal, de usted', 'signature' => '— Equipo ACME' })
      save_agent(settings.merge('tone' => 'empresa', 'voice' => { 'signature' => '— Soporte ACME' }), template: agent)
      config = Motor2::Config.new(agent.reload)
      runner = Motor2::Runner.new(config, state: Motor2::State.new, history: [{ role: 'user', content: 'hola' }])
      system = Motor2::Prompt.new(runner, Motor2::Skills.for(runner)).system

      expect(system).to include('ASÍ HABLA LA EMPRESA', 'Formal, de usted', '— Soporte ACME')
      expect(system).not_to include('— Equipo ACME')
      expect(config.tone).to eq('usted')
      expect(runner.trace.events.last['text']).to include('de este agente: Cómo firmar o despedirse')
    end

    it 'los mensajes que arma el código salen con su voz (y sin voz, tal cual)' do
      expect(Motor2::VoiceText.call(Motor2::Config.new(agent.reload), '¡Hola! Te recuerdo tu cita.')).to eq('¡Hola! Te recuerdo tu cita.')
      AgentBase::CompanyVoice.update!(account, { 'signature' => '— Equipo ACME' })
      allow_any_instance_of(Motor2::VoiceText).to receive(:chat).and_return('¡Hola! Te recuerdo tu cita. — Equipo ACME') # rubocop:disable RSpec/AnyInstance
      expect(Motor2::VoiceText.call(Motor2::Config.new(agent.reload), '¡Hola! Te recuerdo tu cita.')).to end_with('— Equipo ACME')
    end

    it 'reglas propias del área y, fuera de su horario, toma lo que necesita sin prometer hora' do
      closed = { 'from' => '00:00', 'to' => '00:01', 'days' => 'all' }
      save_agent(settings.merge('areas' => areas.deep_merge('sales' => { 'rules' => 'Nunca ofrezcas descuentos.', 'hours' => closed })),
                 template: agent)
      triage('sales', gestion: 'info')
      history = [{ role: 'user', content: '¿cuánto cuesta?' }]
      runner = Motor2::Runner.new(Motor2::Config.new(agent.reload), state: Motor2::State.new, history: history)
      skills = Motor2::Skills.for(runner)
      skills.each { |sk| sk.prepare(history) }
      note = skills.find { |sk| sk.key == 'areas' }.turn_note
      expect(note).to include('REGLAS DE COMERCIAL', 'Nunca ofrezcas descuentos.', 'FUERA DEL HORARIO de Comercial (de 00:00 a 00:01')
    end

    it 'Soporte con visita técnica: tiene las herramientas de citas con quien la atiende' do
      save_agent(settings.merge('areas' => areas.deep_merge('support' => { 'action' => 'visit',
                                                                           'appointment_user_ids' => [support_user.id] })), template: agent)
      appointments = Motor2::Config.new(agent.reload).function.appointments
      expect(appointments).to include('on' => true, 'kind' => 'visita', 'user_ids' => [support_user.id])
    end
  end

  describe 'de qué empresa es' do
    before { triage('support', severidad: 2, intencion: 'no carga la factura') }

    it 'con correo de empresa se liga solo a la organización de ese dominio y el agente ve lo que se sabe' do
      org = account.organizations.create!(name: 'Ferretería Sol', email_domain: 'ferresol.mx', stage: :customer)
      service = account.case_services.create!(name: 'Integración Microsip')
      other = create(:contact, account: account, organization: org)
      CaseTicket.create!(account: account, contact: other, title: 'Antes', case_type: account.case_types.create!(name: 'S', case_class: :support),
                         affected_service: service)
      contact.update!(email: 'mario@ferresol.mx')

      expect(Motor2::ClientCheck.client?(contact)).to be(true)
      expect(contact.reload.organization).to eq(org)
      expect(Motor2::CustomerContext.lines(contact).join("\n")).to include('SU EMPRESA: Ferretería Sol (cliente)', 'Integración Microsip')
      runner = Motor2::Runner.new(Motor2::Config.new(agent.reload), state: Motor2::State.new, conversation: conversation)
      expect(Motor2::Skills::Identity.new(runner).tools).to be_empty # ya se sabe: no se le pregunta
    end

    it 'con correo de gmail no adivina; si no se sabe, el agente tiene identificar_empresa' do
      contact.update!(email: 'mario@gmail.com')
      expect(Motor2::CustomerIdentity.by_domain!(contact)).to be_nil
      expect(tools_for).to include('identificar_empresa')
    end

    it 'la empresa que dice: si está en Organizaciones lo liga; si no, la guarda y deja nota al equipo' do
      org = account.organizations.create!(name: 'Ferretería Sol')
      stub_model(tool_call('identificar_empresa', { empresa: 'ferretería sol', correo: 'mario@ferresol.mx' }), answer('Gracias, Mario.'))
      reply_to(incoming('soy de ferretería sol, mario@ferresol.mx'))
      expect(contact.reload).to have_attributes(organization: org, email: 'mario@ferresol.mx')

      other = create(:contact, account: account)
      conv = create(:conversation, account: account, inbox: inbox, contact: other)
      stub_model(tool_call('identificar_empresa', { empresa: 'Abarrotes Luna', correo: 'mario@ferresol.mx' }), answer('Gracias.'))
      Motor2::ReplyJob.perform_now(create(:message, account: account, inbox: inbox, conversation: conv, message_type: :incoming,
                                                    content: 'de abarrotes luna', sender: other).id)
      expect(other.reload.additional_attributes['company_name']).to eq('Abarrotes Luna')
      expect(conv.messages.where(private: true).pluck(:content).join).to include('no está en Organizaciones', 'posible duplicado')
      expect(conv.reload.label_list).to include('empresa-no-encontrada', 'posible-duplicado')
    end

    it 'no levanta el caso sin antes preguntar de qué empresa es (una vez)' do
      account.case_types.create!(name: 'Soporte', case_class: :support)
      save_agent(settings.merge('areas' => areas.deep_merge('support' => { 'action' => 'case', 'details' => false })), template: agent)
      stub_model(tool_call('crear_caso', { titulo: 'Factura', descripcion: 'No carga' }), answer('¿De qué empresa nos escribes?'))
      reply_to(incoming('no carga la factura'))
      expect(CaseTicket.where(contact: contact).count).to eq(0)

      stub_model(tool_call('crear_caso', { titulo: 'Factura', descripcion: 'No carga' }), answer('Tu folio es el 1.'))
      reply_to(incoming('prefiero no decir'))
      expect(CaseTicket.where(contact: contact).count).to eq(1) # ya se le preguntó: no se le insiste
    end
  end

  describe 'una bandeja con los dos agentes' do
    let!(:prospects) do
      save_agent({ 'objective' => 'handoff', 'question_list' => ['¿Qué buscas?'] }, kind: 'prospects', name: 'Prospectos')
    end

    it 'se pueden prender los dos en la misma bandeja (no dos del mismo tipo)' do
      expect(prospects).to be_persisted
      other = account.tracking_templates.new(name: 'Otro', engine: '2', agent_function: 'customers', attending: true,
                                             attend_inbox_ids: [inbox.id], user: admin)
      expect(other).not_to be_valid
    end

    it 'quien ya es cliente va con el de clientes; los demás, con el de prospectos' do
      expect(Motor2::InboxRouter.agent_for(incoming('hola'))).to eq(prospects)
      account.case_types.create!(name: 'Soporte', case_class: :support)
      CaseTicket.create!(account: account, contact: contact, title: 'Ya era cliente', case_type: account.case_types.first)
      expect(Motor2::InboxRouter.agent_for(incoming('hola de nuevo'))).to eq(agent)
    end
  end
end
