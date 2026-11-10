# frozen_string_literal: true

require 'rails_helper'

# Dali — preguntas de uso: lee las guías y anota lo que no supo (AssistantGuideGap).
RSpec.describe Assistant::GuideTools do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:gaps) { AssistantGuideGap.where(account_id: account.id).order(:id) }
  let(:tools) do
    Assistant::Tools.new(account: account, user: user, grant: Access::Grant.new(nil, nil), zone: Time.zone).tap do |t|
      t.turn = { question: '¿Cómo conecto CONTPAQi?', page: 'home' }
    end
  end

  it 'busca y lee una guía sin anotar nada' do
    found = tools.call('search_guides', { 'query' => 'cómo creo un contrato' })[:result]
    expect(found[:guides].first[:key]).to eq('contratos')

    read = tools.call('read_guide', { 'key' => 'contratos' })[:result]
    expect(read[:content]).to include('Nuevo contrato')
    expect(gaps.count).to eq(0)
  end

  it 'anota la pregunta del usuario cuando no hay guía' do
    result = tools.call('search_guides', { 'query' => 'xyzzy plugh' })[:result]
    expect(result[:guides]).to eq([])

    gap = gaps.last
    expect(gap).to have_attributes(account_id: account.id, user_id: user.id, reason: 'no_guide',
                                   question: '¿Cómo conecto CONTPAQi?', page: 'home', status: 'pending')
  end

  it 'anota una sola vez por turno' do
    tools.call('search_guides', { 'query' => 'xyzzy' })
    tools.call('report_gap', { 'question' => 'otra' })
    expect(gaps.count).to eq(1)
  end

  it 'report_gap guarda la guía que se leyó' do
    tools.call('read_guide', { 'key' => 'clientes' })
    tools.call('report_gap', { 'question' => 'x' })
    expect(gaps.last).to have_attributes(reason: 'not_covered', guide_key: 'clientes')
  end

  it 'la misma pregunta pendiente suma en vez de repetirse' do
    2.times { AssistantGuideGap.record!(account: account, user: user, reason: 'no_guide', question: '¿Cómo conecto CONTPAQi?') }
    AssistantGuideGap.record!(account: account, user: user, reason: 'no_guide', question: '¿como conecto contpaqi')
    expect(gaps.count).to eq(1)
    expect(gaps.last.occurrences).to eq(3)
  end

  it 'read_guide no abre guías de áreas sin acceso' do
    grant = instance_double(Access::Grant, allowed?: false)
    limited = Assistant::Tools.new(account: account, user: user, grant: grant, zone: Time.zone)
    expect(limited.call('read_guide', { 'key' => 'ventas' })[:result]).to have_key(:error)
  end
end
