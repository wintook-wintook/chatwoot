# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::BriefSourceMatch do
  let(:account) { create(:account) }
  let(:texto) do
    "# ADAM\n## Desarrollo Web® — Cuándo recomendarlo\n### Norma\n## Kontrolya®\n## Guion: páginas web\n### Texto oficial\n"
  end

  before do
    create(:knowledge_source, account: account, source_type: 'discourse', status: 'active', name: 'Foro_SC',
                              config: { 'url' => 'https://foro.example.com' })
    allow_any_instance_of(KnowledgeBase::DiscourseKeywordSearch).to receive(:find) do |_buscador, termino| # rubocop:disable RSpec/AnyInstance
      { 'desarrollo web' => [{ title: '6. Desarrollo Web® — Ecosistema' }], 'kontrolya' => [{ title: '13. Kontrolya®' }],
        'guion: paginas web' => [{ title: 'Otra cosa' }] }.fetch(termino, [])
    end
  end

  it 'cuenta qué secciones del encargo están en cada foro (sin Norma ni Texto oficial)' do
    sugerencia = described_class.new(account, text: texto).call.first

    expect(sugerencia).to include('directiva' => '@buscar_foro(Foro_SC)', 'cubiertos' => 2, 'total' => 3)
    expect(sugerencia['secciones']).to contain_exactly('desarrollo web', 'kontrolya')
    expect(described_class.best([sugerencia])['directiva']).to eq('@buscar_foro(Foro_SC)')
  end

  it 'por debajo de la mitad no es la mejor' do
    expect(described_class.best([{ 'directiva' => 'x', 'cubiertos' => 1, 'total' => 3 }])).to be_nil
  end
end
