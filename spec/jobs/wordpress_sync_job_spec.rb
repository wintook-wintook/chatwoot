# frozen_string_literal: true

# @knowledge_sources
require 'rails_helper'

RSpec.describe WordpressSyncJob do
  let(:account) { create(:account) }
  let(:site) { 'https://misitio.com' }
  let(:source) do
    KnowledgeSource.create!(account: account, source_type: 'wordpress', name: 'Blog', status: 'active',
                            config: { 'site_url' => site, 'content_types' => ['posts'] })
  end

  before do
    create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled',
                               settings: { 'api_key' => 'sk-test' })
  end

  def stub_titles(ids)
    stub_request(:get, "#{site}/wp-json/wp/v2/posts")
      .with(query: hash_including('_fields' => /title/))
      .to_return(status: 200, body: ids.map { |id| { 'id' => id, 'title' => { 'rendered' => "Entrada #{id}" } } }.to_json,
                 headers: { 'Content-Type' => 'application/json', 'X-WP-TotalPages' => '1' })
  end

  def stub_items(entries)
    stub_request(:get, "#{site}/wp-json/wp/v2/posts")
      .with(query: hash_including('include'))
      .to_return(status: 200, body: entries.to_json,
                 headers: { 'Content-Type' => 'application/json', 'X-WP-TotalPages' => '1' })
  end

  def entry(id, html, title: "Entrada #{id}")
    { 'id' => id, 'title' => { 'rendered' => title }, 'link' => "#{site}/#{id}",
      'categories' => [], 'content' => { 'rendered' => html }, 'modified' => '2026-09-01T10:00:00' }
  end

  def stub_embeddings(count)
    stub_request(:post, 'https://api.openai.com/v1/embeddings').to_return(
      status: 200,
      body: { 'data' => Array.new(count) { |i| { 'index' => i, 'embedding' => Array.new(1536) { 0.1 } } } }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end

  def items
    account.knowledge_items.where(source_type: 'wordpress', knowledge_source_id: source.id)
  end

  def sync
    described_class.perform_now(action: 'upsert', source_id: source.id, account_id: account.id)
  end

  describe 'indexar' do
    it 'guarda un chunk por trozo, con el id de la entrada como source_id' do
      stub_titles([412])
      stub_items([entry(412, "<p>#{'texto largo. ' * 20}</p>")])
      stub_embeddings(1)

      sync

      expect(items.count).to eq(1)
      expect(items.first).to have_attributes(source_id: 412, title: 'Entrada 412', chunk_index: 0)
      expect(items.first.metadata).to include('wp_type' => 'posts', 'url' => "#{site}/412")
    end

    it 'guarda el texto limpio, no el HTML' do
      stub_titles([1])
      stub_items([entry(1, '<p>Para actualizar a la ultima version</p><script>alert(1)</script><p>y reinicia el servicio</p>')])
      stub_embeddings(1)

      sync

      expect(items.first.content).to eq("Para actualizar a la ultima version\ny reinicia el servicio")
    end

    it 'deja la fuente en idle con el resumen de lo indexado' do
      stub_titles([1, 2])
      stub_items([entry(1, '<p>uno largo para pasar el mínimo de caracteres</p>'),
                  entry(2, '<p>dos largo para pasar el mínimo de caracteres</p>')])
      stub_embeddings(2)

      sync

      expect(source.reload.sync_status).to eq('idle')
      expect(source.config).to include('indexed_entries' => 2, 'indexed_chunks' => 2)
    end

    # Una fila sin embedding nunca aparece en una búsqueda y solo confunde los
    # conteos de la pantalla.
    it 'no guarda un chunk cuyo embedding falló' do
      stub_titles([1])
      stub_items([entry(1, '<p>texto largo para pasar el mínimo de caracteres</p>')])
      stub_request(:post, 'https://api.openai.com/v1/embeddings').to_return(status: 500, body: 'boom')

      sync

      expect(items.count).to eq(0)
    end

    it 'ignora una entrada cuyo contenido queda vacío al limpiarlo' do
      stub_titles([1])
      stub_items([entry(1, '<figure><img src="x.png"></figure>')])
      stub_embeddings(0)

      sync

      expect(items.count).to eq(0)
    end
  end

  # El caso que sostiene todo el módulo: si esto no corre, la pantalla dice una
  # cosa y el agente contesta con contenido que el usuario cree haber quitado.
  describe 'borrar lo que ya no corresponde' do
    before do
      stub_titles([1, 2])
      stub_items([entry(1, '<p>uno largo para pasar el mínimo de caracteres</p>'),
                  entry(2, '<p>dos largo para pasar el mínimo de caracteres</p>')])
      stub_embeddings(2)
      sync
    end

    it 'borra los chunks de una entrada que se deseleccionó' do
      expect(items.count).to eq(2)

      source.update!(config: source.config.merge('excluded_ids' => [2]))
      stub_titles([1, 2])
      stub_items([entry(1, '<p>uno largo para pasar el mínimo de caracteres</p>')])
      stub_embeddings(1)
      sync

      expect(items.pluck(:source_id)).to eq([1])
    end

    # Una entrada despublicada deja de venir en la lista; no llega marcada como
    # borrada, así que hay que reconciliar contra lo que ya está indexado.
    it 'borra los chunks de una entrada que se despublicó' do
      stub_titles([1])
      stub_items([entry(1, '<p>uno largo para pasar el mínimo de caracteres</p>')])
      stub_embeddings(1)
      sync

      expect(items.pluck(:source_id)).to eq([1])
    end

    it 'borra los chunks que sobran cuando una entrada se acorta' do
      stub_titles([1])
      stub_items([entry(1, "<p>#{'a' * 9000}</p>")])
      stub_embeddings(3)
      sync
      expect(items.where(source_id: 1).count).to be > 1

      stub_items([entry(1, '<p>ahora es corta pero pasa el mínimo de caracteres</p>')])
      stub_embeddings(1)
      sync

      expect(items.where(source_id: 1).count).to eq(1)
    end

    it 'borra todo cuando se destruye la fuente' do
      described_class.perform_now(action: 'destroy', source_id: source.id, account_id: account.id)

      expect(items.count).to eq(0)
    end
  end

  # Dos sitios de la misma cuenta pueden tener una entrada con el mismo id: por eso
  # el índice único tuvo que incorporar knowledge_source_id.
  describe 'dos sitios en la misma cuenta' do
    it 'no se pisan aunque tengan una entrada con el mismo id' do
      otra = KnowledgeSource.create!(account: account, source_type: 'wordpress', name: 'Otro blog',
                                     status: 'active', config: { 'site_url' => site, 'content_types' => ['posts'] })
      stub_titles([412])
      stub_items([entry(412, '<p>texto largo para pasar el mínimo de caracteres</p>')])
      stub_embeddings(1)

      sync
      described_class.perform_now(action: 'upsert', source_id: otra.id, account_id: account.id)

      expect(items.count).to eq(1)
      expect(account.knowledge_items.where(knowledge_source_id: otra.id).count).to eq(1)
    end
  end

  describe 'cuando el sitio falla' do
    it 'deja la fuente en error con el motivo, sin reventar' do
      stub_request(:get, /#{site}/).to_return(status: 403)

      expect { sync }.not_to raise_error
      expect(source.reload.sync_status).to eq('error')
    end

    # Un 403 pasajero o una caída de red llegaron a borrar el índice entero,
    # dejando la fuente en `idle` como si todo hubiera ido bien.
    it 'NO borra lo ya indexado cuando el sitio no responde' do
      stub_titles([1])
      stub_items([entry(1, '<p>texto largo para pasar el minimo de caracteres</p>')])
      stub_embeddings(1)
      sync
      expect(items.count).to eq(1)

      stub_request(:get, /#{site}/).to_timeout
      sync

      expect(items.count).to eq(1)
      expect(source.reload.sync_status).to eq('error')
    end

    it 'no hace nada si la fuente no existe' do
      expect { described_class.perform_now(action: 'upsert', source_id: 0, account_id: account.id) }
        .not_to raise_error
    end
  end
end
