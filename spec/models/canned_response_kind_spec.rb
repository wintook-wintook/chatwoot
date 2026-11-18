# frozen_string_literal: true

require 'rails_helper'

# proyecto@predefinidas_que_contestan — el tipo y los topes que se dejan guardar.
RSpec.describe CannedResponse do
  let(:account) { create(:account) }

  it 'por omisión es general y solo acepta los tres tipos' do
    canned = create(:canned_response, account: account)
    expect(canned.kind).to eq('general')
    expect(build(:canned_response, account: account, kind: 'proceso')).not_to be_valid
    expect(build(:canned_response, account: account, kind: 'ficha')).to be_valid
  end

  it 'no deja guardar nombre + contenido de más de 3,500 ni un Prompt de más de 2,000' do
    largo = build(:canned_response, account: account, short_code: 'Ficha', content: 'a' * 3500)
    expect(largo).not_to be_valid
    expect(largo.errors[:content].join).to include('3500')

    prompt = build(:canned_response, account: account, content: 'Hola', content_prompts: 'b' * 2001)
    expect(prompt).not_to be_valid
  end

  it 'las que ya pasaban no se rompen hasta que se edita su texto' do
    vieja = create(:canned_response, account: account, short_code: 'Vieja', content: 'corta')
    vieja.update_column(:content, 'a' * 5000) # rubocop:disable Rails/SkipsModelValidations
    vieja.reload

    expect(vieja.update(kind: 'ficha')).to be(true)
    expect(vieja.update(content: 'a' * 4000)).to be(false)
  end

  it 'cambiar el tipo lo pone en el vector sin volver a vectorizar' do
    canned = create(:canned_response, account: account, short_code: 'Plan X', content: 'Precio $10.')
    source = create(:knowledge_source, account: account)
    item = create(:knowledge_item, account: account, knowledge_source: source, source_id: canned.id, metadata: {})

    canned.update!(kind: 'ficha')
    expect(item.reload.metadata['kind']).to eq('ficha')
  end
end
