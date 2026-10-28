# frozen_string_literal: true

require 'rails_helper'

# CrmZeus A0 — artículos catalogados / no catalogados, precios por lista e impuestos.
RSpec.describe CrmArticle do
  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:list_price) { account.crm_lookups.price_list.find_by!(name: 'Precio de lista') }
  let(:wholesale) { account.crm_lookups.create!(kind: :price_list, name: 'Precio de mayoreo') }
  let(:peso) { account.crm_currencies.find_by!(iso_code: 'MXN') }
  let(:iva) { account.crm_taxes.find_by!(name: 'IVA 16%') }

  before { Crm::DefaultCatalogs.ensure!(account) }

  def article(attrs = {})
    account.crm_articles.create!({ name: 'Casco de seguridad', unit: account.crm_units.find_by!(name: 'Pieza') }.merge(attrs))
  end

  it 'nace no catalogado, activo y almacenable' do
    record = article
    expect(record).to be_uncatalogued
    expect(record).to be_status_active
    expect(record.is_stockable).to be(true)
    expect(record.catalog_status_before_type_cast).to eq(2)
  end

  describe 'no se repiten clave ni nombre (entre catalogados y no catalogados)' do
    before { article(key: 'cas-01', catalog_status: :catalogued) }

    it 'compara el nombre sin acentos ni mayúsculas y avisa en el nombre' do
      dup = account.crm_articles.build(name: '  CASCO de   Ségúridad ')
      expect(dup).not_to be_valid
      expect(dup.errors[:name]).to include(described_class::DUPLICATE_MESSAGE)
      expect(dup.errors[:normalized_name]).to be_empty
    end

    it 'compara la clave en mayúsculas' do
      dup = account.crm_articles.build(name: 'Otro', key: ' CAS-01 ')
      expect(dup).not_to be_valid
      expect(dup.errors[:key]).to be_present
    end

    it 'en otra cuenta sí se puede repetir' do
      Crm::DefaultCatalogs.ensure!(other_account)
      expect(other_account.crm_articles.build(name: 'Casco de seguridad', key: 'CAS-01')).to be_valid
    end
  end

  it 'busca por nombre sin acentos o por clave' do
    article(key: 'CAS-01')
    article(name: 'Cañón de agua')
    expect(account.crm_articles.search('canon').pluck(:name)).to eq(['Cañón de agua'])
    expect(account.crm_articles.search('cas-01').count).to eq(1)
  end

  it 'lleva un precio por lista de precios, cada uno en su moneda' do
    record = article(prices_attributes: [{ price_list: list_price, price: 350.5, currency: peso },
                                         { price_list: wholesale, price: 300 }])
    expect(record.prices.map { |p| [p.price_list.name, p.price.to_f] }).to eq([['Precio de lista', 350.5], ['Precio de mayoreo', 300.0]])
    expect(record.prices.map(&:account_id).uniq).to eq([account.id])

    dup = record.prices.build(price_list: list_price, price: 1)
    expect(dup).not_to be_valid
  end

  it 'rechaza como lista de precios un valor de otro catálogo o de otra cuenta' do
    zone = account.crm_lookups.create!(kind: :zone, name: 'Norte')
    expect(article.prices.build(price_list: zone, price: 1)).not_to be_valid

    Crm::DefaultCatalogs.ensure!(other_account)
    foreign_list = other_account.crm_lookups.price_list.first
    expect(article(name: 'Otro').prices.build(price_list: foreign_list, price: 1)).not_to be_valid
  end

  it 'puede llevar varios impuestos (IVA + retención)' do
    retention = account.crm_taxes.create!(name: 'Retención IVA 10.67%', tax_type: :vat_withholding, percent: 10.67)
    record = article(taxes: [iva, retention])
    expect(record.taxes.map(&:name)).to contain_exactly('IVA 16%', 'Retención IVA 10.67%')
    expect(record.article_taxes.map(&:account_id).uniq).to eq([account.id])
    expect(retention).to be_withholding
  end

  it 'catalogar conserva el id y no se puede dos veces' do
    record = article
    id = record.id
    record.catalog!
    expect(record.reload).to be_catalogued
    expect(record.id).to eq(id)
    expect(record.cataloged_at).to be_present
    expect { record.catalog! }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'rechaza línea o unidad de otra cuenta' do
    Crm::DefaultCatalogs.ensure!(other_account)
    record = account.crm_articles.build(name: 'X', unit: other_account.crm_units.first)
    expect(record).not_to be_valid
    expect(record.errors[:unit]).to be_present
  end

  it 'acepta imagen y rechaza otro tipo de archivo' do
    record = article
    record.image.attach(io: StringIO.new('fake'), filename: 'casco.png', content_type: 'image/png')
    expect(record).to be_valid
    record.image.attach(io: StringIO.new('fake'), filename: 'ficha.pdf', content_type: 'application/pdf')
    expect(record).not_to be_valid
  end

  describe 'catálogos' do
    it 'precarga IVA 16 % (predeterminado), IVA 0 %, Exento, «Precio de lista» y pieza/servicio una sola vez' do
      Crm::DefaultCatalogs.ensure!(account)
      expect(account.crm_taxes.order(:id).map { |t| [t.name, t.tax_type, t.is_default] })
        .to eq([['IVA 16%', 'vat', true], ['IVA 0%', 'vat', false], ['Exento', 'vat_exempt', false]])
      expect(account.crm_lookups.price_list.pluck(:name)).to eq(['Precio de lista'])
      expect(account.crm_units.order(:id).pluck(:name, :sat_key)).to eq([%w[Pieza H87], %w[Servicio E48]])
    end

    it 'la línea solo acepta un grupo de líneas de la cuenta' do
      group = account.crm_lookups.create!(kind: :line_group, name: 'Artículos de protección')
      zone = account.crm_lookups.create!(kind: :zone, name: 'Norte')
      expect(account.crm_article_lines.create!(name: 'Cascos', key: 'cas', group: group).key).to eq('CAS')
      expect(account.crm_article_lines.build(name: 'Guantes', group: zone)).not_to be_valid
    end

    it 'la unidad normaliza la clave SAT' do
      expect(account.crm_units.create!(name: 'Kilogramo', sat_key: 'kgm').sat_key).to eq('KGM')
      expect(account.crm_units.build(name: 'Mala', sat_key: 'TOO-LONG')).not_to be_valid
    end
  end
end
