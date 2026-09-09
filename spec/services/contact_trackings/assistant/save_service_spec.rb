# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::SaveService do
  let(:account) { create(:account) }
  let(:user)    { create(:user, account: account) }
  let(:inbox)   { create(:inbox, account: account) }

  let(:draft_ok) { '@ruta(soporte #soporte: no puedo entrar, me da error): @buscar_articulo' }
  # Le falta el ":" tras el paréntesis: el motor leería 0 ramas.
  let(:draft_roto) { '@ruta(soporte #soporte: no puedo entrar) @buscar_articulo' }

  before { KnowledgeSource.create!(account: account, source_type: 'article', name: 'Centro de Ayuda', status: 'active') }

  def guardar(draft:, mode:, params: {})
    described_class.new(account, user: user, draft: draft, mode: mode, params: params).call
  end

  describe 'crear un Agente IA nuevo' do
    it 'lo crea con el Entrenamiento del asistente' do
      resultado = guardar(draft: draft_ok, mode: 'create',
                          params: { name: 'Soporte Kontrolya', objective: 'Resolver dudas y abrir casos',
                                    inbox_id: inbox.id })

      expect(resultado).to be_success
      expect(resultado.template.complementary_prompt).to eq(draft_ok)
      expect(resultado.template.inbox_id).to eq(inbox.id)
      expect(resultado.template.user).to eq(user)
    end

    it 'devuelve los errores del modelo en vez de reventar' do
      resultado = guardar(draft: draft_ok, mode: 'create', params: { name: '', objective: '' })

      expect(resultado.error).to eq(:invalid)
      expect(resultado.details).to be_present
    end

    it 'ignora un inbox de otra cuenta' do
      ajeno = create(:inbox, account: create(:account))

      resultado = guardar(draft: draft_ok, mode: 'create',
                          params: { name: 'Soporte', objective: 'Resolver dudas', inbox_id: ajeno.id })

      expect(resultado.template.inbox_id).to be_nil
    end
  end

  describe 'reemplazar el Entrenamiento de uno existente' do
    let(:template) do
      account.tracking_templates.create!(name: 'Soporte', objective: 'Resolver dudas',
                                         complementary_prompt: 'el viejo', user: user)
    end

    it 'lo reemplaza y guarda el anterior para poder volver atrás' do
      resultado = guardar(draft: draft_ok, mode: 'replace', params: { template_id: template.id })

      expect(resultado).to be_success
      expect(template.reload.complementary_prompt).to eq(draft_ok)
      expect(template.previous_complementary_prompt).to eq('el viejo')
    end

    it 'no toca un agente de otra cuenta' do
      ajeno = create(:account).tracking_templates.create!(name: 'Ajeno', objective: 'Otro objetivo')

      expect(guardar(draft: draft_ok, mode: 'replace', params: { template_id: ajeno.id }).error)
        .to eq(:template_not_found)
    end
  end

  # Todo el módulo existe porque hoy se puede guardar un agente que no ejecuta nada.
  # Dejar que el guardado se saltee el comprobador reintroduciría el defecto.
  describe 'el comprobador manda' do
    it 'no guarda un Entrenamiento con hallazgos bloqueantes' do
      resultado = guardar(draft: draft_roto, mode: 'create',
                          params: { name: 'Soporte', objective: 'Resolver dudas' })

      expect(resultado.error).to eq(:blocking_findings)
      expect(resultado.details.first[:code]).to eq(:route_line_unparsed)
      expect(account.tracking_templates.count).to eq(0)
    end

    # Un hallazgo que degrada avisa de algo que funciona mal, no de algo que no existe.
    it 'sí guarda cuando lo único que hay son hallazgos que degradan' do
      # La etiqueta #soporte no existe en la cuenta: degrada, no bloquea.
      resultado = guardar(draft: draft_ok, mode: 'create',
                          params: { name: 'Soporte', objective: 'Resolver dudas' })

      expect(resultado).to be_success
    end

    it 'no guarda un borrador vacío' do
      expect(guardar(draft: '', mode: 'create').error).to eq(:empty_draft)
    end
  end
end
