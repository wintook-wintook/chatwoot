# frozen_string_literal: true

require 'rails_helper'

# @buscar_predefinidas(GRUPO) con una sola predefinida en el grupo: se usa sin umbral.
RSpec.describe KnowledgeBaseResponseService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:message) { create(:message, account: account, conversation: conversation, content: 'si me gustó') }
  let(:service) { described_class.new(message, tracking: nil, branch: nil) }
  let!(:visita) { create(:knowledge_item, account: account, title: 'visita', content: 'Tuxpan 30, Zapopan') }

  before do
    create(:knowledge_item, account: account, title: 'garantias', content: '1 mes de garantía')
    create(:knowledge_item, account: account, title: 'promociones', content: 'Descuento de contado')
    create(:knowledge_item, account: account, title: 'promociones Buen Fin', content: 'Buen Fin')
  end

  def grupo(nombre)
    service.send(:only_item_of_group, described_class.grouped_items(account, 'canned_response', nombre), nombre)
  end

  it 'si el grupo deja una sola predefinida, es esa' do
    expect(grupo('visita')).to eq([visita])
  end

  it 'con dos o más, sin grupo o con grupo negado, la búsqueda de siempre' do
    expect(grupo('promociones')).to be_nil
    expect(grupo(nil)).to be_nil
    expect(grupo('!visita')).to be_nil
  end
end
