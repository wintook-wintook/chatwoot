# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia — no simular
RSpec.describe ContactTrackings::Assistant::PromiseChecks do
  around { |example| I18n.with_locale(:es) { example.run } }

  def hallazgos(texto)
    findings = ContactTrackings::Assistant::Findings.new
    described_class.check(texto, map: ContactTrackings::RouteMap.parse(texto), findings: findings)
    findings.of(:degrading)
  end

  describe 'P1 · dice que hace una acción que no tiene' do
    # El borrador #2923 (24/09/2026).
    it 'agenda en el calendario sin @agendar_calendar: avisa, colgado de su rama' do
      texto = "@ruta(agendar_cita #agendar: quiero cita): - -> @crear_ticket\n\n[ALCANCE POR RAMA]\n" \
              "Agendar cita: Agenda la cita en el calendario conectado.\n"

      hallazgo = hallazgos(texto).first
      expect(hallazgo).to include(code: :promised_action_missing, line: 4, route: 'agendar_cita')
      expect(hallazgo[:message]).to include('@agendar_calendar')
    end

    it 'con @agendar_calendar en alguna rama no avisa' do
      texto = "@ruta(agendar_cita #agendar: quiero cita): - -> @agendar_calendar\n\n[ALCANCE POR RAMA]\n" \
              "Agendar cita: Agenda la cita en el calendario.\n"

      expect(hallazgos(texto)).to be_empty
    end

    it 'abre un caso sin @crear_ticket: avisa; encuentra la rama sin los conectores' do
      texto = "@ruta(clase_prueba #prueba: quiero probar): -\n\n[ALCANCE POR RAMA]\n" \
              "Clase de prueba: Abre un caso para que la recepción lo contacte.\n"

      expect(hallazgos(texto).first).to include(code: :promised_action_missing, route: 'clase_prueba')
    end
  end

  describe 'P2 · promesa de seguimiento' do
    it 'avisa cuando la prosa le pide prometerlo' do
      expect(hallazgos("[ESTILO]\nCuando pidan cita, di que te confirmo en un momento.").pluck(:code))
        .to eq([:follow_up_promise])
    end

    it 'no avisa cuando la línea lo prohíbe' do
      expect(hallazgos("[PROHIBIDO]\nNunca digas «te confirmo en un momento» ni «lo estoy revisando».")).to be_empty
    end
  end
end
