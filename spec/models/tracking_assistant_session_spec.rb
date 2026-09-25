# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe TrackingAssistantSession do
  let(:account) { create(:account) }
  let(:user)    { create(:user, account: account) }
  let(:otro)    { create(:user, account: account) }

  def sesion(attrs = {})
    described_class.create!({ account: account, user: user }.merge(attrs))
  end

  describe '.resumable_for' do
    # Verlas todas no significa que la pantalla arranque en la de otro.
    it 'no retoma sola la conversación de otra persona' do
      described_class.create!(account: account, user: otro)

      expect(described_class.resumable_for(account, user)).to be_nil
    end

    it 'devuelve la última conversación a medias de esa persona' do
      vieja = sesion
      nueva = sesion
      vieja.update!(updated_at: 2.hours.ago)

      expect(described_class.resumable_for(account, user)).to eq(nueva)
    end

    # Una entrevista es de quien la tuvo: retomar la de otro sería seguir una
    # conversación que no se leyó.
    it 'no ofrece la conversación de otra persona' do
      sesion(user: otro)

      expect(described_class.resumable_for(account, user)).to be_nil
    end

    it 'no ofrece una que ya terminó en un agente' do
      sesion(status: 'saved')

      expect(described_class.resumable_for(account, user)).to be_nil
    end

    it 'no cruza cuentas' do
      sesion

      expect(described_class.resumable_for(create(:account), user)).to be_nil
    end

    it 'devuelve nil cuando no hay ninguna' do
      expect(described_class.resumable_for(account, user)).to be_nil
    end
  end

  describe '#record_turn' do
    it 'guarda el hilo, el borrador y su comprobación' do
      s = sesion
      s.record_turn(messages: [{ 'role' => 'user', 'content' => 'hola' }],
                    draft: '@ruta(a #b: c): -', validation: { 'valid' => true })

      expect(s.reload.messages.size).to eq(1)
      expect(s.draft).to eq('@ruta(a #b: c): -')
      expect(s.validation).to eq('valid' => true)
    end

    # El borrador sobrevive a los turnos siguientes: el modelo puede volver a
    # preguntar después de haber entregado, y perderlo sería tirar el trabajo.
    it 'no pisa el borrador con un turno que no trae uno' do
      s = sesion
      s.record_turn(messages: [], draft: '@ruta(a #b: c): -')
      s.record_turn(messages: [{ 'role' => 'user', 'content' => 'otra cosa' }])

      expect(s.reload.draft).to eq('@ruta(a #b: c): -')
    end

    # Un hilo que se fue de las manos no debe crecer sin límite dentro del jsonb.
    it 'recorta el hilo al tope' do
      s = sesion
      largos = Array.new(described_class::MAX_MESSAGES + 10) { |i| { 'role' => 'user', 'content' => "m#{i}" } }

      s.record_turn(messages: largos)

      expect(s.reload.messages.size).to eq(described_class::MAX_MESSAGES)
      expect(s.messages.last['content']).to eq("m#{described_class::MAX_MESSAGES + 9}")
    end
  end

  describe '#mark_saved!' do
    it 'la cierra y la liga al agente que quedó' do
      s = sesion
      template = account.tracking_templates.create!(name: 'Soporte', objective: 'Resolver dudas')

      s.mark_saved!(template)

      expect(s.reload).to have_attributes(status: 'saved', tracking_template: template)
      expect(described_class.resumable_for(account, user)).to be_nil
    end

    # 25/09/2026: reabrir la sesión mostraba el texto de antes de las ediciones a mano.
    it 'guarda el texto que quedó en el agente, como versión «guardado»' do
      s = sesion(draft: 'viejo')
      template = account.tracking_templates.create!(name: 'Soporte', objective: 'Resolver dudas')

      s.mark_saved!(template, draft: "[ROL]\nnuevo")

      expect(s.reload.draft).to eq("[ROL]\nnuevo")
      expect(s.version_list.last).to include('source' => 'saved', 'summary' => 'Soporte')
    end
  end

  # 25/09/2026: todas las conversaciones de análisis se llamaban «Analiza mi prompt».
  it 'si el primer mensaje es solo «Analiza mi prompt», el título es la primera línea del prompt' do
    s = sesion(messages: [{ 'role' => 'user', 'content' => 'Analiza mi prompt' }],
               draft: "# PROMPT AGENTE NEOCLASE V8.4\n[ROL]\nx")

    expect(s.title).to eq('🔎 PROMPT AGENTE NEOCLASE V8.4')
  end

  describe 'guardado automático y bitácora' do
    it 'guarda lo editado a mano; pausas seguidas son una sola versión' do
      s = sesion
      s.autosave!("[ROL]\nuno")
      s.autosave!("[ROL]\nuno dos")
      s.autosave!("[ROL]\nuno dos tres")

      expect(s.reload.draft).to eq("[ROL]\nuno dos tres")
      expect(s.version_list.size).to eq(1)
      expect(s.title).to eq('[ROL]')
    end

    it 'cada versión dice qué partes cambiaron, cuántas líneas y lo que declaró el Asistente' do
      s = sesion
      s.add_version(draft: "[ROL]\nAmable.\n\n[ESTILO]\nBreve.", source: 'loaded')
      s.add_version(draft: "[ROL]\nAmable.\n\n[ESTILO]\nBreve y claro.\nSin emojis.", source: 'assistant',
                    notes: ['~ [ESTILO]: más claro'])

      expect(s.version_list.last).to include('changes' => ['~ [ESTILO]'], 'lines' => { 'added' => 2, 'removed' => 1 },
                                             'notes' => ['~ [ESTILO]: más claro'])
    end
  end

  describe 'validaciones' do
    it 'rechaza un estado que no existe' do
      expect(described_class.new(account: account, user: user, status: 'raro')).not_to be_valid
    end
  end

  describe '.listable_for' do
    it 'muestra las abiertas y las que terminaron en un agente' do
      abierta = sesion
      guardada = sesion(status: 'saved')

      expect(described_class.listable_for(account)).to contain_exactly(abierta, guardada)
    end

    # Descartar no borra la fila: la saca de la vista. Un clic de más en una
    # entrevista de 40 minutos no debería ser irreversible.
    it 'no muestra las descartadas' do
      sesion(status: 'discarded')

      expect(described_class.listable_for(account)).to be_empty
    end

    # Se comparten entre administradores: el Entrenamiento de un Agente IA es
    # trabajo del equipo y quedaba escondido en la conversación de quien lo armó.
    it 'muestra también las de otra persona de la cuenta' do
      ajena = sesion(user: otro)

      expect(described_class.listable_for(account)).to include(ajena)
    end

    it 'no muestra las de otra cuenta' do
      propia = sesion
      otra = create(:account)
      described_class.create!(account: otra, user: create(:user, account: otra))

      expect(described_class.listable_for(account)).to contain_exactly(propia)
    end

    it 'las ordena de la más reciente a la más vieja' do
      vieja = sesion
      nueva = sesion
      vieja.update!(updated_at: 3.days.ago)

      expect(described_class.listable_for(account).to_a).to eq([nueva, vieja])
    end
  end

  # Lo que hace elegible una conversación en el listado: de qué trataba y si el
  # borrador servía.
  describe 'cómo se presenta en el listado' do
    it 'usa el primer mensaje de la persona como título' do
      s = sesion(messages: [{ 'role' => 'user', 'content' => '  quiero un agente de soporte  ' },
                            { 'role' => 'assistant', 'content' => '¿qué temas?' }])

      expect(s.title).to eq('quiero un agente de soporte')
    end

    it 'recorta un título largo' do
      s = sesion(messages: [{ 'role' => 'user', 'content' => 'a' * 200 }])

      expect(s.title.length).to be <= 80
    end

    # El primer mensaje de un agente armado desde instrucciones iniciales es el encargo
    # completo para el modelo: en el listado va el nombre del archivo.
    it 'si arrancó desde instrucciones iniciales, usa el nombre del archivo' do
      mensaje = "#{ContactTrackings::Assistant::BriefComposer::HEADER_START}: la idea de cómo lo quiere la " \
                'persona, ya leída y resumida del archivo «encargo_gimnasio.md». Escribilo…'
      s = sesion(messages: [{ 'role' => 'user', 'content' => mensaje }])

      expect(s.title).to eq('📎 encargo_gimnasio.md')
    end

    # Las guardadas antes del 23/09/2026 empiezan con el texto viejo («ENCARGO», voseo).
    it 'reconoce también el inicio viejo de las instrucciones iniciales' do
      viejo = ContactTrackings::Assistant::BriefComposer::LEGACY_HEADER_STARTS.first
      s = sesion(messages: [{ 'role' => 'user', 'content' => "#{viejo}: … del archivo «cobranza.md». …" }])

      expect(s.title).to eq('📎 cobranza.md')
    end

    it 'no toma como título lo que dijo el asistente' do
      s = sesion(messages: [{ 'role' => 'assistant', 'content' => 'hola, ¿en qué te ayudo?' }])

      expect(s.title).to be_nil
    end

    it 'cuenta las ramas del último borrador sin volver a parsearlo' do
      s = sesion(validation: { 'routes' => [{ 'name' => 'a' }, { 'name' => 'b' }] })

      expect(s.route_count).to eq(2)
    end

    it 'cuenta cero cuando todavía no hay borrador' do
      expect(sesion.route_count).to eq(0)
    end
  end

  # Fase D de PROMPT STUDIO: las versiones del Entrenamiento en la conversación.
  describe 'versiones' do
    let(:sesion) { sesion_de_prueba }

    def sesion_de_prueba
      described_class.new(account: account, user: user)
    end

    it 'numera las versiones y guarda de dónde salió cada una' do
      sesion.add_version(draft: 'uno', source: 'loaded')
      sesion.add_version(draft: 'dos', source: 'manual', summary: '~ [ESTILO]')
      sesion.add_version(draft: 'tres', source: 'assistant',
                         validation: { routes: [{}, {}], blocking: [{}] })

      expect(sesion.version_list.map { |v| v.slice('n', 'source') })
        .to eq([{ 'n' => 1, 'source' => 'loaded' }, { 'n' => 2, 'source' => 'manual' },
                { 'n' => 3, 'source' => 'assistant' }])
      expect(sesion.version_list.last).to include('routes' => 2, 'blocking' => 1)
    end

    # Una edición rechazada devuelve el mismo texto que había: no es otra versión.
    it 'no repite una versión con el mismo texto que la última' do
      sesion.add_version(draft: 'uno', source: 'assistant')
      sesion.add_version(draft: 'uno', source: 'manual')

      expect(sesion.version_list.size).to eq(1)
    end

    # La lista viaja en cada turno: con prompts de 17.000 caracteres no puede llevar
    # los textos.
    it 'lista las versiones sin el texto, y lo da de a una' do
      sesion.add_version(draft: 'el texto largo', source: 'assistant')

      expect(sesion.version_list.first).not_to have_key('draft')
      expect(sesion.version(1)['draft']).to eq('el texto largo')
      expect(sesion.version(99)).to be_nil
    end

    it 'conserva solo las últimas, sin renumerar' do
      (described_class::MAX_VERSIONS + 2).times { |i| sesion.add_version(draft: "v#{i}", source: 'assistant') }

      expect(sesion.version_list.size).to eq(described_class::MAX_VERSIONS)
      expect(sesion.version_list.first['n']).to eq(3)
    end

    it 'ignora un origen desconocido o un texto vacío' do
      sesion.add_version(draft: 'x', source: 'inventado')
      sesion.add_version(draft: '', source: 'manual')

      expect(sesion.version_list).to be_empty
    end
  end
end
