# frozen_string_literal: true

require 'rails_helper'

# proyecto@respuestas_predefinidas R3 — categorías; su nombre viaja en el vector (D2).
RSpec.describe CannedResponseCategory do
  let(:account) { create(:account) }
  let(:categoria) { described_class.create!(account: account, name: 'PATITAS') }

  def vector_de(canned)
    create(:knowledge_item, account: account, source_type: 'canned_response', source_id: canned.id, metadata: { 'short_code' => 'x' })
  end

  it 'el nombre es único en la cuenta (sin importar mayúsculas) y usable en la directiva' do
    categoria
    expect(described_class.new(account: account, name: ' patitas ')).not_to be_valid
    expect(described_class.new(account: account, name: 'VET (2)')).not_to be_valid
    expect(described_class.new(account: account, name: '!VET')).not_to be_valid
    expect(described_class.new(account: create(:account), name: 'PATITAS')).to be_valid
  end

  it 'asignar, renombrar y borrar la categoría actualiza el vector sin pedir embedding' do
    canned = create(:canned_response, account: account)
    item = vector_de(canned)

    expect { canned.update!(category: categoria) }.not_to have_enqueued_job(KnowledgeItemSyncJob)
    expect(item.reload.metadata).to eq('short_code' => 'x', 'category' => 'PATITAS')

    categoria.update!(name: 'VETERINARIA')
    expect(item.reload.metadata['category']).to eq('VETERINARIA')

    categoria.destroy!
    expect(canned.reload.category_id).to be_nil
    expect(item.reload.metadata).to eq('short_code' => 'x')
  end

  it 'una predefinida no puede tener la categoría de otra cuenta' do
    ajena = described_class.create!(account: create(:account), name: 'AJENA')

    expect(build(:canned_response, account: account, category: ajena)).not_to be_valid
  end
end
