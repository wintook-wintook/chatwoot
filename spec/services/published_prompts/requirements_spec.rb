# frozen_string_literal: true

require 'rails_helper'

# proyecto@publicar_prompts (F1). Solo texto: no toca la base.
RSpec.describe PublishedPrompts::Requirements do
  it 'detecta cada clase de directiva una sola vez' do
    texto = '{{doc:Manual}} {{hoja_buscar: Servicio Gruas | remolque=? | Calendar_ID}} ' \
            '{{consulta:sae/saldo(rfc)}} {{consulta:existencias}} {{logo}} {{logo}} ' \
            '@buscar_foro(Foro X) @discourse @buscar_predefinidas'

    expect(described_class.detect(texto)).to contain_exactly(
      { 'kind' => 'google_doc', 'name' => 'Manual' },
      { 'kind' => 'google_sheet', 'name' => 'Servicio Gruas' },
      { 'kind' => 'erp_query', 'name' => 'sae/saldo' },
      { 'kind' => 'erp_query', 'name' => 'existencias' },
      { 'kind' => 'attachment', 'name' => 'logo' },
      { 'kind' => 'knowledge_source', 'name' => 'Foro X' },
      { 'kind' => 'discourse_integration' },
      { 'kind' => 'canned_responses' }
    )
  end

  it 'regresa vacío sin texto' do
    expect(described_class.detect(nil, '')).to eq([])
  end
end
