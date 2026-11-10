# frozen_string_literal: true

require 'rails_helper'

# Asistente (Dali) — conversación, propuestas que esperan «Confirmar» y su ejecución.
# OpenAI no se llama: se simulan sus respuestas (Assistant::Chat#complete).
RSpec.describe 'Assistant API' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account, name: 'Mario Pérez') }
  let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:ticket)  { CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: soporte) }
  let(:base)    { "/api/v1/accounts/#{account.id}/assistant" }

  def tool_call(name, args)
    { 'role' => 'assistant', 'content' => nil,
      'tool_calls' => [{ 'id' => "call_#{name}", 'type' => 'function',
                         'function' => { 'name' => name, 'arguments' => args.to_json } }] }
  end

  def answer(text) = { 'role' => 'assistant', 'content' => text }

  def stub_model(*replies)
    allow_any_instance_of(Assistant::Chat).to receive(:complete).and_return(*replies) # rubocop:disable RSpec/AnyInstance
  end

  def say(content, context = {}, user = admin)
    post "#{base}/messages", params: { content: content, context: context, tz: 'America/Mexico_City' },
                             headers: user.create_new_auth_token, as: :json
  end

  it 'se llama Dali si la cuenta no le puso nombre, y el administrador lo cambia' do
    get base, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['name']).to eq('Dali')

    patch "#{base}/settings", params: { name: 'Lupita' }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['name']).to eq('Lupita')
    expect(Assistant::Settings.name_for(account.reload)).to eq('Lupita')
  end

  it 'un agente no cambia el nombre' do
    create(:account_user, account: account, user: agent) unless agent.account_users.exists?(account: account)
    patch "#{base}/settings", params: { name: 'Otro' }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it 'contesta y guarda el turno' do
    stub_model(answer('Hola, ¿en qué te ayudo?'))
    say('hola')

    expect(response).to have_http_status(:ok)
    thread = AssistantThread.last
    expect(thread.messages.pluck('role')).to eq(%w[user assistant])
    expect(thread.messages.last['content']).to eq('Hola, ¿en qué te ayudo?')
  end

  it 'busca con lo que el usuario puede ver y le pasa el resultado al modelo' do
    ticket
    stub_model(tool_call('search', query: 'Mario'), answer('Encontré a Mario Pérez.'))
    say('busca a Mario')

    expect(response.parsed_body.dig('message', 'content')).to eq('Encontré a Mario Pérez.')
  end

  describe 'propuestas' do
    def propose(name, args, context = { case_id: ticket.id })
      stub_model(tool_call(name, args), answer('Revísalo y confirma.'))
      say('hazlo', context)
      response.parsed_body.dig('message', 'proposals', 0)
    end

    def confirm(proposal, payload = {})
      post "#{base}/proposals/#{proposal['id']}/confirm", params: { payload: payload, tz: 'America/Mexico_City' },
                                                          headers: admin.create_new_auth_token, as: :json
    end

    it 'una nota en el caso no se hace hasta confirmar, y queda «vía asistente»' do
      proposal = propose('propose_note', case_id: ticket.id, content: 'Llamó para reclamar')
      expect(proposal).to include('type' => 'note', 'status' => 'pending')
      expect(ticket.case_events.internal_note).to be_empty

      confirm(proposal)
      expect(response).to have_http_status(:ok)
      note = ticket.case_events.internal_note.last
      expect(note.payload).to include('content' => 'Llamó para reclamar', 'via' => 'assistant')
      expect(response.parsed_body.dig('proposal', 'status')).to eq('done')
    end

    it 'la tarea toma la hora local y lo que el usuario cambió en la tarjeta' do
      proposal = propose('propose_task', case_id: ticket.id, title: 'Llamar', due_at: '2030-01-10T09:00')
      expect(proposal.dig('payload', 'due_at')).to eq('2030-01-10T09:00:00-06:00')

      confirm(proposal, title: 'Llamar a Mario')
      task = ticket.case_tasks.last
      expect(task.title).to eq('Llamar a Mario')
      expect(task.due_at).to eq(Time.utc(2030, 1, 10, 15, 0))
      expect(task.assignee).to eq(admin)
    end

    it 'la tarea agendada pasa por el alta de la agenda' do
      proposal = propose('propose_meeting', contact_id: contact.id, title: 'Llamada', starts_at: '2030-01-10T10:00')
      expect(proposal.dig('payload', 'ends_at')).to eq('2030-01-10T10:30:00-06:00')

      expect { confirm(proposal) }.to change(CaseMeeting, :count).by(1)
      expect(CaseMeeting.last).to have_attributes(contact_id: contact.id, organizer_id: admin.id)
    end

    it 'programa un mensaje en una conversación del cliente' do
      conversation = create(:conversation, account: account, contact: contact)
      proposal = propose('propose_scheduled_message',
                         conversation_id: conversation.display_id, content: 'Hola', send_at: '2030-01-10T10:00')

      expect { confirm(proposal) }.to change(ScheduledMessage, :count).by(1)
    end

    it 'no confirma dos veces ni algo cancelado' do
      proposal = propose('propose_note', case_id: ticket.id, content: 'x')
      post "#{base}/proposals/#{proposal['id']}/cancel", headers: admin.create_new_auth_token, as: :json
      confirm(proposal)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(ticket.case_events.internal_note).to be_empty
    end

    it 'rechaza una tarea en un caso cerrado' do
      proposal = propose('propose_task', case_id: ticket.id, title: 'Algo')
      ticket.update_columns(status: CaseTicket.statuses[:closed]) # rubocop:disable Rails/SkipsModelValidations
      confirm(proposal)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(ticket.case_tasks).to be_empty
    end

    it 'sin fecha válida no propone la cita y se lo dice al modelo' do
      stub_model(tool_call('propose_meeting', contact_id: contact.id, title: 'Llamada'), answer('¿A qué hora?'))
      say('agéndale')

      expect(response.parsed_body.dig('message', 'proposals')).to be_empty
    end
  end

  # D3 — delegar el seguimiento a un agente IA hablando.
  describe 'delegar' do
    let(:conversation) { create(:conversation, account: account, contact: contact) }
    let(:agent) do
      create(:tracking_template, account: account, name: 'Cobranza', objective: 'Que pague la factura pendiente',
                                 ai_context: 'Eres amable.', retry_interval_value: 2, retry_interval_unit: 'days')
    end

    before do
      ticket.update!(conversation: conversation)
      agent
    end

    def delegate_proposal(args = {})
      stub_model(tool_call('propose_delegate', { agent_id: agent.id, case_id: ticket.id }.merge(args)),
                 answer('Revísalo y confirma.'))
      say('dale seguimiento hasta que pague', case_id: ticket.id)
      response.parsed_body.dig('message', 'proposals', 0)
    end

    def confirm(proposal, payload = {})
      post "#{base}/proposals/#{proposal['id']}/confirm", params: { payload: payload, tz: 'America/Mexico_City' },
                                                          headers: admin.create_new_auth_token, as: :json
    end

    it 'lista los agentes para la conversación del caso' do
      stub_model(tool_call('list_agents', case_id: ticket.id), answer('Tienes a Cobranza.'))
      say('¿qué agentes tengo?', case_id: ticket.id)

      expect(response.parsed_body.dig('message', 'content')).to eq('Tienes a Cobranza.')
    end

    it 'propone con la conversación del caso y lo que trae el agente; confirmado crea el seguimiento ligado al caso' do
      proposal = delegate_proposal(objective: 'Que mande la orden de compra', instruction: 'Menciona la cotización 12')
      expect(proposal['payload']).to include('conversation_id' => conversation.display_id, 'interval_value' => 2,
                                             'interval_unit' => 'days', 'max_attempts' => 3)
      expect(proposal.dig('labels', 'agent')).to eq('Cobranza')
      expect(ContactTracking.where(account_id: account.id)).to be_empty

      expect { confirm(proposal, max_attempts: 5) }.to change(ContactTracking, :count).by(1)
      tracking = ContactTracking.where(account_id: account.id).last
      expect(tracking).to have_attributes(tracking_template_id: agent.id, conversation_id: conversation.id,
                                          inbox_id: conversation.inbox_id, max_attempts: 5,
                                          objective: 'Que mande la orden de compra', status: 'pending')
      expect(tracking.ai_context).to include('Eres amable.', 'Menciona la cotización 12')
    end

    it 'liga el seguimiento al caso y lo anota en su bitácora «vía asistente»' do
      confirm(delegate_proposal)

      expect(ticket.reload.contact_tracking).to eq(ContactTracking.where(account_id: account.id).last)
      expect(ticket.case_events.tracking_triggered.last.payload).to include('agent' => 'Cobranza', 'via' => 'assistant')
    end

    it 'el detalle del caso dice a quién está delegado' do
      confirm(delegate_proposal)
      get "/api/v1/accounts/#{account.id}/case_tickets/#{ticket.id}", headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body.dig('case_ticket', 'delegation')).to include('agent' => 'Cobranza', 'status' => 'pending')
    end

    it 'pausa y cancela un seguimiento con confirmación' do
      confirm(delegate_proposal)
      tracking = ContactTracking.where(account_id: account.id).last
      stub_model(tool_call('propose_tracking_action', tracking_id: tracking.id, action: 'pause'), answer('Confirma.'))
      say('páusalo', case_id: ticket.id)
      confirm(response.parsed_body.dig('message', 'proposals', 0))

      expect(tracking.reload).to be_paused
    end

    it 'no propone un agente de otra bandeja' do
      other_inbox = create(:inbox, account: account)
      agent.update_columns(inbox_id: other_inbox.id) # rubocop:disable Rails/SkipsModelValidations
      proposal = delegate_proposal

      expect(proposal).to be_nil
    end
  end

  # D4 — casos y clientes hablando.
  describe 'casos y clientes' do
    let(:venta) { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
    let!(:lost_reason) { CaseOutcomeReason.ensure_defaults_for(account).find_by(outcome: :lost, label: 'Precio') }
    let(:opp) do
      CaseTicket.create!(account: account, title: 'Licencias', contact: contact, case_type: venta, status: :in_progress)
    end

    def propose(name, args)
      stub_model(tool_call(name, args), answer('Revísalo y confirma.'))
      say('hazlo', case_id: opp.id)
      response.parsed_body.dig('message', 'proposals', 0)
    end

    def confirm(proposal, payload = {})
      post "#{base}/proposals/#{proposal['id']}/confirm", params: { payload: payload, tz: 'America/Mexico_City' },
                                                          headers: admin.create_new_auth_token, as: :json
    end

    it 'crea una oportunidad con monto para el contacto' do
      proposal = propose('propose_create_case', case_type_id: venta.id, contact_id: contact.id, title: 'Renovación',
                                                amount: 15_000, currency: 'MXN')
      expect { confirm(proposal) }.to change { CaseTicket.where(account_id: account.id).count }.by(1)

      created = CaseTicket.where(account_id: account.id).order(:id).last
      expect(created).to have_attributes(title: 'Renovación', contact_id: contact.id, case_type_id: venta.id, assignee_id: admin.id)
      expect(created.amount.to_i).to eq(15_000)
    end

    it 'mueve de etapa dentro del mismo estado y lo anota' do
      target = venta.case_type_columns.where(outcome: nil).where.not(id: opp.case_type_column_id)
                    .find { |c| c.statuses.include?('in_progress') }
      confirm(propose('propose_move_stage', case_id: opp.id, column_id: target.id))

      expect(opp.reload.case_type_column_id).to eq(target.id)
      expect(opp.case_events.column_changed.last.payload).to include('via' => 'assistant')
    end

    it 'no mueve a una etapa de resultado: eso es ganar/perder' do
      result = venta.case_type_columns.where.not(outcome: nil).first
      expect(propose('propose_move_stage', case_id: opp.id, column_id: result.id)).to be_nil
    end

    it 'cierra como perdida con su motivo y conserva las tareas pendientes sin caso' do
      task = opp.case_tasks.create!(account: account, title: 'Llamar')
      proposal = propose('propose_outcome', case_id: opp.id, outcome: 'lost', reason_id: lost_reason.id)
      expect(proposal.dig('labels', 'pending')).to eq(1)

      confirm(proposal)
      expect(opp.reload).to have_attributes(status: 'closed', outcome: 'lost', outcome_reason_id: lost_reason.id)
      expect(task.reload).to have_attributes(case_ticket_id: nil, status: 'pending')
    end

    it 'pospone y retoma' do
      reason = account.case_outcome_reasons.outcome_postponed.enabled.first
      confirm(propose('propose_postpone', case_id: opp.id, until: 1.month.from_now.to_date.iso8601, reason_id: reason&.id))
      expect(opp.reload).to be_postponed

      confirm(propose('propose_resume_case', case_id: opp.id))
      expect(opp.reload).not_to be_postponed
    end

    it 'marca comprometida con la fecha que prometió el cliente' do
      date = 10.days.from_now.to_date.iso8601
      confirm(propose('propose_update_opportunity', case_id: opp.id, committed: true, expected_close_at: date))

      expect(opp.reload).to be_committed
      expect(opp.expected_close_at.to_s).to eq(date)
    end

    it 'da de alta un contacto' do
      proposal = propose('propose_create_contact', name: 'Ana Ruiz', email: 'ana@example.com')
      expect { confirm(proposal) }.to change { account.contacts.count }.by(1)
      expect(account.contacts.last.email).to eq('ana@example.com')
    end

    it 'no propone cambios en un caso cerrado' do
      opp.update_columns(status: CaseTicket.statuses[:closed]) # rubocop:disable Rails/SkipsModelValidations
      expect(propose('propose_postpone', case_id: opp.id, until: 1.month.from_now.to_date.iso8601)).to be_nil
    end
  end

  describe 'ventas (D5a)' do
    let(:venta) { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
    let(:seller) { create(:user, account: account, role: :agent, name: 'Luis Vendedor') }

    def won(user, amount)
      deal = CaseTicket.create!(account: account, title: 'Trato', contact: contact, case_type: venta, assignee: user)
      deal.update_columns(amount: amount, currency: 'MXN', outcome: CaseTicket.outcomes[:won], outcome_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end

    before do
      won(admin, 80_000)
      won(seller, 20_000)
      SalesBudgetLine.create!(account: account, user: admin, period: Time.zone.today.beginning_of_month, amount: 100_000)
    end

    it '«¿cómo vamos?» trae la tarjeta de datos y preguntas para seguir; explica con el modelo de análisis' do
      account.update!(custom_attributes: { 'assistant_analysis_model' => 'gpt-4o' })
      models = []
      replies = [tool_call('sales_overview', period: 'this_month'), answer('Van al 80 %.')]
      allow_any_instance_of(Assistant::Chat).to receive(:complete) do |chat, _messages| # rubocop:disable RSpec/AnyInstance
        models << chat.send(:model)
        replies.shift
      end

      say('¿cómo vamos este mes?')

      message = AssistantThread.last.messages.last
      tiles = message['cards'].first['tiles'].to_h { |t| [t['label'], t['value']] }
      expect(tiles).to include('Achieved' => 100_000.0, 'Target' => 100_000.0, 'Progress' => 100.0)
      expect(message['suggestions'].size).to eq(3)
      expect(models).to eq([Assistant::Settings.model_for(account), 'gpt-4o'])
    end

    it 'el vendedor con «solo lo suyo» solo obtiene lo suyo aunque pregunte por otro' do
      role = AccessRole.for_account(account).find { |r| r.key == 'seller' }
      account.account_users.find_by(user: seller).update!(access_role: role)
      stub_model(tool_call('sales_breakdown', dimension: 'seller'), answer('Tu ranking.'))

      say('¿quién vende más?', {}, seller)

      rows = AssistantThread.last.messages.last['cards'].first['table']['rows']
      expect(rows.map { |r| r.first['value'] }).to eq(['Luis Vendedor'])
    end

    it 'sin acceso a Ventas le dice al modelo que no puede' do
      role = AccessRole.for_account(account).find { |r| r.key == 'technician' }
      account.account_users.find_by(user: seller).update!(access_role: role)
      stub_model(tool_call('sales_overview', {}), answer('No tienes acceso.'))

      say('¿cómo vamos?', {}, seller)

      expect(AssistantThread.last.messages.last['cards']).to eq([])
    end

    it 'el administrador elige los modelos; uno fuera de la lista se rechaza' do
      patch "#{base}/settings", params: { model: 'gpt-4.1-mini', analysis_model: 'gpt-4o' }, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['models']).to include('model' => 'gpt-4.1-mini', 'analysis_model' => 'gpt-4o')
      expect(Assistant::Settings.model_for(account.reload, :analysis)).to eq('gpt-4o')

      patch "#{base}/settings", params: { model: 'gpt-x' }, headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'alcance según el rol' do
    let(:seller) { create(:user, account: account, role: :agent) }

    def prompt_for(user)
      prompts = []
      allow_any_instance_of(Assistant::Chat).to receive(:complete) do |_chat, messages| # rubocop:disable RSpec/AnyInstance
        prompts << messages.first[:content]
        answer('Te ayudo con…')
      end
      say('¿en qué me puedes ayudar?', {}, user)
      prompts.first
    end

    it 'con Ventas, el alcance y los ejemplos incluyen ventas' do
      expect(prompt_for(admin)).to include(I18n.t('assistant.capabilities.sales'), I18n.t('assistant.capabilities.limits'))

      get base, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['starters']).to include(I18n.t('assistant.starters.sales_month'))
    end

    it 'sin Ventas no se le ofrece; con «solo lo suyo», sus números' do
      role = AccessRole.for_account(account).find { |r| r.key == 'technician' }
      account.account_users.find_by(user: seller).update!(access_role: role)
      prompt = prompt_for(seller)
      expect(prompt).not_to include(I18n.t('assistant.capabilities.sales'))
      expect(prompt).not_to include(I18n.t('assistant.capabilities.sales_own'))
      get base, headers: seller.create_new_auth_token, as: :json
      expect(response.parsed_body['starters']).not_to include(I18n.t('assistant.starters.sales_month'))

      role = AccessRole.for_account(account).find { |r| r.key == 'seller' }
      account.account_users.find_by(user: seller).update!(access_role: role)
      expect(prompt_for(seller)).to include(I18n.t('assistant.capabilities.sales_own'))
    end
  end
end
