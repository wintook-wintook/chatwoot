# frozen_string_literal: true

# proyecto@ai_agent_assistant - F2
require 'rails_helper'

RSpec.describe AiAgentAssistant::Linter do
  let(:account) { create(:account) }
  let(:inbox)   { create(:inbox, account: account) }

  def build_template(attrs = {})
    create(:tracking_template, {
      account: account,
      inbox: inbox,
      name: 'Agente de prueba',
      objective: 'Confirmar el pago de la factura vencida u obtener una fecha compromiso de pago.',
      complementary_prompt: 'Eres del área de cobranza. Trato de usted.'
    }.merge(attrs))
  end

  def rules_for(template)
    described_class.new(template, account: account).call.pluck(:rule)
  end

  def finding_for(template, rule)
    described_class.new(template, account: account).call.find { |f| f[:rule] == rule }
  end

  describe 'un agente bien formado' do
    it 'no dispara nada' do
      expect(rules_for(build_template)).to be_empty
    end
  end

  describe 'conflicto de directivas' do
    it 'bloquea dos fuentes en el mismo prompt e indica cuál gana' do
      t = build_template(complementary_prompt: "@discourse\n@buscar_predefinidas")
      f = finding_for(t, :two_sources)

      expect(f[:level]).to eq(:error)
      expect(f[:params][:winner]).to eq('@buscar_predefinidas')
      expect(f[:params][:ignored]).to eq(['@discourse'])
    end

    it 'bloquea una búsqueda con prompt largo: el prompt se descarta entero' do
      t = build_template(complementary_prompt: "@buscar_articulo\n#{'x' * 400}")
      f = finding_for(t, :search_swallows_prompt)

      expect(f[:level]).to eq(:error)
      expect(f[:params][:discarded_chars]).to be > 200
    end

    it 'NO se queja de {{hoja:}} con prompt largo: las fuentes Google lo conservan' do
      t = build_template(complementary_prompt: "{{hoja:Precios}}\n#{'x' * 400}")
      expect(rules_for(t)).not_to include(:search_swallows_prompt)
    end

    it 'bloquea búsqueda junto a adjuntos: el motor deja de enviarlos' do
      t = build_template(complementary_prompt: '@discourse envía el {{catalogo}}')
      expect(finding_for(t, :search_kills_attachments)[:level]).to eq(:error)
    end

    it 'avisa cuando hay dos nombres de hoja distintos' do
      t = build_template(complementary_prompt: '{{hoja:SUSSA-UNIDADESSOP}} y {{hoja:SUSSA-UNIDADES}}')
      f = finding_for(t, :inconsistent_source_names)

      expect(f[:level]).to eq(:warning)
      expect(f[:params][:used]).to eq('SUSSA-UNIDADESSOP')
    end
  end

  describe 'requisitos no satisfechos' do
    it 'bloquea {{hoja:}} sin la feature de Google' do
      account.disable_features!('google_calendar')
      t = build_template(complementary_prompt: '{{hoja:Precios}}')

      expect(finding_for(t, :google_feature_missing)[:level]).to eq(:error)
    end

    it 'bloquea un tipo de ticket que no existe, y ofrece los que sí' do
      account.case_types.create!(name: 'RENTA UNIDADES')
      t = build_template(complementary_prompt: '@crear_ticket(tipo=UNIDADES)')
      f = finding_for(t, :case_type_missing)

      expect(f[:level]).to eq(:error)
      expect(f[:params][:requested]).to eq('UNIDADES')
      expect(f[:params][:available]).to include('RENTA UNIDADES')
    end

    it 'acepta el tipo de ticket cuando sí existe' do
      account.case_types.create!(name: 'RENTA UNIDADES')
      t = build_template(complementary_prompt: '@crear_ticket(prioridad=alta, tipo=RENTA UNIDADES)')

      expect(rules_for(t)).not_to include(:case_type_missing)
    end

    it 'bloquea {{nombre}} sin un archivo con ese nombre' do
      t = build_template(complementary_prompt: 'Hola, {{catalogo}}')
      f = finding_for(t, :attachment_missing)

      expect(f[:level]).to eq(:error)
      expect(f[:params][:missing]).to eq(['catalogo'])
    end

    it 'bloquea @agendar_calendar sin calendarios' do
      t = build_template(complementary_prompt: '@agendar_calendar', calendar_integration_ids: [])
      expect(finding_for(t, :calendar_missing)[:level]).to eq(:error)
    end

    # El modelo ya valida el formato de keyword_actions, así que por la UI no entra una
    # acción inválida. Esto cubre el borrador SIN GUARDAR que recibe el endpoint de lint,
    # y las filas heredadas.
    it 'bloquea una acción de palabra clave inválida' do
      t = build(:tracking_template, account: account, inbox: inbox, objective: 'x' * 80,
                                    keyword_actions: [{ 'keyword' => 'ya pagué', 'action' => 'cerrar',
                                                        'direction' => 'incoming' }])
      expect(finding_for(t, :invalid_keyword_action)[:level]).to eq(:error)
    end
  end

  describe 'ventana de WhatsApp' do
    let(:inbox) do
      create(:inbox, account: account,
                     channel: create(:channel_whatsapp, account: account,
                                                        validate_provider_config: false, sync_templates: false))
    end

    it 'bloquea WhatsApp sin plantillas con reintento de días: todo reintento falla' do
      t = build_template(whatsapp_templates: [], retry_interval_value: 3, retry_interval_unit: 'days')
      f = finding_for(t, :whatsapp_without_templates)

      expect(f[:level]).to eq(:error)
      expect(f[:params][:hours]).to eq(72)
    end

    it 'no se queja si hay plantilla' do
      t = build_template(whatsapp_templates: [{ 'name' => 'cobranza' }], retry_interval_value: 3, retry_interval_unit: 'days')
      expect(rules_for(t)).not_to include(:whatsapp_without_templates)
    end

    it 'no se queja si el reintento cae dentro de la ventana' do
      t = build_template(whatsapp_templates: [], retry_interval_value: 6, retry_interval_unit: 'hours')
      expect(rules_for(t)).not_to include(:whatsapp_without_templates)
    end
  end

  describe 'presupuesto del motor' do
    it 'avisa de un prompt fuera de presupuesto' do
      t = build_template(complementary_prompt: 'x' * 2_000)
      f = finding_for(t, :prompt_too_long)

      expect(f[:level]).to eq(:warning)
      expect(f[:params][:max_tokens]).to eq(150)
    end

    it 'avisa del ai_context truncado e indica cuánto se pierde' do
      t = build_template(ai_context: 'x' * 1_146)
      expect(finding_for(t, :ai_context_too_long)[:params][:lost]).to eq(346)
    end
  end

  describe 'coherencia con la configuración' do
    it 'avisa si el prompt nombra un canal distinto al del inbox' do
      t = build_template(complementary_prompt: 'Atiendes clientes por WhatsApp.')
      f = finding_for(t, :channel_mismatch)

      expect(f[:level]).to eq(:warning)
      expect(f[:params][:mentioned]).to eq('Whatsapp')
    end

    it 'avisa de slots por calendario sin calendarios' do
      t = build_template(slots_presentation: 'by_calendar', calendar_integration_ids: [])
      expect(finding_for(t, :slots_without_calendars)[:level]).to eq(:warning)
    end

    it 'avisa de un agente sin canal asignado' do
      t = build_template(inbox: nil)
      expect(finding_for(t, :inbox_missing)[:level]).to eq(:warning)
    end
  end

  describe 'estilo y operación' do
    it 'avisa de {{nombre}} usado como variable' do
      t = build_template(complementary_prompt: 'Hola, {{nombre}}, buen día.')
      expect(finding_for(t, :placeholder_looks_like_variable)[:params][:names]).to eq(['nombre'])
    end

    it 'avisa de marcadores visibles en las palabras clave' do
      t = build_template(keyword_actions: [{ 'keyword' => '#cumplido', 'action' => 'objective_met', 'direction' => 'both' }])
      expect(finding_for(t, :visible_keyword_marker)[:params][:markers]).to eq(['#cumplido'])
    end

    it 'avisa de un prompt idéntico al de otro agente' do
      texto = 'a' * 600
      build_template(name: 'Telegram - Postventa', complementary_prompt: texto)
      t = build_template(name: 'WhatsApp - Postventa', complementary_prompt: texto)

      expect(finding_for(t, :duplicate_prompt)[:params][:others]).to include('Telegram - Postventa')
    end

    it 'sugiere fijar la zona horaria con @agendar_calendar' do
      t = build_template(complementary_prompt: '@agendar_calendar', calendar_integration_ids: [1], timezone: nil)
      expect(finding_for(t, :timezone_missing)[:level]).to eq(:info)
    end

    it 'sugiere aprovechar el objective cuando es un título' do
      t = build_template(objective: 'SEGUIMIENTO VENCIMIENTO RENOVACIÓN LICENCIAS')
      expect(finding_for(t, :objective_is_a_title)[:level]).to eq(:info)
    end

    it 'detecta versiones hermanas guardadas como copias' do
      build_template(name: 'TICKETS UNIDADES V3')
      t = build_template(name: 'TICKETS UNIDADES V4')
      f = finding_for(t, :sibling_versions)

      expect(f[:params][:base]).to eq('TICKETS UNIDADES')
      expect(f[:params][:others]).to include('TICKETS UNIDADES V3')
    end
  end

  describe '#errors?' do
    it 'es true solo si hay algo de nivel error' do
      con_error = build_template(name: 'Con error', complementary_prompt: 'Hola, {{catalogo}}')
      solo_aviso = build_template(name: 'Solo aviso', objective: 'CORTO')

      expect(described_class.new(con_error, account: account).errors?).to be(true)
      expect(described_class.new(solo_aviso, account: account).errors?).to be(false)
    end
  end
end
