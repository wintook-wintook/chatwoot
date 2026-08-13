# frozen_string_literal: true

# proyecto@ai_agent_assistant - F4
require 'rails_helper'

RSpec.describe TrackingTemplateVersion do
  let(:account) { create(:account) }
  let(:user)    { create(:user, account: account) }

  describe 'snapshot al guardar' do
    it 'crea la versión 1 al nacer el agente' do
      template = create(:tracking_template, account: account, name: 'Cobranza',
                                            complementary_prompt: 'Eres del área de cobranza.')

      expect(template.versions.count).to eq(1)
      version = template.versions.first
      expect(version.version).to eq(1)
      expect(version.source).to eq('create')
      expect(version.snapshot['complementary_prompt']).to eq('Eres del área de cobranza.')
    end

    it 'agrega una versión por cada guardado que cambia el comportamiento' do
      template = create(:tracking_template, account: account, complementary_prompt: 'v uno')
      template.update!(complementary_prompt: 'v dos')
      template.update!(complementary_prompt: 'v tres')

      expect(template.versions.ordered.pluck(:version)).to eq([3, 2, 1])
      expect(template.versions.ordered.first.snapshot['complementary_prompt']).to eq('v tres')
    end

    it 'no versiona un guardado que no toca ningún campo versionado' do
      template = create(:tracking_template, account: account)

      expect { template.update!(updated_at: 1.minute.from_now) }
        .not_to(change { template.versions.count })
    end

    it 'no versiona el archivado: archivar no cambia el comportamiento' do
      template = create(:tracking_template, account: account)

      expect { template.archive! }.not_to(change { template.versions.count })
      expect(template.reload).to be_archived
    end

    it 'guarda la nota y el autor del guardado' do
      template = create(:tracking_template, account: account)
      Current.user = user
      template.version_note = 'Se agregó la regla de cierre'
      template.update!(complementary_prompt: 'nuevo')

      version = template.versions.ordered.first
      expect(version.note).to eq('Se agregó la regla de cierre')
      expect(version.user).to eq(user)
    ensure
      Current.user = nil
    end
  end

  describe 'línea base de los agentes anteriores a F4' do
    it 'reconstruye el estado previo como versión 1 al primer guardado' do
      template = create(:tracking_template, account: account, complementary_prompt: 'lo que había')
      template.versions.delete_all # simula un agente creado antes de que existiera el historial

      template.update!(complementary_prompt: 'lo que hay ahora')

      expect(template.versions.order(:version).pluck(:source)).to eq(%w[baseline manual])
      expect(template.versions.find_by(version: 1).snapshot['complementary_prompt']).to eq('lo que había')
      expect(template.versions.find_by(version: 2).snapshot['complementary_prompt']).to eq('lo que hay ahora')
    end
  end

  describe 'inmutabilidad' do
    it 'no deja editar un snapshot ya guardado' do
      version = create(:tracking_template, account: account).versions.first

      expect { version.update!(note: 'reescribiendo la historia') }
        .to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end

  describe '#resolved source' do
    it 'acepta los orígenes conocidos y cae a manual con cualquier otro' do
      template = create(:tracking_template, account: account)

      template.version_source = 'restore'
      template.update!(objective: 'Objetivo restaurado')
      expect(template.versions.ordered.first.source).to eq('restore')

      template.version_source = 'lo-que-sea'
      template.update!(objective: 'Otro objetivo distinto')
      expect(template.versions.ordered.first.source).to eq('manual')
    end
  end
end
