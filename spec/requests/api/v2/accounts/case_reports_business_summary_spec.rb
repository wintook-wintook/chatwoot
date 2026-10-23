# frozen_string_literal: true

require 'rails_helper'

# @tickets_cases — «Resumen del negocio»: quién lo ve, qué trae y «Explícame la
# semana» (la llamada a OpenAI se simula con `chat`).
RSpec.describe 'Case Reports API — Resumen del negocio' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:venta)   { CaseType.create!(account: account, name: 'Venta', color: '#8b5cf6', case_class: :commercial) }
  let(:soporte) { CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6') }
  let(:base)    { "/api/v2/accounts/#{account.id}/case_reports" }
  let(:won_reason) { CaseOutcomeReason.ensure_defaults_for(account).find_by(outcome: :won) }

  def summary_as(user)
    get "#{base}/business_summary", headers: user.create_new_auth_token, as: :json
  end

  def opportunity(attrs = {})
    CaseTicket.create!({ account: account, title: 'Opp', contact: contact, case_type: venta, assignee: agent,
                         status: :in_progress }.merge(attrs))
  end

  describe 'quién puede verlo' do
    it 'los administradores siempre; un agente solo si lo autorizan' do
      summary_as(admin)
      expect(response).to have_http_status(:ok)

      summary_as(agent)
      expect(response).to have_http_status(:forbidden)

      CaseSetting.for_account(account).update!(business_summary_user_ids: [agent.id])
      summary_as(agent)
      expect(response).to have_http_status(:ok)
    end

    it 'el administrador elige a los autorizados (solo usuarios de la cuenta) y cada quien sabe si puede' do
      stranger = create(:user)
      patch "/api/v1/accounts/#{account.id}/case_setting",
            params: { case_setting: { business_summary_user_ids: [agent.id, stranger.id, agent.id] } },
            headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['business_summary_user_ids']).to eq([agent.id])

      get "/api/v1/accounts/#{account.id}/case_setting", headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body['can_view_business_summary']).to be(true)

      patch "/api/v1/accounts/#{account.id}/case_setting",
            params: { case_setting: { business_summary_user_ids: [] } }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'qué trae' do
    it 'ventas, soporte, quién tiene más vencido y lo que necesita atención (lo más grave primero)' do
      travel_to Time.zone.parse('2026-10-21 12:00') do
        opportunity(amount: 900, currency: 'MXN').close_with_outcome!(:won, reason_id: won_reason.id)
        opportunity(amount: 300, currency: 'MXN', committed: true, expected_close_at: Date.new(2026, 10, 10))
        opportunity(amount: 100, currency: 'MXN', expected_close_at: Date.new(2026, 10, 5))
        CaseTicket.create!(account: account, title: 'Falla', contact: contact, case_type: soporte)

        summary_as(admin)
        body = response.parsed_body

        expect(body['classes']).to eq(%w[commercial support])
        expect(body).not_to have_key('work_orders')
        expect(body['sales']['won_value']).to eq([{ 'currency' => 'MXN', 'amount' => 900.0, 'count' => 1 }])
        expect(body['sales']['committed_overdue'].first).to include('amount' => 300.0)
        expect(body['support']).to include('open_count' => 1)
        expect(body['people']['most_overdue']).to eq([{ 'assignee_id' => agent.id, 'assignee_name' => agent.name,
                                                        'count' => 2 }])
        expect(body['attention'].pluck('key', 'count')).to eq([['promises_overdue', 1], ['close_overdue', 1]])
      end
    end
  end

  describe 'conversaciones' do
    let(:inbox) { create(:inbox, account: account) }

    it 'trae los números de Chatwoot y avisa de las conversaciones sin atender' do
      convo = create(:conversation, account: account, inbox: inbox, contact: contact)
      convo.update_labels(%w[precio])
      summary_as(admin)
      block = response.parsed_body['conversations']

      expect(block['now']).to include('open' => 1, 'unattended' => 1)
      expect(block['top_labels']).to eq([{ 'label' => 'precio', 'count' => 1 }])
      expect(block['by_channel'].first['count']).to eq(1)
      expect(response.parsed_body['attention'].pluck('key')).to include('unattended_conversations')
    end

    it 'el análisis con IA manda una muestra con extractos y limpia los ejemplos' do
      CaseAiConfig.for_account(account).update!(enabled: true)
      allow_any_instance_of(Cases::Ai::ConversationAnalyst).to receive(:available?).and_return(true) # rubocop:disable RSpec/AnyInstance
      convo = create(:conversation, account: account, inbox: inbox, contact: contact)
      create(:message, conversation: convo, account: account, inbox: inbox, message_type: :incoming, content: '¿Cuánto cuesta?')
      create(:message, conversation: convo, account: account, inbox: inbox, message_type: :outgoing, content: 'Nota',
                       private: true)
      sent = nil
      allow_any_instance_of(Cases::Ai::ConversationAnalyst).to receive(:chat) do |_analyst, **args| # rubocop:disable RSpec/AnyInstance
        sent = args[:user]
        { 'topics' => [{ 'label' => 'Precios', 'count' => 1, 'examples' => [convo.display_id, 99_999] }],
          'upset' => [], 'lost_sales' => [{ 'conversation' => convo.display_id, 'why' => 'Preguntó precio' },
                                          { 'conversation' => 99_999, 'why' => 'inventada' }],
          'complaints' => 'nada' }
      end

      post "#{base}/business_summary_conversations_ai", headers: admin.create_new_auth_token, as: :json

      expect(sent).to include("##{convo.display_id}", 'oportunidad: no', 'C: ¿Cuánto cuesta?')
      expect(sent).not_to include('Nota')
      expect(response.parsed_body['analysis']).to eq(
        'topics' => [{ 'label' => 'Precios', 'count' => 1, 'examples' => [convo.display_id] }],
        'upset' => [], 'lost_sales' => [{ 'conversation' => convo.display_id, 'why' => 'Preguntó precio' }],
        'complaints' => [], 'sample_size' => 1
      )
    end
  end

  describe 'Explícame la semana' do
    before do
      CaseAiConfig.for_account(account).update!(enabled: true)
      allow_any_instance_of(Cases::Ai::BusinessSummaryNarrator).to receive(:available?).and_return(true) # rubocop:disable RSpec/AnyInstance
    end

    it 'manda el resumen y el período, y limpia la respuesta' do
      sent = nil
      allow_any_instance_of(Cases::Ai::BusinessSummaryNarrator).to receive(:chat) do |_narrator, **args| # rubocop:disable RSpec/AnyInstance
        sent = args[:user]
        { 'headline' => ' Vas bien. ', 'good' => ['Vendiste más', ''], 'watch' => 'no es lista', 'today' => %w[a b c d e f] }
      end

      post "#{base}/business_summary_ai", params: { period_label: '1–21 oct', compare_label: '1–21 sept' },
                                          headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(sent).to include('1–21 oct', '1–21 sept', '"classes"')
      expect(response.parsed_body['story']).to eq('headline' => 'Vas bien.', 'good' => ['Vendiste más'],
                                                  'watch' => ['no es lista'], 'today' => %w[a b c d e])
    end

    it 'respeta si la IA está apagada y a quién no tiene acceso' do
      CaseAiConfig.for_account(account).update!(modes: CaseAiConfig.default_modes.merge('business_summary' => 'off'))
      post "#{base}/business_summary_ai", headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)

      post "#{base}/business_summary_ai", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end
end
