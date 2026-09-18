# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::InventoryService do
  let(:account) { create(:account) }

  def source(source_type, name)
    KnowledgeSource.create!(account: account, source_type: source_type, name: name, status: 'active')
  end

  describe 'fuentes' do
    it 'traduce cada fuente activa a la directiva que hay que escribir en la @ruta' do
      source('discourse', 'Foro Kontrolya')
      source('google_sheet', 'Precios 2026')

      directivas = described_class.new(account).call[:sources].pluck(:directive)

      expect(directivas).to contain_exactly('@buscar_foro(Foro Kontrolya)', '{{hoja:Precios 2026}}')
    end

    it 'no ofrece las fuentes inactivas' do
      source('discourse', 'Foro Viejo').update!(status: 'inactive')

      expect(described_class.new(account).call[:sources]).to be_empty
    end

    it 'usa el nombre textual, sin normalizar, porque la directiva lo direcciona' do
      source('google_doc', 'Manual de Instalación v2')

      directiva = described_class.new(account).call[:sources].first[:directive]

      expect(directiva).to eq('{{doc:Manual de Instalación v2}}')
    end
  end

  # El asistente le dicta al modelo las directivas disponibles. Si emite una que el
  # motor no reconoce, el Entrenamiento sale con una fuente muerta: parsea, pero no
  # busca en ningún lado y nadie se entera. Este viaje de vuelta lo impide.
  describe 'las directivas emitidas las reconoce el parser real del motor' do
    it 'cada una resuelve al modo esperado en KnowledgeBase::Directives.detect' do
      KnowledgeSource::SOURCE_TYPES.each_with_index do |source_type, i|
        source(source_type, "Fuente #{i}")
      end

      described_class.new(account).call[:sources].each do |entry|
        detected = KnowledgeBase::Directives.detect(entry[:directive])

        expect(detected).not_to be_nil, "#{entry[:directive]} no la reconoce el motor"
        expect(detected[:mode]).to eq(entry[:mode]), "#{entry[:directive]} resolvió a #{detected[:mode]}"
      end
    end
  end

  # Guardarraíl que motivó este servicio: si mañana se agrega un source_type al motor
  # y nadie le da su directiva acá, el asistente dejaría de ofrecerlo en silencio —
  # el mismo modo de falla que este módulo existe para matar.
  describe 'sincronía con KnowledgeSource::SOURCE_TYPES' do
    it 'cada tipo del motor está clasificado: o tiene directiva, o es no direccionable' do
      clasificados = described_class::SOURCE_DIRECTIVES.keys + described_class::NOT_ADDRESSABLE

      expect(clasificados).to match_array(KnowledgeSource::SOURCE_TYPES)
    end
  end

  describe 'fuentes que el asistente no sabe ofrecer' do
    # En la base de dev hay filas 'ai_agent' que ningún código crea y que no están en
    # SOURCE_TYPES. Se saltan la validación por venir de antes, así que hay que
    # tolerarlas — pero visibles, no tragadas.
    it 'las expone en unsupported en vez de omitirlas' do
      source('discourse', 'Foro Kontrolya')
      KnowledgeSource.new(account: account, source_type: 'ai_agent', name: 'Agentes IA', status: 'active')
                     .save!(validate: false)

      resultado = described_class.new(account).call

      expect(resultado[:sources].size).to eq(1)
      expect(resultado[:unsupported]).to contain_exactly(
        { source_type: 'ai_agent', name: 'Agentes IA' }
      )
    end
  end

  describe 'grupos de respuestas predefinidas' do
    # El grupo de @buscar_predefinidas(GRUPO) es el prefijo del short_code: no hay
    # columna ni pantalla donde leerlo.
    it 'deduce los prefijos y los ordena por cuántas respuestas tiene cada uno' do
      create(:canned_response, account: account, short_code: 'GESTION - alta de usuario')
      create(:canned_response, account: account, short_code: 'GESTION - datos fiscales')
      create(:canned_response, account: account, short_code: 'HORARIO de atencion')

      grupos = described_class.new(account).call[:canned_groups]

      expect(grupos).to eq([{ prefix: 'GESTION', count: 2 }, { prefix: 'HORARIO', count: 1 }])
    end

    it 'ignora un short_code de una sola palabra, que no declara ningún grupo' do
      create(:canned_response, account: account, short_code: 'saludo')

      expect(described_class.new(account).call[:canned_groups]).to be_empty
    end
  end

  describe 'frases de clientes' do
    let(:inbox) { create(:inbox, account: account) }

    def conversacion_con(*contenidos)
      conversation = create(:conversation, account: account, inbox: inbox)
      contenidos.each do |content|
        create(:message, account: account, inbox: inbox, conversation: conversation,
                         message_type: :incoming, content: content)
      end
      conversation
    end

    it 'devuelve los mensajes textuales, con sus typos' do
      conversacion_con('voy actualiza a firebird 5 kontrolya ya es comparble')

      expect(described_class.new(account).call[:customer_phrases])
        .to eq(['voy actualiza a firebird 5 kontrolya ya es comparble'])
    end

    # "El primer mensaje" a secas no sirve: la mayoría de las conversaciones abre
    # con un saludo y el planteo llega después. Medido contra la cuenta de pruebas,
    # el literal primero dejaba 1 frase de 8.
    it 'saltea el saludo y toma el primer mensaje que dice algo' do
      conversacion_con('hola', 'no puedo entrar al sistema desde ayer')

      expect(described_class.new(account).call[:customer_phrases])
        .to eq(['no puedo entrar al sistema desde ayer'])
    end

    # A lo ancho primero: una de cada conversación antes que la segunda de ninguna,
    # para que una conversación charlatana no se lleve el cupo.
    it 'pone primero una frase de cada conversación, y recién después las demás' do
      conversacion_con('no puedo entrar al sistema desde ayer',
                       'tambien me falla la impresion de recibos')
      conversacion_con('cuanto sale la licencia anual')

      frases = described_class.new(account).call[:customer_phrases]

      expect(frases.first(2)).to contain_exactly('no puedo entrar al sistema desde ayer',
                                                 'cuanto sale la licencia anual')
      expect(frases.last).to eq('tambien me falla la impresion de recibos')
    end

    it 'no mira más allá del planteo: pasado ese punto es diálogo, no tema' do
      conversacion_con('hola', 'buenas tardes como estan', 'gracias por responder tan rapido',
                       'les escribo desde la sucursal norte', 'ahora si les cuento el problema',
                       'el sistema no abre desde la actualizacion')

      expect(described_class.new(account).call[:customer_phrases])
        .not_to include('el sistema no abre desde la actualizacion')
    end

    # Las frases salen del servidor hacia OpenAI: lo que se muestra en pantalla es
    # lo enmascarado, que es exactamente lo que se envía.
    it 'las devuelve enmascaradas' do
      conversacion_con('mi correo es juan.perez@empresa.com y no me llega nada')

      frase = described_class.new(account).call[:customer_phrases].first

      expect(frase).to include('[correo]')
      expect(frase).not_to include('juan.perez@empresa.com')
    end

    it 'no tapa el vocabulario del negocio al enmascarar' do
      conversacion_con('no puedo timbrar la factura A-1234 de CONTPAQi 2026')

      expect(described_class.new(account).call[:customer_phrases])
        .to eq(['no puedo timbrar la factura A-1234 de CONTPAQi 2026'])
    end

    it 'descarta los saludos, que no describen ninguna situación' do
      conversacion_con('hola')

      expect(described_class.new(account).call[:customer_phrases]).to be_empty
    end

    it 'no incluye lo que respondió el agente' do
      conversation = create(:conversation, account: account, inbox: inbox)
      create(:message, account: account, inbox: inbox, conversation: conversation,
                       message_type: :outgoing, content: 'Con gusto le ayudo con la actualización')

      expect(described_class.new(account).call[:customer_phrases]).to be_empty
    end

    it 'no repite la misma frase dos veces' do
      2.times { conversacion_con('como timbro la nomina en CONTPAQi Nominas') }

      expect(described_class.new(account).call[:customer_phrases].size).to eq(1)
    end
  end

  describe 'cuenta vacía' do
    # Cold start: sin fuentes ni tipos de caso no hay de dónde proponer, y el
    # asistente tiene que ofrecer arquetipos en vez de entrevistar sobre la nada.
    it 'se marca como empty cuando no hay fuentes ni tipos de caso' do
      expect(described_class.new(account).call[:empty]).to be(true)
    end

    it 'deja de estar empty en cuanto hay una fuente' do
      source('discourse', 'Foro Kontrolya')

      expect(described_class.new(account).call[:empty]).to be(false)
    end
  end
end
