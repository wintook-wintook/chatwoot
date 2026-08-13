# frozen_string_literal: true

# proyecto@ai_agent_assistant - F3
require 'rails_helper'

RSpec.describe AiAgentAssistant::PromptBuilder do
  let(:account) { create(:account, name: 'Kontrolya') }
  let(:tracking) do
    instance_double(ContactTracking,
                    account: account,
                    objective: 'Confirmar el pago de la factura vencida.',
                    ai_context: 'Cliente con dos facturas abiertas.',
                    complementary_prompt: 'Eres del área de cobranza. Trato de usted.',
                    attempt_count: 0,
                    max_attempts: 3,
                    contact: nil)
  end

  # ==========================================================================
  # GOLDEN MASTER. Este texto es el que recibe el modelo hoy en producción.
  # Si alguien lo cambia sin querer, esto falla — y si lo cambia queriendo, el
  # diff del spec deja constancia de qué cambió para el cliente.
  # ==========================================================================
  describe '.scheduled_system' do
    it 'arma el prompt exacto de la ruta programada' do
      expect(described_class.scheduled_system(tracking, contact_name: 'Juan')).to eq(<<~SYSTEM.strip)
        Eres un asistente de seguimiento al cliente para Kontrolya.

        INFORMACIÓN DEL CLIENTE:
        - Nombre: Juan

        CONTEXTO INTERNO (no mencionar al cliente):
        - Objetivo: Confirmar el pago de la factura vencida.
        - Contexto: Cliente con dos facturas abiertas.
        - Este es el intento número 1 de 3

        INSTRUCCIONES ADICIONALES DEL AGENTE:
        Eres del área de cobranza. Trato de usted.

        REGLAS GENERALES:
        - Nunca menciones "intentos", "seguimiento automático" ni detalles técnicos
        - Mantén un tono cordial y profesional, como si lo escribiera un agente humano
        - Máximo 2 oraciones
        - En español
        - NO incluyas comillas al inicio ni al final del mensaje
      SYSTEM
    end

    it 'incluye el perfil del contacto cuando existe' do
      result = described_class.scheduled_system(tracking, contact_name: 'Juan', contact_profile: 'Prefiere WhatsApp')
      expect(result).to include("- Nombre: Juan\n\nPERFIL DEL CONTACTO:\nPrefiere WhatsApp")
    end
  end

  describe '.clean_complementary_prompt' do
    it 'vacía el prompt entero con cualquiera de las cuatro directivas de búsqueda' do
      %w[@buscar_predefinidas @buscar_articulo @buscar_artículo @discourse].each do |directiva|
        expect(described_class.clean_complementary_prompt("#{directiva}\nInstrucciones largas")).to eq('')
      end
      expect(described_class.clean_complementary_prompt("@buscar_foro(Manual)\nTexto")).to eq('')
    end

    it 'CONSERVA el prompt con las fuentes Google: es la diferencia que nadie ve' do
      %w[{{doc:Manual}} {{hoja:Precios}}].each do |fuente|
        expect(described_class.clean_complementary_prompt("#{fuente} y mis instrucciones"))
          .to include('mis instrucciones')
      end
    end

    it 'retira @agendar_calendar del texto: es una bandera, no una instrucción' do
      expect(described_class.clean_complementary_prompt('@agendar_calendar Ofrece horarios'))
        .to eq('Ofrece horarios')
    end
  end

  describe '.conversational_system' do
    it 'arma el prompt exacto de la ruta conversacional' do
      result = described_class.conversational_system(
        tracking, appointment_state: 'Sin cita agendada.', next_contact: '12/08/2026 a las 10:00'
      )

      expect(result).to include('Eres un asesor de ventas para Kontrolya.')
      expect(result).to include('OBJETIVO DE LA CONVERSACIÓN: Confirmar el pago de la factura vencida.')
      expect(result).to include('ESTADO DE LA CITA: Sin cita agendada.')
      expect(result).to include('PRÓXIMO CONTACTO PROGRAMADO: 12/08/2026 a las 10:00')
      expect(result).to include("INSTRUCCIONES ADICIONALES:\nEres del área de cobranza.")
    end

    it 'trunca la base de conocimiento a 800 caracteres' do
      allow(tracking).to receive(:ai_context).and_return('x' * 1_000)
      result = described_class.conversational_system(tracking, appointment_state: '-', next_contact: '-')

      expect(result).to include("BASE DE CONOCIMIENTO:\n#{'x' * 797}...")
    end

    it 'deja fuera las instrucciones cuando hay una directiva de búsqueda (T2)' do
      allow(tracking).to receive(:complementary_prompt).and_return("@discourse\nEres del área de cobranza.")
      result = described_class.conversational_system(tracking, appointment_state: '-', next_contact: '-')

      expect(result).not_to include('INSTRUCCIONES ADICIONALES')
      expect(result).not_to include('cobranza')
    end
  end

  describe '.conversational_user' do
    it 'incluye el tope de 4 líneas que el motor impone' do
      expect(described_class.conversational_user('Juan', 'Hola')).to include('Máximo 4 líneas.')
    end
  end
end
