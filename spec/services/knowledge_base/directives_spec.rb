# frozen_string_literal: true

# proyecto@contact_tracking — catálogo único de directivas
require 'rails_helper'

RSpec.describe KnowledgeBase::Directives do
  describe '.detect' do
    it 'reconoce cada directiva del catálogo' do
      expect(described_class.detect('@buscar_predefinidas')).to eq({ mode: :canned_response, group: nil })
      expect(described_class.detect('@buscar_articulo')).to eq({ mode: :article })
      expect(described_class.detect('@discourse')).to eq({ mode: :discourse_integration })
    end

    it 'extrae el grupo de @buscar_predefinidas(GRUPO), incluido el negado' do
      expect(described_class.detect('@buscar_predefinidas(COMERCIAL)'))
        .to eq({ mode: :canned_response, group: 'COMERCIAL' })
      expect(described_class.detect('@buscar_predefinidas(!COMERCIAL)'))
        .to eq({ mode: :canned_response, group: '!COMERCIAL' })
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

    it 'reconoce @soporte_contpaq con el nombre de la fuente' do
      expect(described_class.detect('@soporte_contpaq(Agente de Servicio CONTPAQi)'))
        .to eq({ mode: :contpaq_support, source_name: 'Agente de Servicio CONTPAQi' })
    end

    it 'no le da a @soporte_contpaq precedencia sobre las directivas ya existentes' do
      # Va ultima en la cadena a proposito: adelantarla cambiaria la fuente de los
      # agentes que ya estan configurados.
      expect(described_class.detect("@soporte_contpaq(X)\n@discourse"))
        .to eq({ mode: :discourse_integration })
      expect(described_class.detect("@soporte_contpaq(X)\n@buscar_predefinidas"))
        .to eq({ mode: :canned_response, group: nil })
    end

    it 'devuelve nil cuando no hay ninguna directiva' do
      expect(described_class.detect('texto sin directivas')).to be_nil
    end

    it 'respeta la precedencia: gana la primera de la cadena' do
      expect(described_class.detect("@discourse\n@buscar_predefinidas")).to eq({ mode: :canned_response, group: nil })
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

    it 'exige una fuente contpaq_support activa con ese nombre' do
      directive = { mode: :contpaq_support, source_name: 'Agente CONTPAQi' }
      expect(described_class.ready?(directive, account: account, inbox_id: inbox.id)).to be(false)

      account.knowledge_sources.create!(name: 'Agente CONTPAQi', source_type: 'contpaq_support',
                                        config: { 'base_url' => 'https://example.test/v1' })
      expect(described_class.ready?(directive, account: account, inbox_id: inbox.id)).to be(true)
    end

    it 'no confunde una fuente de otro tipo que se llame igual' do
      account.knowledge_sources.create!(name: 'Foro Kontrolya', source_type: 'discourse', config: {})
      directive = { mode: :contpaq_support, source_name: 'Foro Kontrolya' }
      expect(described_class.ready?(directive, account: account, inbox_id: inbox.id)).to be(false)
    end

    it 'no considera disponible una hoja si la cuenta no tiene la feature de Google' do
      directive = { mode: :google_sheet, source_name: 'X' }
      expect(described_class.ready?(directive, account: account, inbox_id: inbox.id)).to be(false)
    end
  end

  # @knowledge_sources — la fuente WordPress
  describe '.detect con @buscar_sitio' do
    it 'reconoce la directiva y se queda con el nombre del sitio' do
      expect(described_class.detect('@buscar_sitio(Blog Kontrolya)'))
        .to eq(mode: :wordpress, source_name: 'Blog Kontrolya')
    end

    it 'acepta el nombre con espacios y acentos' do
      expect(described_class.detect('@buscar_sitio(Sitio de Atención)')[:source_name])
        .to eq('Sitio de Atención')
    end

    it 'no la confunde con las otras directivas de búsqueda' do
      expect(described_class.detect('@buscar_foro(Foro X)')[:mode]).to eq(:knowledge_source)
      expect(described_class.detect('@buscar_articulo')[:mode]).to eq(:article)
    end

    it 'no la reconoce sin paréntesis: el nombre es obligatorio' do
      expect(described_class.detect('@buscar_sitio')).to be_nil
    end

    # El comentario de SEARCH_DIRECTIVES lo pide explícitamente: adelantar una
    # fuente cambiaría la que usan los agentes ya configurados.
    it 'está al final de la tabla de precedencia' do
      expect(described_class::SEARCH_DIRECTIVES.last[1]).to eq(:wordpress)
    end

    # Si en la misma rama conviven dos fuentes, gana la primera del catálogo. Que
    # wordpress esté al final significa que nunca le roba el turno a otra.
    it 'cede ante una fuente más antigua en la misma línea' do
      expect(described_class.detect('@buscar_articulo @buscar_sitio(Blog)')[:mode]).to eq(:article)
    end
  end

  # La rama tiene que llegar entera al motor: nombre, etiqueta, fuente y escalamiento.
  describe 'dentro de una @ruta' do
    it 'parsea una rama que usa el sitio como fuente' do
      texto = '@ruta(sitio #soporte1: novedades, precios): @buscar_sitio(Blog Kontrolya) -> @crear_ticket(tipo=Soporte)'

      ruta = ContactTrackings::RouteMap.parse(texto).routes.first

      expect(ruta.name).to eq('sitio')
      expect(ruta.directive).to eq('@buscar_sitio(Blog Kontrolya)')
      expect(ruta.escalation).to eq('@crear_ticket(tipo=Soporte)')
      expect(described_class.detect(ruta.directive)[:mode]).to eq(:wordpress)
    end
  end

  describe 'la fuente en el modelo' do
    let(:account) { create(:account) }

    it 'acepta una fuente de tipo wordpress' do
      source = KnowledgeSource.new(account: account, source_type: 'wordpress', name: 'Blog')

      expect(source).to be_valid
    end

    # Direccionada por nombre, como el foro: una cuenta puede conectar más de un
    # sitio, así que el nombre tiene que ser único para que la directiva no ambigüe.
    it 'exige que el nombre sea único en la cuenta' do
      KnowledgeSource.create!(account: account, source_type: 'wordpress', name: 'Blog')
      repetida = KnowledgeSource.new(account: account, source_type: 'wordpress', name: 'blog')

      expect(repetida).not_to be_valid
    end

    it 'permite dos sitios distintos en la misma cuenta' do
      KnowledgeSource.create!(account: account, source_type: 'wordpress', name: 'Blog')
      otro = KnowledgeSource.new(account: account, source_type: 'wordpress', name: 'Tienda')

      expect(otro).to be_valid
    end
  end

  # Sin el caso :wordpress en ready?, la directiva cae en `else false`: el motor da
  # la rama por no disponible, kbase_available? devuelve false y el agente NUNCA
  # consulta el sitio. Parsea perfecto y no hace nada.
  describe '.ready? con @buscar_sitio' do
    let(:account) { create(:account) }
    let(:source) do
      KnowledgeSource.create!(account: account, source_type: 'wordpress', name: 'Blog', status: 'active')
    end

    def indexar(src)
      KnowledgeItem.create!(account: account, knowledge_source_id: src.id, source_type: 'wordpress',
                            source_id: 1, chunk_index: 0, content: 'algo indexado', title: 'T')
    end

    it 'da por disponible un sitio activo con contenido indexado' do
      indexar(source)

      expect(described_class.available?('@buscar_sitio(Blog)', account: account, inbox_id: nil)).to be(true)
    end

    it 'no le importa la capitalización del nombre' do
      indexar(source)

      expect(described_class.available?('@buscar_sitio(blog)', account: account, inbox_id: nil)).to be(true)
    end

    # Un sitio conectado del que todavía no se eligió nada no puede resolver un
    # turno: dar la rama por disponible haría que el agente busque en el vacío.
    it 'no da por disponible un sitio sin nada indexado' do
      source

      expect(described_class.available?('@buscar_sitio(Blog)', account: account, inbox_id: nil)).to be(false)
    end

    it 'no da por disponible un sitio inactivo' do
      indexar(source)
      source.update!(status: 'inactive')

      expect(described_class.available?('@buscar_sitio(Blog)', account: account, inbox_id: nil)).to be(false)
    end

    it 'no da por disponible un sitio que no existe' do
      expect(described_class.available?('@buscar_sitio(Fantasma)', account: account, inbox_id: nil)).to be(false)
    end
  end
end
