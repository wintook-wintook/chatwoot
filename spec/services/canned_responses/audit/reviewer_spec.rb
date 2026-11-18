# frozen_string_literal: true

require 'rails_helper'

# proyecto@auditoria_predefinidas — datos distintos de cosas distintas no se contradicen,
# aunque el modelo diga lo contrario (dos maestrías con la misma plantilla y otros precios).
RSpec.describe CannedResponses::Audit::Reviewer do
  let(:account) { create(:account) }
  let(:chat) { instance_double(ContactTrackings::Assistant::OpenaiChat, api_key: 'sk-test') }
  let(:negocios) do
    build(:canned_response, id: 1, account: account, short_code: 'Maestría en Negocios — Costos', content: 'El precio de lista es $35,272.')
  end
  let(:salud) do
    build(:canned_response, id: 2, account: account, short_code: 'Maestría en Salud — Costos', content: 'El precio de lista es $40,272.')
  end
  let(:contradiccion) do
    [{ 'topic' => 'costo', 'quote_a' => 'El precio de lista es $35,272', 'quote_b' => 'El precio de lista es $40,272', 'why' => 'distintos' }]
  end

  before { allow(ContactTrackings::Assistant::OpenaiChat).to receive(:new).and_return(chat) }

  it 'si no es el mismo sujeto, descarta las contradicciones' do
    allow(chat).to receive(:call).and_return('subject_a' => 'Maestría en Negocios', 'subject_b' => 'Maestría en Salud',
                                             'same_subject' => false, 'relation' => 'overlap', 'contradictions' => contradiccion)

    resultado = described_class.new(account).pair(negocios, salud)

    expect(resultado).to include('relation' => 'distinct', 'contradictions' => [], 'same_subject' => false)
  end

  it 'si es el mismo sujeto, las conserva' do
    allow(chat).to receive(:call).and_return('same_subject' => true, 'relation' => 'overlap', 'contradictions' => contradiccion)

    expect(described_class.new(account).pair(negocios, salud)['contradictions'].size).to eq(1)
  end

  it 'descarta la que el propio modelo dice que puede ser cierta a la vez o que no es el mismo dato' do
    otras = [contradiccion.first.merge('same_item' => false), contradiccion.first.merge('can_both_be_true' => true)]
    allow(chat).to receive(:call).and_return('same_subject' => true, 'relation' => 'overlap', 'contradictions' => otras)

    expect(described_class.new(account).pair(negocios, salud)['contradictions']).to eq([])
  end

  it 'mismo sujeto con aspectos distintos no es «se solapan»' do
    allow(chat).to receive(:call).and_return('same_subject' => true, 'repeats_info' => false, 'relation' => 'overlap',
                                             'contradictions' => [])

    expect(described_class.new(account).pair(negocios, salud)['relation']).to eq('distinct')
  end

  it 'sujetos distintos que comparten información no se solapan' do
    allow(chat).to receive(:call).and_return('same_subject' => false, 'repeats_info' => true, 'relation' => 'overlap',
                                             'contradictions' => [])

    expect(described_class.new(account).pair(negocios, salud)['relation']).to eq('distinct')
  end
end
