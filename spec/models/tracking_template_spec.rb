# frozen_string_literal: true

require 'rails_helper'

# proyecto@bot_seguimiento_calendar
RSpec.describe TrackingTemplate do
  let(:account) { create(:account) }

  describe 'validación de timezone' do
    it 'acepta una zona horaria válida' do
      template = build(:tracking_template, account: account, timezone: 'America/Mexico_City')
      expect(template).to be_valid
    end

    it 'permite dejar la zona horaria vacía (hereda del inbox)' do
      template = build(:tracking_template, account: account, timezone: nil)
      expect(template).to be_valid
    end

    it 'rechaza una zona horaria inválida' do
      template = build(:tracking_template, account: account, timezone: 'Marte/Olympus')
      expect(template).not_to be_valid
      expect(template.errors[:timezone]).to be_present
    end
  end

  # proyecto@asistente_agentes_ia — plan: docs/formulario_entrenamiento_plan.md
  describe 'Entrenamiento por bloques' do
    def agente(prompt)
      account.tracking_templates.create!(name: "Agente #{SecureRandom.hex(3)}", objective: 'Un objetivo', complementary_prompt: prompt)
    end

    it 'guarda la estructura al guardar el texto' do
      bloques = agente("[ROL]\nSos amable.")['training_structure']['blocks']

      expect(bloques.map { |b| b['title'] }).to eq(['ROL'])
    end

    # Las dos columnas no pueden decir cosas distintas, escriba quien escriba.
    it 'vuelve a separar la estructura cada vez que cambia el texto' do
      template = agente("[ROL]\nSos amable.")
      template.update!(complementary_prompt: "[ROL]\nSos amable.\n\n[ESTILO]\nBreve.")

      expect(template.reload.training_structure['blocks'].pluck('title')).to eq(%w[ROL ESTILO])
    end

    it 'arma el texto desde los bloques del formulario' do
      template = agente("[ROL]\nSos amable.")
      estructura = template.training_blocks
      estructura['blocks'] << { 'type' => 'section', 'title' => 'NO SIMULAR', 'body' => 'Nunca confirmes.' }

      template.update!(training_structure_from_form: estructura)

      expect(template.reload.complementary_prompt).to eq("[ROL]\nSos amable.\n\n[NO SIMULAR]\nNunca confirmes.")
      expect(template.training_structure['blocks'].pluck('title')).to eq(['ROL', 'NO SIMULAR'])
    end

    # Un agente anterior a la columna y sin backfill se abre igual.
    it 'separa al vuelo si la estructura guardada está vacía' do
      template = agente("## ROL\nx")
      template.update_columns(training_structure: {}) # rubocop:disable Rails/SkipsModelValidations

      expect(template.reload.training_blocks['blocks'].first['style']).to eq('markdown2')
    end
  end
end
