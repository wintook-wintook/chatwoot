# frozen_string_literal: true

# proyecto@asistente_agentes_ia — F6
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::DryRunService do
  let(:account) { create(:account) }

  def probar(draft, question = 'no puedo entrar al sistema')
    described_class.new(account, draft: draft, question: question).call
  end

  def canned_source
    KnowledgeSource.create!(account: account, source_type: 'canned_response', name: 'Respuestas', status: 'active')
  end

  describe 'entradas que no se pueden probar' do
    it 'rechaza una pregunta vacía' do
      expect(probar('@buscar_articulo', '   ').error).to eq(:blank_question)
    end

    it 'rechaza un Entrenamiento vacío' do
      expect(probar('').error).to eq(:blank_draft)
    end
  end

  describe 'rama' do
    # Con una sola rama el clasificador no le pregunta al modelo: la devuelve. Que la
    # prueba en seco tampoco gaste tokens ahí es parte del comportamiento, no un atajo
    # del spec — por eso la cuenta SÍ tiene key de OpenAI acá: si el servicio llamara,
    # webmock cortaría la conexión y el ejemplo fallaría.
    it 'con una sola rama la elige sin llamar al modelo' do
      account.hooks.create!(app_id: 'openai', status: 'enabled', settings: { 'api_key' => 'sk-test' })

      r = probar('@ruta(soporte #soporte: fallas): @buscar_articulo')

      expect(r.payload[:routes]).to include(chosen: 'soporte', single: true, declared: ['soporte'])
    end

    it 'informa las ramas declaradas y cuál es la por defecto' do
      draft = <<~T
        @ruta(soporte #soporte: fallas): @buscar_articulo
        @ruta(comercial #comercial: precios): @buscar_predefinidas
        @ruta_por_defecto: comercial
      T

      # Sin integración de OpenAI el clasificador no puede preguntar y cae a la por
      # defecto — el mismo camino que en producción cuando la llamada falla.
      expect(probar(draft).payload[:routes]).to include(
        declared: %w[soporte comercial], default: 'comercial', chosen: 'comercial', single: false
      )
    end

    it 'marca cuando el Entrenamiento no declara ninguna rama' do
      expect(probar('Sos un asesor amable.').payload[:routes]).to include(none_declared: true, chosen: nil)
    end

    it 'devuelve la etiqueta con la que cerraría el turno' do
      expect(probar('@ruta(soporte #soporte_tec: fallas): @buscar_articulo').payload[:tag]).to eq('#soporte_tec')
    end
  end

  describe 'fuente' do
    it 'dice que la rama no consulta nada cuando la fuente es un guion' do
      r = probar('@ruta(charla #charla: saludos): -')

      expect(r.payload[:source]).to include(directive: nil, reason: :no_source)
    end

    it 'avisa cuando la fuente está escrita pero el motor no la reconoce' do
      r = probar('@ruta(soporte #soporte: fallas): @buscar_lo_que_sea')

      expect(r.payload[:source]).to include(reason: :unreadable, directive: '@buscar_lo_que_sea')
    end

    it 'avisa cuando la fuente se entiende pero no existe en la cuenta' do
      r = probar('@ruta(soporte #soporte: fallas): @buscar_foro(Foro Que No Existe)')

      expect(r.payload[:source]).to include(mode: :knowledge_source, available: false, reason: :source_missing)
    end

    # @buscar_foro(NOMBRE) resuelve por nombre contra cualquier fuente activa (así lo
    # hace Directives.ready?); el tipo real de un foro es 'discourse'.
    it 'no ejecuta una fuente que consulta un servicio externo en vivo' do
      KnowledgeSource.create!(account: account, source_type: 'discourse', name: 'Foro', status: 'active')

      r = probar('@ruta(soporte #soporte: fallas): @buscar_foro(Foro)')

      expect(r.payload[:source]).to include(available: true, reason: :live_source)
      expect(r.payload[:source]).not_to have_key(:items)
    end

    # Sin ramas el motor lee la directiva suelta del prompt, por precedencia del
    # catálogo. La prueba en seco tiene que hacer lo mismo.
    it 'sin ramas toma la directiva suelta del prompt' do
      canned_source
      create(:knowledge_item, account: account, source_type: 'canned_response')

      r = probar('Sos un asesor. @buscar_predefinidas', 'hola')

      expect(r.payload[:source]).to include(mode: :canned_response)
    end
  end

  describe 'búsqueda real' do
    let(:source) { canned_source }

    before do
      create(:knowledge_item, account: account, knowledge_source: source, source_type: 'canned_response',
                              title: 'GESTION alta de usuario', content: 'Para dar de alta un usuario…')
      create(:knowledge_item, account: account, knowledge_source: source, source_type: 'canned_response',
                              title: 'HORARIO DE OFICINA', content: 'Atendemos de 9 a 18.')
    end

    it 'avisa cuando no se pudo vectorizar la pregunta' do
      allow_any_instance_of(described_class).to receive(:generate_embedding).and_return(nil) # rubocop:disable RSpec/AnyInstance

      expect(probar('@ruta(x #x: y): @buscar_predefinidas').payload[:source]).to include(reason: :embedding_failed)
    end

    # El grupo es la razón por la que esto no podía reusar KnowledgeBase::DirectiveRunner:
    # ese ignora el grupo, así que habría buscado en todo el corpus y a 0.20 mientras el
    # motor busca en el grupo y a 0.45 — fragmentos que en producción nunca salen.
    it 'aplica el umbral estrecho del grupo positivo' do
      allow_any_instance_of(described_class).to receive(:generate_embedding).and_return(Array.new(1536, 0.1)) # rubocop:disable RSpec/AnyInstance

      r = probar('@ruta(gestion #gestion: altas): @buscar_predefinidas(GESTION)')

      expect(r.payload[:source][:threshold]).to eq(KnowledgeBaseResponseService::GROUP_SIMILARITY_THRESHOLD)
    end

    it 'usa el umbral general sin grupo' do
      allow_any_instance_of(described_class).to receive(:generate_embedding).and_return(Array.new(1536, 0.1)) # rubocop:disable RSpec/AnyInstance

      r = probar('@ruta(gestion #gestion: altas): @buscar_predefinidas')

      expect(r.payload[:source][:threshold]).to eq(KnowledgeBaseResponseService::DEFAULTS['similarity_threshold'])
    end
  end

  describe 'caso' do
    it 'informa el tipo declarado y que ese tipo existe en la cuenta' do
      account.case_types.create!(name: 'Soporte')

      r = probar('@ruta(soporte #soporte: fallas): @buscar_articulo -> @crear_ticket(tipo=Soporte)')

      expect(r.payload[:case]).to include(creates: true, case_type: { name: 'Soporte', exists: true })
    end

    # Un tipo escrito que no existe no rompe nada: el intake infiere otro. Verlo antes
    # de guardar es justo el punto.
    it 'avisa cuando el tipo declarado no existe' do
      r = probar('@ruta(soporte #soporte: fallas): @buscar_articulo -> @crear_ticket(tipo=Inventado)')

      expect(r.payload[:case][:case_type]).to eq({ name: 'Inventado', exists: false })
    end

    it 'con escalamiento por rama, el caso se evalúa después de la fuente' do
      r = probar('@ruta(soporte #soporte: fallas): @buscar_articulo -> @crear_ticket')

      expect(r.payload[:case]).to include(creates: true, after_source: true, inherited_from_prompt: false)
    end

    # El hallazgo que más sorprende: una rama SIN flecha, en un agente donde otras sí
    # la tienen, no queda sin escalamiento — hereda el @crear_ticket suelto del prompt
    # y encima se adelanta a la fuente.
    it 'una rama sin flecha hereda la directiva del prompt y se adelanta a la fuente' do
      draft = <<~T
        Sos el asistente. @crear_ticket(tipo=General)
        @ruta(soporte #soporte: fallas): @buscar_articulo -> @crear_ticket(tipo=Soporte)
        @ruta(otros #otros: lo demas): @buscar_predefinidas
        @ruta_por_defecto: otros
      T

      expect(probar(draft).payload[:case]).to include(
        creates: true, inherited_from_prompt: true, after_source: false
      )
    end

    it 'sin escalamientos por rama, fallback=true manda el caso al final' do
      r = probar('@ruta(soporte #soporte: fallas): @buscar_articulo' \
                 "\n@crear_ticket(tipo=Soporte, fallback=true)")

      expect(r.payload[:case]).to include(creates: true, after_source: true)
    end

    it 'dice que no abre caso cuando no hay ninguna directiva de ticket' do
      expect(probar('@ruta(soporte #soporte: fallas): @buscar_articulo').payload[:case]).to include(creates: false)
    end
  end

  # ============================================================================
  # CONTRATO: ninguna fuente puede quedar sin clasificar en silencio
  # ============================================================================
  # Si mañana se agrega una fuente al catálogo (pasó con Google Docs, con Contpaq y
  # con WordPress), sin esto aparecería en pantalla como "no se puede probar en seco"
  # sin que nadie lo haya decidido. Así, rompe el spec y obliga a elegir.
  describe 'cobertura del catálogo de fuentes' do
    it 'clasifica todos los modos de KnowledgeBase::Directives' do
      modos = KnowledgeBase::Directives::SEARCH_DIRECTIVES.map { |(_re, mode, _named)| mode }
      modos += %i[canned_response erp_query]

      expect(described_class::MODE_EXECUTION.keys).to include(*modos.uniq)
    end
  end
end
