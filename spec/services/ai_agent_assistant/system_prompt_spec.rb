# frozen_string_literal: true

# proyecto@ai_agent_assistant - F5
require 'rails_helper'

RSpec.describe AiAgentAssistant::SystemPrompt do
  let(:account) { create(:account) }
  let(:user)    { create(:user, account: account) }
  let(:inbox)   { create(:inbox, account: account) }

  def session_for(mode: 'interview', step: 'objective', draft: {}, template: nil)
    account.ai_agent_assistant_sessions.create!(user: user, mode: mode, step: step,
                                                draft: draft, tracking_template: template)
  end

  # Esta es la diferencia con escribir el prompt en ChatGPT: ChatGPT no sabe qué tiene
  # encendido esta cuenta, así que propone directivas que aquí no existen.
  describe 'se arma contra el estado real de la cuenta' do
    it 'separa lo disponible de lo que no lo está' do
      account.enable_features!('google_calendar')
      account.disable_features!('erp_connection')

      texto = described_class.for(session_for)
      disponibles, no_disponibles = texto.split('NO DISPONIBLES')

      expect(disponibles).to include('{{doc:')
      expect(no_disponibles).to include('{{consulta:')
    end

    it 'nunca filtra una expresión regular del motor' do
      expect(described_class.for(session_for)).not_to include('\\b', '(?i)')
    end

    it 'deja escrita la regla más cara del módulo' do
      # `squish` porque el heredoc parte las frases en varias líneas.
      texto = described_class.for(session_for).squish

      expect(texto).to include('DESCARTAN el prompt complementario entero')
      expect(texto).to include('{{doc:}} y {{hoja:}} NO lo descartan')
    end
  end

  describe 'límites del motor en lenguaje de negocio' do
    it 'habla de oraciones y líneas, no de nombres de jobs' do
      texto = described_class.for(session_for)

      expect(texto).to include('dos oraciones', 'cuatro líneas')
      expect(texto).not_to include('ContactTrackingJob', 'clean_cp')
    end

    it 'insiste en que el objetivo es el campo que siempre sobrevive' do
      expect(described_class.for(session_for)).to include('llega íntegro al modelo')
    end
  end

  describe 'guion de la entrevista' do
    it 'incluye el árbol de selección solo en el paso de conocimiento' do
      expect(described_class.for(session_for(step: 'knowledge'))).to include('ÁRBOL DE SELECCIÓN')
      expect(described_class.for(session_for(step: 'objective'))).not_to include('ÁRBOL DE SELECCIÓN')
    end

    it 'el árbol solo lista ramas que la cuenta puede usar' do
      account.disable_features!('erp_connection', 'google_calendar')

      texto = described_class.for(session_for(step: 'knowledge'))
      arbol = texto[/ÁRBOL DE SELECCIÓN.*/m]

      expect(arbol).not_to include('{{consulta:', '{{doc:')
    end

    it 'no aparece fuera del modo entrevista' do
      expect(described_class.for(session_for(mode: 'audit'))).not_to include('PASO ACTUAL')
    end
  end

  describe 'modos' do
    it 'auditar dice de dónde viene el prompt y qué hacer con él' do
      expect(described_class.for(session_for(mode: 'audit'))).to include('MODO AUDITAR', 'ChatGPT')
    end

    it 'ajuste pide el diff mínimo' do
      expect(described_class.for(session_for(mode: 'tweak'))).to include('diff mínimo')
    end
  end

  describe 'borrador en curso' do
    it 'dice que está vacío cuando no hay nada' do
      expect(described_class.for(session_for)).to include('BORRADOR ACTUAL: vacío')
    end

    it 'parte del Agente IA guardado cuando la sesión trabaja sobre uno' do
      template = create(:tracking_template, account: account, name: 'Cobranza',
                                            objective: 'Confirmar el pago de la factura vencida.')

      expect(described_class.for(session_for(template: template)))
        .to include('Confirmar el pago de la factura vencida.')
    end
  end

  describe 'indagación del propósito' do
    it 'el árbol de forma sale en su paso, no antes' do
      expect(described_class.for(session_for(step: 'purpose'))).to include('INDAGACIÓN DEL PROPÓSITO')
      expect(described_class.for(session_for(step: 'objective'))).not_to include('INDAGACIÓN DEL PROPÓSITO')
    end

    it 'cada forma llega con las secciones que le tocan' do
      texto = described_class.for(session_for(step: 'purpose'))

      expect(texto).to include('[SLOTS]', '[POSTCIERRE]', '[NODOS]')
    end

    it 'manda escribir las secciones, no solo nombrarlas' do
      texto = described_class.for(session_for(step: 'purpose')).squish

      expect(texto).to include('escribe el prompt con ESAS secciones')
    end
  end

  describe 'secciones que puede proponer' do
    it 'lleva el catálogo con el para qué de cada una' do
      texto = described_class.for(session_for)

      expect(texto).to include('SECCIONES QUE PUEDES PROPONER', '[POSTCIERRE]', '[SLOTS]')
    end

    # Media pieza del asistente es ofrecer arquitectura que el usuario no sabe que existe;
    # la otra media es no imponérsela a quien no la necesita.
    it 'insiste en ofrecer y no imponer' do
      texto = described_class.for(session_for).squish

      expect(texto).to include('Ofrece, no impongas')
      expect(texto).to include('Más secciones no es mejor agente')
    end

    it 'dice que el prompt vacío no tiene ninguna' do
      expect(described_class.for(session_for)).to include('no tiene ninguna sección todavía')
    end

    it 'no vuelve a proponer las que el prompt ya trae' do
      texto = described_class.for(session_for(draft: { 'complementary_prompt' => "[CIERRE]\nAdiós." }))

      expect(texto).to include('ya trae estas secciones, no las propongas otra vez: CIERRE')
    end

    it 'deja fuera la de configuración: esa no va dentro del prompt' do
      texto = described_class.for(session_for)[/SECCIONES QUE PUEDES PROPONER.*?Cómo se ofrecen/m]

      expect(texto).not_to include('[CONFIG]')
    end
  end

  describe 'contrato de salida' do
    it 'exige JSON y enumera los campos válidos' do
      texto = described_class.for(session_for)

      expect(texto).to include('"proposals"', '"next_step"')
      expect(texto).to include('complementary_prompt')
    end
  end
end
