require 'rails_helper'

RSpec.describe ContactTrackings::SheetLookup do
  let(:account) { create(:account) }
  let(:embed) { 'https://calendar.google.com/calendar/embed?src=cal64%40group.calendar.google.com&ctz=America%2FMexico_City' }
  let!(:source) do
    create(:knowledge_source, account: account, source_type: 'google_sheet', name: 'Servicio Gruas',
                              config: { 'sheet_mode' => 'faq' })
  end
  let(:conversation) { create(:conversation, account: account) }

  before do
    [%w[TP-64 60 activo], %w[TP-63 40.8 activo], %w[TP-6 30 baja]].each_with_index do |(remolque, peso, estatus), i|
      GoogleSheetRow.create!(account: account, knowledge_source: source, row_index: i,
                             data: { 'remolque' => remolque, 'peso_max_t' => peso, 'estatus' => estatus,
                                     'Calendar_ID' => i.zero? ? embed : "cal#{remolque}" })
    end
  end

  def lookup(inner, conv: nil)
    described_class.new(account, described_class.parse(inner), conversation: conv).call
  end

  def say(content, type = :incoming)
    create(:message, account: account, inbox: conversation.inbox, conversation: conversation,
                     message_type: type, content: content)
  end

  describe '.parse' do
    it 'lee la hoja, las condiciones y las columnas a regresar' do
      spec = described_class.parse_all('x {{hoja_buscar: Servicio Gruas | remolque=TP-64,TP-63; estatus=activo | Calendar_ID, peso_max_t}}').first

      expect(spec.sheet).to eq('Servicio Gruas')
      expect(spec.filters.map(&:to_h)).to eq([{ column: 'remolque', op: '=', wanted: %w[TP-64 TP-63] },
                                              { column: 'estatus', op: '=', wanted: ['activo'] }])
      expect(spec.returns).to eq(%w[Calendar_ID peso_max_t])
    end

    it 'sin una de las tres partes no es una directiva válida' do
      expect(described_class.parse_all('{{hoja_buscar: Servicio Gruas | remolque=?}}')).to be_empty
      expect(described_class.parse('Servicio Gruas | remolque | Calendar_ID')).to be_nil
    end
  end

  it 'busca exacto: «tp 63» es la TP-63 y la TP-6 no se confunde con la TP-64' do
    result = lookup('Servicio Gruas | remolque=tp 63, TP-6 | peso_max_t')

    expect(result.found).to eq(%w[40.8 30])
  end

  it 'varias condiciones se cumplen todas' do
    expect(lookup('Servicio Gruas | remolque=TP-64,TP-6; estatus=activo | peso_max_t').found).to eq(['60'])
  end

  it 'sin coincidencias no inventa nada' do
    expect(lookup('Servicio Gruas | remolque=TP-500 | Calendar_ID').status).to eq(:no_match)
  end

  it 'avisa si la hoja o una columna no existen' do
    expect(lookup('Otra hoja | remolque=TP-64 | Calendar_ID').status).to eq(:sheet_missing)
    result = lookup('Servicio Gruas | unidad=TP-64 | Calendar_ID')
    expect([result.status, result.missing]).to eq([:column_missing, ['unidad']])
  end

  describe 'con «?», el valor sale de la conversación' do
    it 'los que nombró el cliente ganan sobre los que ofreció el agente' do
      say('Te recomiendo la TP-64 o la TP-63', :outgoing)
      say('La tp 63 está bien')

      result = lookup('Servicio Gruas | remolque=? | Calendar_ID', conv: conversation)
      expect([result.asked, result.found]).to eq([['TP-63'], ['calTP-63']])
    end

    it 'dice de qué mensaje salió el valor' do
      say('Te recomiendo la TP-64', :outgoing)
      nombro = say('Mejor la TP-63')
      say('¿Y en la tarde?')

      expect(lookup('Servicio Gruas | remolque=? | Calendar_ID', conv: conversation).source_message_id).to eq(nombro.id)
    end

    it 'si el cliente no nombró ninguno, todos los que ofreció el agente' do
      say('Necesito mover una excavadora')
      say('Te recomiendo la TP-64 o la TP-63', :outgoing)

      expect(lookup('Servicio Gruas | remolque=? | peso_max_t', conv: conversation).found).to eq(%w[60 40.8])
    end

    it 'si nadie nombró ninguno no busca en todas las filas: hay que preguntar' do
      say('Quiero agendar un servicio')

      result = lookup('Servicio Gruas | remolque=? | Calendar_ID', conv: conversation)
      expect([result.status, result.asked]).to eq([:needs_value, 'remolque'])
    end
  end

  describe 'con «?» y la VARIABLE del mismo nombre que la columna' do
    def lookup_con(inner, variables)
      described_class.new(account, described_class.parse(inner), conversation: conversation, variables: variables).call
    end

    it 'usa la variable aunque nadie la haya nombrado en los últimos mensajes' do
      say('¿Y en la tarde?')

      expect(lookup_con('Servicio Gruas | remolque=? | peso_max_t', { 'REMOLQUE' => 'la TP-63' }).found).to eq(['40.8'])
    end

    it 'si el cliente nombra otro, van los dos: el prompt decide' do
      say('¿y la TP-64?')

      expect(lookup_con('Servicio Gruas | remolque=? | peso_max_t', { 'REMOLQUE' => 'TP-63' }).found).to eq(%w[60 40.8])
    end

    it 'de los valores que nombra la variable se queda el más largo' do
      GoogleSheetRow.create!(account: account, knowledge_source: source, row_index: 3,
                             data: { 'remolque' => 'TP-63 Plus', 'peso_max_t' => '45', 'estatus' => 'activo', 'Calendar_ID' => 'x' })

      expect(lookup_con('Servicio Gruas | remolque=? | peso_max_t', { 'REMOLQUE' => 'Remolque TP-63 Plus' }).found).to eq(['45'])
    end

    it 'con la variable VACÍO y nadie lo nombra, hay que preguntar' do
      say('Quiero agendar un servicio')

      expect(lookup_con('Servicio Gruas | remolque=? | Calendar_ID', { 'REMOLQUE' => 'VACÍO' }).status).to eq(:needs_value)
    end

    it 'con la variable VACÍO no toma lo que nombró el agente ni el cliente en turnos anteriores' do
      say('Para el patio de la TP-64')
      say('Le recomendamos la TP-64 o la TP-63', :outgoing)
      say('¿Y cuánto aguanta?')

      expect(lookup_con('Servicio Gruas | remolque=? | peso_max_t', { 'REMOLQUE' => 'VACÍO' }).status).to eq(:needs_value)
    end

    it 'con la variable VACÍO toma lo que el cliente nombró en su turno actual' do
      say('¿Cuál remolque quiere?', :outgoing)
      say('La TP-63')
      say('¿Cuánto aguanta?')

      expect(lookup_con('Servicio Gruas | remolque=? | peso_max_t', { 'REMOLQUE' => 'VACÍO' }).found).to eq(['40.8'])
    end

    it 'sin la variable declarada, lo de siempre (el agente sirve de respaldo)' do
      say('Le recomendamos la TP-64', :outgoing)
      say('¿Cuánto aguanta?')

      expect(lookup_con('Servicio Gruas | remolque=? | peso_max_t', { 'OTRA' => 'VACÍO' }).found).to eq(['60'])
    end
  end

  describe 'con «?» y el nombre corto de un valor largo' do
    let!(:carreras) do
      create(:knowledge_source, account: account, source_type: 'google_sheet', name: 'Carreras', config: { 'sheet_mode' => 'faq' })
    end

    before do
      ['Administración', 'Desarrollo y Administración Inmobiliaria en Bienes Raíces', 'Relaciones Internacionales',
       'Trabajo Social', 'Administración de Instituciones de Salud'].each_with_index do |carrera, i|
        GoogleSheetRow.create!(account: account, knowledge_source: carreras, row_index: i,
                               data: { 'carrera' => carrera, 'liga' => "liga-#{i}" })
      end
    end

    def liga(variables = { 'CARRERA' => 'Licenciatura en Relaciones Internacionales' })
      described_class.new(account, described_class.parse('Carreras | carrera=? | liga'), conversation: conversation,
                                                                                         variables: variables).call.found
    end

    it '«bienes raíces» nombra la carrera completa, aunque CARRERA sea otra' do
      say('y para bienes raíces es lo mismo')

      expect(liga).to eq(%w[liga-1 liga-2])
    end

    it 'el nombre completo trae solo esa, no «Administración» que va dentro' do
      say('Desarrollo y Administración Inmobiliaria en Bienes Raíces')

      expect(liga('CARRERA' => 'VACÍO')).to eq(['liga-1'])
    end

    it 'una sola palabra o un tramo de dos carreras no bastan' do
      say('¿y el servicio social cuánto cuesta?')
      expect(liga('CARRERA' => 'VACÍO')).to be_nil

      say('información de administración')
      expect(liga('CARRERA' => 'VACÍO')).to eq(['liga-0'])
    end

    it '«instituciones de salud» es la maestría' do
      say('quiero la de instituciones de salud')

      expect(liga('CARRERA' => 'VACÍO')).to eq(['liga-4'])
    end
  end

  it 'nunca le llega al modelo que redacta: es configuración de la agenda' do
    texto = 'Agenda en su calendario. {{hoja_buscar: Servicio Gruas | remolque=? | Calendar_ID}} Consulta {{hoja:Servicio Gruas}}.'

    expect(KnowledgeBase::Directives.strip_tokens(texto)).to eq('Agenda en su calendario.  Consulta la información consultada.')
  end

  describe 'comparaciones (pieza 1)' do
    it 'con número fijo: >=, <, !=' do
      expect(lookup('Servicio Gruas | peso_max_t>=40 | remolque').found).to eq(%w[TP-64 TP-63])
      expect(lookup('Servicio Gruas | peso_max_t<40 | remolque').found).to eq(['TP-6'])
      expect(lookup('Servicio Gruas | estatus!=baja | remolque').found).to eq(%w[TP-64 TP-63])
    end

    it 'con «?»: el mayor número que dijo el cliente, en la unidad de la columna' do
      say('Necesito una grúa de 50 toneladas para una carga de 26 t, el lunes 28')

      result = lookup('Servicio Gruas | peso_max_t>=? | remolque', conv: conversation)
      expect([result.found, result.criteria]).to eq([['TP-64'], ['peso_max_t >= 50.0']])
    end

    it 'si el cliente no dio un número con unidad, hay que preguntar' do
      say('Necesito una grúa para el lunes 28')

      result = lookup('Servicio Gruas | peso_max_t>=? | remolque', conv: conversation)
      expect([result.status, result.asked]).to eq([:needs_value, 'peso_max_t'])
    end

    it 'sin acentos: «grua» encuentra «Grúa»' do
      GoogleSheetRow.create!(account: account, knowledge_source: source, row_index: 9,
                             data: { 'remolque' => 'Grúa 80', 'peso_max_t' => '80', 'estatus' => 'activo', 'Calendar_ID' => 'c80' })
      say('¿tienen la grua 80?')

      expect(lookup('Servicio Gruas | remolque=? | Calendar_ID', conv: conversation).found).to eq(['c80'])
    end

    it 'una comparación sin número no es válida' do
      expect(described_class.parse('Servicio Gruas | peso_max_t>=grande | remolque')).to be_nil
    end
  end

  it '.agenda_specs: solo las que van después de la flecha' do
    prompt = "@ruta(a: x): {{hoja_buscar: Unidades | economico=? | operador}}\n" \
             '@ruta(b: y): - -> {{hoja_buscar: Servicio Gruas | remolque=? | Calendar_ID}} -> @agendar_calendar'

    expect(described_class.agenda_specs(prompt).map(&:sheet)).to eq(['Servicio Gruas'])
  end

  describe '.calendar_id' do
    it 'saca el id del calendario del link para verlo' do
      expect(described_class.calendar_id(embed)).to eq('cal64@group.calendar.google.com')
      expect(described_class.calendar_id(' abc@group.calendar.google.com ')).to eq('abc@group.calendar.google.com')
    end
  end
end
