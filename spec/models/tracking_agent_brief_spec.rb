# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe TrackingAgentBrief do
  let(:account) { create(:account) }
  let(:user)    { create(:user, account: account) }

  def brief(attrs = {})
    described_class.create!({ account: account, user: user, filename: 'e.md', content: 'hola',
                              sha256: described_class.fingerprint('hola') }.merge(attrs))
  end

  describe '.read_twin' do
    it 'solo devuelve uno con la lectura ya hecha' do
      brief(status: 'reading')

      expect(described_class.read_twin(account, described_class.fingerprint('hola'))).to be_nil
    end

    it 'devuelve el último leído con esa huella' do
      viejo = brief(status: 'ready')
      nuevo = brief(status: 'ready')
      viejo.update!(created_at: 1.day.ago)

      expect(described_class.read_twin(account, described_class.fingerprint('hola'))).to eq(nuevo)
    end
  end

  describe '#copy_reading_from' do
    # Las respuestas del chat son de cada agente aunque el archivo sea el mismo.
    it 'copia la lectura y no las respuestas' do
      gemelo = brief(status: 'ready', chunks: [{ 'sha' => 'a' }], digest: { 'objetivo' => 'x' }, answers: { 'q' => 'r' })
      copia = described_class.new
      copia.copy_reading_from(gemelo)

      expect(copia).to have_attributes(status: 'ready', chunks: [{ 'sha' => 'a' }], digest: { 'objetivo' => 'x' },
                                       answers: {}, usage: { 'reused_from' => gemelo.id })
    end
  end

  # ApplicationRecord corta toda columna text en 20.000 caracteres; ADAM tiene 1,1 millones.
  it 'guarda encargos más largos que el tope general de texto' do
    largo = 'a' * 50_000

    expect(brief(content: largo, sha256: described_class.fingerprint(largo))).to be_persisted
  end

  it 'no acepta un estado desconocido' do
    expect { brief(status: 'lista') }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
