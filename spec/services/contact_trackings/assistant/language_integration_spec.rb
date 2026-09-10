# frozen_string_literal: true

# proyecto@asistente_agentes_ia — el Asistente en dos idiomas
require 'rails_helper'

# ==============================================================================
# La regla que sostiene todo esto: se traduce lo que LEEN PERSONAS, nunca lo que
# PARSEA EL MOTOR.
#
# Un @route(...) o un @create_ticket(...) no los reconoce ninguna regex, así que el
# agente quedaría inerte — en silencio, que es exactamente la falla que este módulo
# vino a eliminar. Por eso el archivo no comprueba solo que haya traducción: también
# comprueba que la gramática siga intacta en las dos.
# ==============================================================================
# Se cuelga de Language porque es la pieza que decide el idioma; lo que se prueba acá
# es el EFECTO de esa decisión sobre el comprobador y sobre el prompt del asistente.
RSpec.describe ContactTrackings::Assistant::Language do
  let(:account) { create(:account) }

  def validar(texto, locale)
    I18n.with_locale(locale) do
      ContactTrackings::Assistant::ValidatorService.new(texto, account: account).call
    end
  end

  describe 'los mensajes del comprobador' do
    let(:roto) { '@ruta(soporte #soporte: no puedo entrar) @buscar_articulo' }

    it 'salen en español para una cuenta en español' do
      mensaje = validar(roto, :es)[:blocking].first[:message]

      expect(mensaje).to include('falta el ":"')
      expect(mensaje).to include('Línea 1')
    end

    it 'salen en inglés para una cuenta en inglés' do
      mensaje = validar(roto, :en)[:blocking].first[:message]

      expect(mensaje).to include('the ":"')
      expect(mensaje).to include('Line 1')
    end

    it 'diagnostican lo MISMO en los dos idiomas' do
      expect(validar(roto, :es)[:blocking].pluck(:code))
        .to eq(validar(roto, :en)[:blocking].pluck(:code))
    end

    # El fallback de Rails solo está en production/staging: sin resolución propia,
    # una cuenta en portugués vería "translation missing" en el panel.
    it 'no deja "translation missing" con un idioma que el Asistente no soporta' do
      mensaje = validar(roto, :pt)[:blocking].first[:message]

      expect(mensaje).not_to include('translation missing')
      expect(mensaje).to include('Línea 1')
    end
  end

  # ============================================================================
  # LO QUE NO SE TRADUCE
  # ============================================================================
  describe 'la gramática del motor' do
    # Cada literal que el parser busca con una regex fija. Si alguno se tradujera,
    # el Entrenamiento parsearía distinto y el agente no ejecutaría nada.
    literales = ['@ruta(', '@ruta_por_defecto', '@crear_ticket(', 'tipo=', '->'].freeze

    %i[es en].each do |locale|
      it "sigue en su forma original en #{locale}" do
        instrucciones = I18n.with_locale(locale) do
          ContactTrackings::Assistant::Instructions.call(one_shot: false, max_turns: 5)
        end

        literales.each { |literal| expect(instrucciones).to include(literal) }
      end

      it "le dice al modelo que NO traduzca esos literales, en #{locale}" do
        instrucciones = I18n.with_locale(locale) do
          ContactTrackings::Assistant::Instructions.call(one_shot: false, max_turns: 5)
        end

        expect(instrucciones).to include(described_class.name_for(locale))
      end
    end

    # El contrato dicta ejemplos que el parser real tiene que poder leer. Que estén
    # en español no es un descuido: son gramática, no prosa.
    it 'el ejemplo del contrato lo sigue parseando el motor, sea cual sea el idioma' do
      %i[es en].each do |locale|
        I18n.with_locale(locale) do
          map = ContactTrackings::RouteMap.parse(ContactTrackings::Assistant::Contract::ROUTE_EXAMPLE)
          expect(map.routes.size).to eq(1)
        end
      end
    end
  end

  # ============================================================================
  # LA CORRECCIÓN DE 10/09/2026 — ver config/locales/tracking_assistant.*.yml
  # ============================================================================
  # El mensaje decía que una rama sin flecha "deja de abrir casos". Verificado contra
  # Cases::TicketCreatorService: es al revés. El job la manda a
  # try_create_ticket(directive: nil), que cae al Entrenamiento ENTERO y encuentra
  # ahí el @crear_ticket de OTRA rama.
  describe 'régimen de escalamiento mixto' do
    let(:mixto) do
      "@ruta(soporte #soporte: fallas): @buscar_articulo -> @crear_ticket(tipo=Soporte)\n" \
        '@ruta(otros #otros: lo demas): @buscar_predefinidas'
    end

    it 'ya no afirma que esas ramas dejan de abrir casos' do
      mensaje = validar(mixto, :es)[:degrading].find { |f| f[:code] == :mixed_escalation_regime }[:message]

      expect(mensaje).to include('NO las deja sin caso')
      expect(mensaje).to include('ANTES de consultar')
    end

    it 'y lo dice igual en inglés' do
      mensaje = validar(mixto, :en)[:degrading].find { |f| f[:code] == :mixed_escalation_regime }[:message]

      expect(mensaje).to include('does NOT leave them')
      expect(mensaje).to include('BEFORE consulting')
    end

    # El motor de verdad, no el mensaje: si esto cambiara, el aviso volvería a mentir.
    it 'coincide con lo que hace Cases::TicketCreatorService' do
      conversation = create(:conversation, account: account)
      message = create(:message, account: account, conversation: conversation, message_type: :incoming)
      creator = Cases::TicketCreatorService.new(message, tracking: ContactTracking.new(complementary_prompt: mixto),
                                                         directive: nil)

      expect(creator.send(:directive_present?)).to be(true)
      expect(creator.send(:directive_overrides)).to include('tipo' => 'Soporte')
    end
  end
end
