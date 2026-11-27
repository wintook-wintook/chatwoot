# frozen_string_literal: true

require 'rails_helper'

# Cotizaciones › Formatos — varios formatos por empresa, bloques, datos de la empresa, vista previa y PDF.
RSpec.describe 'Quote Formats API' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:url)     { "/api/v1/accounts/#{account.id}/quote_formats" }
  let(:headers) { admin.create_new_auth_token }
  let(:contact) { create(:contact, account: account, name: 'Dora Elizabeth') }

  def quote_with_items(attrs = {})
    quote = Quotes::Builder.new(account, admin).create!({ contact_id: contact.id }.merge(attrs))
    quote.items.create!(account: account, description: 'Instalación', quantity: 1, unit_price: 1000, tax_percent: 16)
    quote.recalculate!
    quote
  end

  it 'la primera vez crea el formato principal por omisión y regresa los datos de la empresa' do
    get url, headers: headers, as: :json
    body = response.parsed_body
    expect(body['formats'].size).to eq(1)
    expect(body['formats'].first).to include('is_default' => true)
    expect(body['formats'].first['settings']['blocks'].pluck('key')).to eq(QuoteFormat::BLOCKS)
    expect(body['can_edit']).to be(true)
  end

  it 'guarda solo lo que conoce, deja un solo formato por omisión y no borra el último' do
    get url, headers: headers, as: :json
    first = account.quote_formats.first
    post url, params: { quote_format: { name: 'Gobierno', is_default: true,
                                        settings: { brand: { color: '#112233', font: 'Comic Sans' }, hack: { x: 1 },
                                                    blocks: [{ key: 'items', on: true }, { key: 'header', on: false }] } } },
              headers: headers, as: :json
    format = account.quote_formats.find_by(name: 'Gobierno')
    expect(format.config['brand']).to include('color' => '#112233', 'font' => 'Inter')
    expect(format.settings).not_to have_key('hack')
    expect(format.config['blocks'].first(2)).to eq([{ 'key' => 'items', 'on' => true }, { 'key' => 'header', 'on' => false }])
    expect(first.reload.is_default).to be(false)

    delete "#{url}/#{format.id}", headers: headers, as: :json
    expect(first.reload.is_default).to be(true)
    delete "#{url}/#{first.id}", headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'la vista previa usa lo que está en pantalla, con los datos de la empresa y el total con letra' do
    patch "#{url}/company", params: { company: { legal_name: 'Kontrolya SA de CV', tax_id: 'KON010101AB1' } }, headers: headers, as: :json
    quote_with_items
    post "#{url}/preview", params: { settings: { totals: { amount_in_words: true }, intro: { text: 'Hola {{cliente}}' },
                                                 blocks: QuoteFormat::BLOCKS.map { |key| { key: key, on: true } } } },
                           headers: headers, as: :json
    html = response.parsed_body['html']
    expect(html).to include('Kontrolya SA de CV', 'KON010101AB1', 'Hola Dora Elizabeth', 'MIL CIENTO SESENTA PESOS 00/100 M.N.')
  end

  it 'la liga del cliente se ve con el formato de la cotización y su PDF sale con wkhtmltopdf' do
    format = account.quote_formats.create!(name: 'Simple', settings: { blocks: [{ key: 'items', on: true }],
                                                                       footer: { text: 'Gracias por su preferencia' } })
    quote = quote_with_items(quote_format_id: format.id)
    get "/cotizacion/#{quote.public_token}"
    expect(response.body).to include('Instalación')
    expect(response.body).not_to include('Gracias por su preferencia') # el pie está apagado

    skip 'sin wkhtmltopdf' unless Quotes::Pdf.available?
    get "/cotizacion/#{quote.public_token}/pdf"
    expect(response.media_type).to eq('application/pdf')
    expect(response.body).to start_with('%PDF')
  end

  it 'al mandar la cotización adjunta su PDF' do
    quote = quote_with_items
    inbox = create(:inbox, account: account)
    create(:conversation, account: account, inbox: inbox, contact: contact)
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('%PDF-1.4'), filename: 'COT.pdf', content_type: 'application/pdf')
    allow(Quotes::Pdf).to receive(:available?).and_return(true)
    allow(Quotes::Pdf).to receive(:new).and_return(instance_double(Quotes::Pdf, blob: blob))
    message = Quotes::Delivery.new(quote, admin).deliver!
    expect(message.attachments.first.file.filename.to_s).to eq('COT.pdf')
  end
end
