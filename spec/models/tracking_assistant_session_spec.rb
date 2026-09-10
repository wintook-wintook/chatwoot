# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe TrackingAssistantSession do
  let(:account) { create(:account) }
  let(:user)    { create(:user, account: account) }
  let(:otro)    { create(:user, account: account) }

  def sesion(attrs = {})
    described_class.create!({ account: account, user: user }.merge(attrs))
  end

  describe '.resumable_for' do
    it 'devuelve la última conversación a medias de esa persona' do
      vieja = sesion
      nueva = sesion
      vieja.update!(updated_at: 2.hours.ago)

      expect(described_class.resumable_for(account, user)).to eq(nueva)
    end

    # Una entrevista es de quien la tuvo: retomar la de otro sería seguir una
    # conversación que no se leyó.
    it 'no ofrece la conversación de otra persona' do
      sesion(user: otro)

      expect(described_class.resumable_for(account, user)).to be_nil
    end

    it 'no ofrece una que ya terminó en un agente' do
      sesion(status: 'saved')

      expect(described_class.resumable_for(account, user)).to be_nil
    end

    it 'no cruza cuentas' do
      sesion

      expect(described_class.resumable_for(create(:account), user)).to be_nil
    end

    it 'devuelve nil cuando no hay ninguna' do
      expect(described_class.resumable_for(account, user)).to be_nil
    end
  end

  describe '#record_turn' do
    it 'guarda el hilo, el borrador y su comprobación' do
      s = sesion
      s.record_turn(messages: [{ 'role' => 'user', 'content' => 'hola' }],
                    draft: '@ruta(a #b: c): -', validation: { 'valid' => true })

      expect(s.reload.messages.size).to eq(1)
      expect(s.draft).to eq('@ruta(a #b: c): -')
      expect(s.validation).to eq('valid' => true)
    end

    # El borrador sobrevive a los turnos siguientes: el modelo puede volver a
    # preguntar después de haber entregado, y perderlo sería tirar el trabajo.
    it 'no pisa el borrador con un turno que no trae uno' do
      s = sesion
      s.record_turn(messages: [], draft: '@ruta(a #b: c): -')
      s.record_turn(messages: [{ 'role' => 'user', 'content' => 'otra cosa' }])

      expect(s.reload.draft).to eq('@ruta(a #b: c): -')
    end

    # Un hilo que se fue de las manos no debe crecer sin límite dentro del jsonb.
    it 'recorta el hilo al tope' do
      s = sesion
      largos = Array.new(described_class::MAX_MESSAGES + 10) { |i| { 'role' => 'user', 'content' => "m#{i}" } }

      s.record_turn(messages: largos)

      expect(s.reload.messages.size).to eq(described_class::MAX_MESSAGES)
      expect(s.messages.last['content']).to eq("m#{described_class::MAX_MESSAGES + 9}")
    end
  end

  describe '#mark_saved!' do
    it 'la cierra y la liga al agente que quedó' do
      s = sesion
      template = account.tracking_templates.create!(name: 'Soporte', objective: 'Resolver dudas')

      s.mark_saved!(template)

      expect(s.reload).to have_attributes(status: 'saved', tracking_template: template)
      expect(described_class.resumable_for(account, user)).to be_nil
    end
  end

  describe 'validaciones' do
    it 'rechaza un estado que no existe' do
      expect(described_class.new(account: account, user: user, status: 'raro')).not_to be_valid
    end
  end
end
