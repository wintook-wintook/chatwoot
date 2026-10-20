# frozen_string_literal: true

# proyecto@adaptar_prompts_publicados (F0)
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::AdaptationInventory do
  let(:account) { create(:account) }

  def inventario(texto, template: nil)
    described_class.new(texto, account: account, template: template).call
  end

  def item(items, key)
    items.find { |i| i[:key] == key }
  end

  def source(source_type, name)
    KnowledgeSource.create!(account: account, source_type: source_type, name: name, status: 'active')
  end

  it 'sin texto no hay nada que configurar' do
    expect(inventario('')).to eq([])
  end

  describe 'variables <PENDIENTE: X>' do
    let(:texto) do
      "Eres el asistente de <PENDIENTE: Nombre del negocio>.\n" \
        "Horario: <PENDIENTE: Horario>.\n" \
        'Despídete como <PENDIENTE: nombre del negocio>.'
    end

    it 'agrupa las marcas por etiqueta, sin importar mayúsculas' do
      items = inventario(texto)
      negocio = item(items, 'var:nombre del negocio')

      expect(negocio).to include(kind: 'variable', name: 'Nombre del negocio', status: 'missing',
                                 fix: 'text', group: :business, occurrences: 2, line: 1)
      expect(item(items, 'var:horario')).to include(occurrences: 1, line: 2)
    end
  end

  describe 'fuentes que se nombran' do
    before { account.enable_features!('google_calendar') }

    it 'cruza {{doc:}} con la cuenta: la que existe sale ok, la que no se puede crear ahí mismo' do
      source('google_doc', 'Precios')
      items = inventario("Usa {{doc:precios}}.\nY también {{doc:Garantías}}.")

      expect(item(items, 'google_doc:precios')).to include(status: 'ok')
      expect(item(items, 'google_doc:garantías')).to include(
        status: 'missing', fix: 'create_inline', line: 2,
        create: { source_type: 'google_doc', name: 'Garantías' }, options: ['Precios']
      )
    end

    it 'lee las directivas también en la prosa, fuera de las líneas @ruta' do
      items = inventario("[ROL]\nConsulta {{hoja:Catalogo}} antes de contestar.")

      expect(item(items, 'google_sheet:catalogo')).to include(status: 'missing', group: :sources)
    end

    it '@buscar_foro se crea como fuente de Discourse (igual que sourceDirective.js)' do
      items = inventario('@ruta(soporte: fallas): @buscar_foro(Foro Kontrolya) -> @crear_ticket(tipo=Soporte)')

      expect(item(items, 'knowledge_source:foro kontrolya')).to include(
        create: { source_type: 'discourse', name: 'Foro Kontrolya' }
      )
    end

    it '{{hoja_buscar:}} pide la hoja, no la directiva entera' do
      items = inventario('{{hoja_buscar: Gruas | marca=? | precio}}')

      expect(item(items, 'sheet_lookup:gruas')).to include(
        name: 'Gruas', status: 'missing', create: { source_type: 'google_sheet', name: 'Gruas' }
      )
    end

    it 'avisa cuando la fuente Google existe pero la cuenta no tiene Google habilitado' do
      account.disable_features!('google_calendar')
      source('google_doc', 'Precios')

      expect(item(inventario('{{doc:Precios}}'), 'google_doc:precios')).to include(
        status: 'missing', reason: 'google_disabled'
      )
    end
  end

  describe '{{consulta:}} del ERP' do
    it 'sin conexión, lleva a crearla en Base de Conocimiento' do
      items = inventario('{{consulta:sae/saldo_cliente(rfc=?)}}')

      expect(item(items, 'erp_query:sae/saldo_cliente')).to include(
        status: 'missing', fix: 'link', link: { route: 'knowledge_sources_list', query: { tab: 'erp' } }
      )
    end

    it 'con conexión pero sin esa consulta, ofrece las de la conexión' do
      conexion = ExternalDbConnection.create!(account: account, name: 'SAE Servicios', engine: :firebird,
                                              erp_type: :sae, host: 'erp.test', port: 3050, database: 'db')
      conexion.external_db_queries.create!(account: account, name: 'saldo', sql_template: 'SELECT 1')

      expect(item(inventario('{{consulta:sae/saldo_cliente}}'), 'erp_query:sae/saldo_cliente')).to include(
        status: 'missing', fix: 'select', options: ['saldo']
      )
    end
  end

  describe 'archivos {{nombre}}' do
    let(:template) { create(:tracking_template, account: account) }

    it 'cruza con la pestaña Archivos del agente' do
      create(:ai_agent_attachment, tracking_template: template, name: 'catalogo')
      items = inventario('Manda {{catalogo}} y {{promo}}.', template: template)

      expect(item(items, 'attachment:catalogo')).to include(status: 'ok')
      expect(item(items, 'attachment:promo')).to include(status: 'missing', fix: 'upload')
    end
  end

  describe 'etiquetas y tipos de caso' do
    # 20/10/2026: las etiquetas van en el mensaje y las lee una automatización; no son
    # etiquetas de Chatwoot que haya que crear.
    it 'no pide las etiquetas de la ruta ni las de estado de la prosa' do
      texto = "@ruta(ventas #cotizacion: quiero precio): -\n[ETIQUETAS]\n#humano = pidió una persona"

      expect(inventario(texto)).to be_empty
    end

    it '@crear_ticket(tipo=X): elegir uno de la cuenta o crearlo en Tickets (solo administrador)' do
      CaseType.create!(account: account, name: 'Soporte', color: '#3b82f6')
      items = inventario('@crear_ticket(tipo=Ventas)')

      expect(item(items, 'case_type:ventas')).to include(
        status: 'missing', fix: 'select', options: ['Soporte'], admin_only: true,
        link: { route: 'gestorTickets_types' }
      )
    end

    it 'no pide un tipo que todavía es <PENDIENTE:> (eso ya sale como variable)' do
      items = inventario('@crear_ticket(tipo=<PENDIENTE: tipo de caso>)')

      expect(items.pluck(:kind)).to eq(['variable'])
    end
  end

  describe 'lo que se configura fuera del Asistente' do
    it 'calendario, predefinidas y discourse llevan su enlace' do
      items = inventario("@agendar_calendar\n@buscar_predefinidas(Precios)\n@discourse")

      expect(item(items, 'calendar')).to include(status: 'missing', fix: 'link', link: { route: 'google_calendar' })
      expect(item(items, 'canned_responses')).to include(status: 'missing', link: { route: 'canned_list' })
      expect(item(items, 'discourse')).to include(
        link: { route: 'settings_applications_integration', params: { integration_id: 'discourse' } }
      )
    end

    it 'la bandeja solo se pide en un agente guardado, con el enlace a su ficha' do
      template = create(:tracking_template, account: account, inbox_id: nil)

      expect(item(inventario('Hola', template: template), 'inbox')).to include(
        status: 'missing', link: { route: 'tracking_templates_list', query: { edit: template.id } }
      )
      expect(item(inventario('Hola'), 'inbox')).to be_nil
    end
  end

  it 'ordena por bloque: negocio, fuentes, tipos de caso, fuera del Asistente' do
    texto = "@agendar_calendar\n@crear_ticket(tipo=Ventas)\n{{doc:X}}\n<PENDIENTE: Horario>"

    expect(inventario(texto).pluck(:group).uniq).to eq(%i[business sources case_types outside])
  end
end
