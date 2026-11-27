# frozen_string_literal: true

require 'rails_helper'

# El candado de las guías de uso (config/assistant/guides): si se renombra una pantalla
# de open_page, se agrega un área sin guía o una guía queda incompleta, esto falla.
RSpec.describe Assistant::Guides do
  let(:admin) { Access::Grant.new(nil, nil) }
  # Las pruebas de los archivos leen los .md directo (all puede venir del portal «Guías de Dali»).
  let(:guides) { described_class.load_files }

  def grant_with(*areas)
    instance_double(Access::Grant, allowed?: false).tap do |grant|
      areas.each { |area| allow(grant).to receive(:allowed?).with(area).and_return(true) }
    end
  end

  describe 'los archivos' do
    it 'hay guías' do
      expect(guides).not_to be_empty
    end

    it 'cada una tiene cabecera completa y su clave es el nombre del archivo' do
      files = Dir[described_class::DIR.join('*.md')].map { |path| File.basename(path, '.md') }.sort
      expect(guides.map(&:key).sort).to eq(files)
      guides.each do |guide|
        expect(guide.title).to be_present, "#{guide.key}: falta title"
        expect(guide.keywords).to be_present, "#{guide.key}: faltan keywords"
        expect(guide.body).to match(/^## /), "#{guide.key}: el texto necesita secciones ##"
      end
    end

    it 'las áreas existen' do
      guides.each do |guide|
        expect(guide.areas - AccessRole::AREAS).to be_empty, "#{guide.key}: área desconocida #{guide.areas - AccessRole::AREAS}"
      end
    end

    it 'las pantallas que mencionan existen en open_page' do
      guides.each do |guide|
        unknown = guide.pages - Assistant::Pages::MAP.keys
        expect(unknown).to be_empty, "#{guide.key}: pantallas que open_page no conoce #{unknown}"
      end
    end

    it 'sus sources apuntan a archivos que existen y reviewed es una fecha' do
      freshness = Assistant::GuideFreshness.new
      guides.each do |guide|
        guide.sources.each do |glob|
          files = freshness.files_for(guide.dup.tap { |g| g.sources = [glob] })
          expect(files).not_to be_empty, "#{guide.key}: sources sin archivos #{glob}"
        end
        expect { Date.iso8601(guide.reviewed) }.not_to raise_error, "#{guide.key}: reviewed inválido" if guide.reviewed
      end
    end

    it 'cada área del menú tiene al menos una guía' do
      covered = guides.flat_map(&:areas)
      expect(AccessRole::AREAS - covered).to be_empty
    end

    it 'las claves no se repiten' do
      expect(guides.map(&:key).uniq.size).to eq(guides.size)
    end
  end

  describe '.search' do
    it 'encuentra la guía por sus palabras' do
      expect(described_class.search('¿cómo creo un contrato?', admin).first[:key]).to eq('contratos')
      expect(described_class.search('para qué sirve el embudo de contactos', admin).first[:key]).to eq('embudo_contactos')
      expect(described_class.search('cómo concluyo una tarea', admin).first[:key]).to eq('agenda')
    end

    it 'aguanta las faltas de ortografía comunes (c/s/z, v/b, ll/y, h)' do
      expect(described_class.search('se puedem hacer mensiones en chat con clientes', admin).first[:key]).to eq('conversaciones')
      expect(described_class.search('como hago una cotisacion', admin).first[:key]).to eq('cotizaciones')
      expect(described_class.search('como instalo la app en mi selular', admin).first[:key]).to eq('dali_telefono')
    end

    it 'el verbo poder no cuenta («puedo», «pueden», «puedem»)' do
      expect(described_class.words_of('¿se pueden hacer menciones? puedem podemos')).to eq(%w[menciones])
    end

    it 'no devuelve nada si no hay coincidencia' do
      expect(described_class.search('xyzzy plugh', admin)).to eq([])
      expect(described_class.search('¿cómo?', admin)).to eq([])
    end

    it 'no muestra guías de áreas que el usuario no tiene' do
      keys = described_class.search('contrato organización cliente', grant_with('agenda')).pluck(:key)
      expect(keys).not_to include('clientes', 'contratos', 'organizaciones')
    end
  end

  describe '.find' do
    it 'respeta el área' do
      expect(described_class.find('ventas', admin)).to be_present
      expect(described_class.find('ventas', grant_with('agenda'))).to be_nil
      expect(described_class.find('dali', grant_with)).to be_present
    end
  end

  describe '.all (de dónde salen)' do
    let(:slug) { "ayuda-dali-spec-#{SecureRandom.hex(3)}" }
    let(:owner) { create(:account) }
    let(:other_account) { create(:account) }
    let(:author) { create(:user, account: owner, role: :administrator) }

    around { |example| ClimateControl.modify(PLATFORM_HELP_PORTAL_SLUG: slug) { example.run } }

    def publish_guide(portal, key, status: :published, **meta)
      create(:article, portal: portal, account_id: owner.id, author_id: author.id, title: key.titleize, status: status, locale: 'es',
                       slug: "#{key.dasherize}-#{SecureRandom.hex(3)}", content: "## Para qué sirve\nTexto de #{key}.",
                       meta: { 'guide_key' => key, 'areas' => [], 'keywords' => ['palabra'] }.merge(meta))
    end

    it 'sin portal usa los archivos' do
      expect(described_class.all.map(&:key)).to eq(described_class.load_files.map(&:key))
    end

    it 'con portal usa sus artículos publicados con clave, ordenados por clave, sin importar la cuenta' do
      portal = create(:portal, slug: slug, account_id: owner.id, config: { allowed_locales: ['es'], default_locale: 'es' })
      publish_guide(portal, 'zeta', 'areas' => %w[sales], 'pages' => %w[case], 'sources' => ['a.rb'], 'reviewed' => '2026-11-20')
      publish_guide(portal, 'alfa')
      publish_guide(portal, 'borrador', status: :draft)
      # Uno sin clave (p. ej. de antes): el portal le pone clave a lo nuevo, así que se le quita a mano.
      create(:article, portal: portal, account_id: owner.id, author_id: author.id, locale: 'es').update_column(:meta, {}) # rubocop:disable Rails/SkipsModelValidations

      expect(described_class.all.map(&:key)).to eq(%w[alfa zeta])
      zeta = described_class.all.last
      expect(zeta).to have_attributes(title: 'Zeta', areas: %w[sales], keywords: ['palabra'], pages: %w[case],
                                      sources: ['a.rb'], reviewed: '2026-11-20', body: "## Para qué sirve\nTexto de zeta.")

      Current.account = other_account
      expect(described_class.search('palabra zeta', admin).pluck(:key)).to include('zeta')
    ensure
      Current.reset
    end

    it 'si el portal no tiene guías vuelve a los archivos' do
      create(:portal, slug: slug, account_id: owner.id)
      expect(described_class.all.map(&:key)).to eq(described_class.load_files.map(&:key))
    end
  end
end
