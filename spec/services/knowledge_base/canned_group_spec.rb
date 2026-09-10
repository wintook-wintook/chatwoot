# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe KnowledgeBase::CannedGroup do
  let(:account) { create(:account) }
  let(:source)  { KnowledgeSource.create!(account: account, source_type: 'canned_response', name: 'Respuestas', status: 'active') }

  def item(title)
    create(:knowledge_item, account: account, knowledge_source: source, source_type: 'canned_response', title: title)
  end

  describe '.scope' do
    before do
      item('GESTION alta de usuario')
      item('GESTION cambio de datos')
      item('HORARIO DE OFICINA')
      item(nil)
    end

    it 'sin grupo devuelve el corpus completo' do
      expect(described_class.scope(account, 'canned_response', nil).count).to eq(4)
    end

    it 'con grupo deja solo los títulos que empiezan con ese prefijo' do
      titulos = described_class.scope(account, 'canned_response', 'GESTION').pluck(:title)

      expect(titulos).to contain_exactly('GESTION alta de usuario', 'GESTION cambio de datos')
    end

    # El item sin título tiene que sobrevivir a la exclusión: un NOT ILIKE contra NULL
    # da NULL y lo descartaría en silencio.
    it 'con grupo negado excluye ese prefijo y conserva los que no tienen título' do
      titulos = described_class.scope(account, 'canned_response', '!GESTION').pluck(:title)

      expect(titulos).to contain_exactly('HORARIO DE OFICINA', nil)
    end

    it 'trata un grupo vacío como si no hubiera grupo' do
      expect(described_class.scope(account, 'canned_response', '!').count).to eq(4)
    end

    it 'no deja que el grupo se escape como comodín de LIKE' do
      item('%')

      expect(described_class.scope(account, 'canned_response', '%').pluck(:title)).to eq(['%'])
    end
  end

  describe '.threshold' do
    it 'sube el listón solo para el grupo positivo' do
      expect(described_class.threshold('GESTION')).to eq(KnowledgeBaseResponseService::GROUP_SIMILARITY_THRESHOLD)
    end

    it 'deja el umbral general sin grupo y con grupo negado' do
      expect(described_class.threshold(nil)).to be_nil
      expect(described_class.threshold('!GESTION')).to be_nil
    end
  end

  # ============================================================================
  # EL SPEC QUE JUSTIFICA QUE HAYA DOS COPIAS
  # ============================================================================
  # El motor de producción NO delega en este módulo: la lógica está escrita dos
  # veces, acá y en KnowledgeBaseResponseService#grouped_items / #group_threshold.
  # La prueba en seco del Asistente le dice a alguien qué va a hacer el motor, así
  # que si las dos copias se separan, el panel no falla — miente.
  #
  # Esto corre las dos sobre los mismos datos y exige el mismo resultado. Si alguien
  # toca una sola, este spec se pone rojo y dice cuál.
  describe 'paridad con el motor de producción' do
    let(:service) do
      # El servicio real, con un mensaje sin persistir: grouped_items y group_threshold
      # solo usan @account, así que alcanza para interrogarlos.
      KnowledgeBaseResponseService.new(Message.new(account: account, content: 'hola'))
    end

    before do
      item('GESTION alta de usuario')
      item('HORARIO DE OFICINA')
      item(nil)
    end

    [nil, 'GESTION', '!GESTION', '', 'NOEXISTE'].each do |group|
      it "devuelve el mismo alcance que el motor para el grupo #{group.inspect}" do
        mio    = described_class.scope(account, 'canned_response', group).pluck(:id).sort
        motor  = service.send(:grouped_items, 'canned_response', group).pluck(:id).sort

        expect(mio).to eq(motor)
      end

      it "devuelve el mismo umbral que el motor para el grupo #{group.inspect}" do
        expect(described_class.threshold(group)).to eq(service.send(:group_threshold, group))
      end
    end
  end
end
