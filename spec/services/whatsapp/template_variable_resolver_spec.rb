# frozen_string_literal: true

require 'rails_helper'

# feat/plantillas_variables_resolver F9.2 — los casos son los mismos que pasa la réplica del
# navegador (dashboard/helper/specs/whatsappTemplateVariables.spec.js).
describe Whatsapp::TemplateVariableResolver do
  fixture = JSON.parse(Rails.root.join('spec/fixtures/whatsapp_template_variables.json').read)

  def contact_from(datos)
    Contact.new(datos) if datos
  end

  def agent_from(datos)
    User.new(name: datos['name'], display_name: datos['available_name']) if datos
  end

  def conversation_from(datos)
    return unless datos

    Conversation.new(display_id: datos['number'], custom_attributes: datos['custom_attributes'] || {},
                     assignee: agent_from(datos['assignee']))
  end

  def resolver_for(caso, now)
    described_class.new(contact: contact_from(caso['contact']), conversation: conversation_from(caso['conversation']),
                        inbox: caso['inbox'] && Inbox.new(caso['inbox']), agent: agent_from(caso['agent']), now: now)
  end

  it 'los reservados son los mismos que los del navegador' do
    expect(described_class::RESERVED.keys).to eq(fixture['reserved'])
  end

  fixture['cases'].each do |caso|
    it caso['title'] do
      resolver = resolver_for(caso, Time.iso8601(fixture['now']))

      expect(caso['expected'].keys.index_with { |clave| resolver.value(clave) }).to eq(caso['expected'])
    end
  end

  it 'separa lo que tiene dato de lo que falta, cada variable una vez' do
    resolver = described_class.new(contact: Contact.new(name: 'Juan', custom_attributes: { edad: 34 }))

    expect(resolver.resolve(%w[nombre edad nombre plan 1])).to eq(values: { 'nombre' => 'Juan', 'edad' => '34' },
                                                                  missing: %w[plan 1])
  end

  it 'la bandeja sale de la conversación si no se da' do
    conversation = Conversation.new(display_id: 1, inbox: Inbox.new(name: 'Ventas', timezone: 'America/Mexico_City'))
    resolver = described_class.new(conversation: conversation, now: Time.iso8601(fixture['now']))

    expect(resolver.value('bandeja')).to eq('Ventas')
    expect(resolver.value('fecha_hoy')).to eq('31/10/2026')
  end
end
