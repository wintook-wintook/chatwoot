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

  describe '.listable_for' do
    it 'muestra las abiertas y las que terminaron en un agente' do
      abierta = sesion
      guardada = sesion(status: 'saved')

      expect(described_class.listable_for(account, user)).to contain_exactly(abierta, guardada)
    end

    # Descartar no borra la fila: la saca de la vista. Un clic de más en una
    # entrevista de 40 minutos no debería ser irreversible.
    it 'no muestra las descartadas' do
      sesion(status: 'discarded')

      expect(described_class.listable_for(account, user)).to be_empty
    end

    it 'no muestra las de otra persona' do
      sesion(user: otro)

      expect(described_class.listable_for(account, user)).to be_empty
    end

    it 'las ordena de la más reciente a la más vieja' do
      vieja = sesion
      nueva = sesion
      vieja.update!(updated_at: 3.days.ago)

      expect(described_class.listable_for(account, user).to_a).to eq([nueva, vieja])
    end
  end

  # Lo que hace elegible una conversación en el listado: de qué trataba y si el
  # borrador servía.
  describe 'cómo se presenta en el listado' do
    it 'usa el primer mensaje de la persona como título' do
      s = sesion(messages: [{ 'role' => 'user', 'content' => '  quiero un agente de soporte  ' },
                            { 'role' => 'assistant', 'content' => '¿qué temas?' }])

      expect(s.title).to eq('quiero un agente de soporte')
    end

    it 'recorta un título largo' do
      s = sesion(messages: [{ 'role' => 'user', 'content' => 'a' * 200 }])

      expect(s.title.length).to be <= 80
    end

    it 'no toma como título lo que dijo el asistente' do
      s = sesion(messages: [{ 'role' => 'assistant', 'content' => 'hola, ¿en qué te ayudo?' }])

      expect(s.title).to be_nil
    end

    it 'cuenta las ramas del último borrador sin volver a parsearlo' do
      s = sesion(validation: { 'routes' => [{ 'name' => 'a' }, { 'name' => 'b' }] })

      expect(s.route_count).to eq(2)
    end

    it 'cuenta cero cuando todavía no hay borrador' do
      expect(sesion.route_count).to eq(0)
    end
  end
end
