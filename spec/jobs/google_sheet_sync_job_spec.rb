require 'rails_helper'

RSpec.describe GoogleSheetSyncJob do
  let(:account) { create(:account) }
  let!(:integration) do
    UserCalendarIntegration.create!(account: account, user: create(:user, account: account),
                                    google_email: 'agenda@gruas.com', tokens: {})
  end
  let(:table) do
    { headers: %w[remolque Calendar_ID],
      rows: [{ 'remolque' => 'TP-64', 'Calendar_ID' => 'cal-64' },
             { 'remolque' => 'TP-63', 'Calendar_ID' => 'cal-63' }] }
  end
  let(:sheets) { instance_double(GoogleSheetsService, read_table: table, file_metadata: { 'modifiedTime' => 't1' }) }

  before do
    allow(GoogleSheetsService).to receive(:new).and_return(sheets)
    allow_any_instance_of(described_class).to receive(:generate_embedding).and_return(Array.new(1536, 0.0)) # rubocop:disable RSpec/AnyInstance
  end

  def source_in(mode)
    create(:knowledge_source, account: account, source_type: 'google_sheet', name: 'Servicio Gruas',
                              config: { 'file_id' => 'f1', 'sheet_mode' => mode, 'integration_id' => integration.id })
  end

  def sync(source)
    described_class.perform_now(action: 'upsert', source_id: source.id, account_id: account.id)
  end

  # {{hoja_buscar:}} busca exacto por columna: sin las filas crudas, una hoja FAQ no se podía consultar.
  it 'en modo FAQ guarda las filas crudas además de vectorizarlas' do
    source = source_in('faq')
    sync(source)

    expect(source.google_sheet_rows.order(:row_index).pluck(:data)).to eq(table[:rows])
    expect(account.knowledge_items.where(source_type: 'google_sheet', source_id: source.id).count).to eq(2)
  end

  it 'en modo Datos sigue guardando las filas crudas y un solo resumen' do
    source = source_in('data')
    sync(source)

    expect(source.google_sheet_rows.count).to eq(2)
    expect(account.knowledge_items.where(source_type: 'google_sheet', source_id: source.id).count).to eq(1)
  end

  it 'al volver a sincronizar reemplaza las filas, no las duplica' do
    source = source_in('faq')
    2.times { sync(source) }

    expect(source.google_sheet_rows.count).to eq(2)
  end
end
