# frozen_string_literal: true

# proyecto@contact_tracking — catálogo único de directivas
require 'rails_helper'

RSpec.describe KnowledgeBase::Directives do
  describe '.detect' do
    it 'reconoce cada directiva del catálogo' do
      expect(described_class.detect('@buscar_predefinidas')).to eq({ mode: :canned_response })
      expect(described_class.detect('@buscar_articulo')).to eq({ mode: :article })
      expect(described_class.detect('@discourse')).to eq({ mode: :discourse_integration })
    end

    it 'acepta @buscar_articulo con y sin tilde' do
      expect(described_class.detect('@buscar_artículo')).to eq({ mode: :article })
    end

    it 'extrae el nombre de la fuente en las directivas parametrizadas' do
      expect(described_class.detect('@buscar_foro(Foro Kontrolya)'))
        .to eq({ mode: :knowledge_source, source_name: 'Foro Kontrolya' })
      expect(described_class.detect('{{hoja:Info Licencia}}'))
        .to eq({ mode: :google_sheet, source_name: 'Info Licencia' })
      expect(described_class.detect('{{doc:Manual}}'))
        .to eq({ mode: :google_doc, source_name: 'Manual' })
    end

    it 'devuelve nil cuando no hay ninguna directiva' do
      expect(described_class.detect('texto sin directivas')).to be_nil
    end

    it 'respeta la precedencia: gana la primera de la cadena' do
      expect(described_class.detect("@discourse\n@buscar_predefinidas")).to eq({ mode: :canned_response })
      expect(described_class.detect("@discourse\n{{hoja:X}}")).to eq({ mode: :google_sheet, source_name: 'X' })
    end
  end

  describe '.ready?' do
    let(:account) { create(:account) }
    let(:inbox)   { create(:inbox, account: account) }

    it 'es false cuando la directiva es nil' do
      expect(described_class.ready?(nil, account: account, inbox_id: inbox.id)).to be(false)
    end

    it 'exige que existan items para las fuentes vectoriales' do
      directive = { mode: :canned_response }
      expect(described_class.ready?(directive, account: account, inbox_id: inbox.id)).to be(false)
    end

    it 'exige el hook de discourse habilitado en ese inbox' do
      directive = { mode: :discourse_integration }
      expect(described_class.ready?(directive, account: account, inbox_id: inbox.id)).to be(false)

      create(:integrations_hook, account: account, inbox: inbox, app_id: 'discourse', status: 'enabled',
                                 settings: { 'url' => 'https://foro.example.com', 'api_key' => 'k' })
      expect(described_class.ready?(directive, account: account, inbox_id: inbox.id)).to be(true)
    end

    it 'no considera disponible una hoja si la cuenta no tiene la feature de Google' do
      directive = { mode: :google_sheet, source_name: 'X' }
      expect(described_class.ready?(directive, account: account, inbox_id: inbox.id)).to be(false)
    end
  end
end
