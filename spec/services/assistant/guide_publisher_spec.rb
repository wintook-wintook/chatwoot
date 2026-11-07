# frozen_string_literal: true

require 'rails_helper'

# Guías del repo → artículos del Centro de ayuda global (un portal para todos los clientes).
RSpec.describe Assistant::GuidePublisher do
  let(:account) { create(:account) }
  # Los slugs de artículo son únicos en toda la base y la de pruebas es la de desarrollo
  # (que ya tiene el portal publicado): cada ejemplo usa su propio prefijo.
  let(:prefix) { "spec#{SecureRandom.hex(3)}-" }
  let!(:admin) { create(:user, account: account, role: :administrator) }
  let(:portal) { described_class.create_portal!(account: account) }

  def guide(key, title: key.titleize, areas: ['agenda'], body: "## Para qué sirve\nTexto de #{key}.", category: nil)
    Assistant::Guides::Guide.new(key: key, title: title, areas: areas, keywords: %w[uno dos], pages: [], body: body,
                                 category: category)
  end

  def publish(guides)
    described_class.new(portal: portal, guides: guides).call
  end

  around do |example|
    ClimateControl.modify(PLATFORM_HELP_PORTAL_SLUG: "ayuda-spec-#{SecureRandom.hex(3)}", FRONTEND_URL: 'https://app.test') do
      example.run
    end
  end

  before { stub_const("#{described_class}::SLUG_PREFIX", prefix) }

  it 'crea un artículo publicado por guía, en la categoría de su área' do
    result = publish([guide('agenda'), guide('dali', areas: []), guide('casos', category: 'Primeros pasos')])
    expect(result.created).to eq(%w[agenda dali casos])

    agenda = portal.articles.find_by(slug: "#{prefix}agenda")
    expect(agenda).to have_attributes(title: 'Agenda', status: 'published', locale: 'es', author_id: admin.id,
                                      content: "## Para qué sirve\nTexto de agenda.")
    expect(agenda.category.name).to eq('Agenda')
    expect(portal.articles.find_by(slug: "#{prefix}dali").category.name).to eq('Primeros pasos')
    expect(portal.articles.find_by(slug: "#{prefix}casos").category.name).to eq('Primeros pasos')
  end

  it 'no toca lo que no cambió y actualiza lo que sí' do
    publish([guide('agenda'), guide('dali', areas: [])])
    result = publish([guide('agenda', body: "## Para qué sirve\nNuevo."), guide('dali', areas: [])])
    expect(result.updated).to eq(['agenda'])
    expect(result.unchanged).to eq(['dali'])
    expect(portal.articles.find_by(slug: "#{prefix}agenda").content).to include('Nuevo.')
  end

  it 'archiva el artículo de una guía que ya no existe' do
    publish([guide('agenda'), guide('vieja')])
    result = publish([guide('agenda')])
    expect(result.archived).to eq(['vieja'])
    expect(portal.articles.find_by(slug: "#{prefix}vieja")).to be_archived
  end

  it 'da el enlace público del artículo para que Dali lo comparta' do
    portal
    publish([guide('agenda')])
    expect(described_class.article_url('agenda')).to eq("https://app.test/hc/#{portal.slug}/articles/#{prefix}agenda")
    expect(described_class.article_url('no-existe')).to be_nil
  end

  it 'publica las guías reales del repo sin errores' do
    result = described_class.new(portal: portal).call
    expect(result.created.size).to eq(Assistant::Guides.all.size)
  end
end
