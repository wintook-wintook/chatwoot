require 'rails_helper'

RSpec.describe ContactTrackings::WelcomeMessage do
  let(:prompt) do
    <<~PROMPT
      @ruta(comercial #cotizacion: precios): @buscar_predefinidas
      [ROL] Eres el asistente de Kontrolya.
      [MENSAJE DE BIENVENIDA]#{' '}
      Información del Agente de Soporte Kontrolya

      Ahora te invito a probarlo.
      [ESTILO] Dos párrafos como máximo.
    PROMPT
  end

  it 'toma el texto de la sección hasta el siguiente rótulo, aunque traiga texto en la misma línea' do
    expect(described_class.text(prompt)).to eq("Información del Agente de Soporte Kontrolya\n\nAhora te invito a probarlo.")
  end

  it 'quita la sección del prompt y conserva el resto' do
    expect(described_class.strip(prompt)).to eq(
      "@ruta(comercial #cotizacion: precios): @buscar_predefinidas\n[ROL] Eres el asistente de Kontrolya.\n" \
      '[ESTILO] Dos párrafos como máximo.'
    )
  end

  it 'no hace nada sin la sección' do
    expect(described_class.text("[ROL]\nHola")).to be_nil
    expect(described_class.strip("[ROL]\nHola")).to eq("[ROL]\nHola")
  end

  describe '.claim' do
    let(:conversation) { create(:conversation) }
    let(:tracking) { instance_double(ContactTracking, complementary_prompt: prompt, tracking_template_id: 297, id: 1) }

    it 'entrega la bienvenida con #bienvenida solo la primera vez' do
      expect(described_class.claim(tracking, conversation)).to eq(
        "Información del Agente de Soporte Kontrolya\n\nAhora te invito a probarlo.\n\n#bienvenida"
      )
      expect(conversation.reload.additional_attributes.dig('welcome_sent', '297')).to be_present
      expect(described_class.claim(tracking, conversation)).to be_nil
    end

    it 'no la manda a media plática si el bot ya había respondido' do
      create(:message, conversation: conversation, message_type: :outgoing,
                       content_attributes: { sentiment_auto_reply: true })

      expect(described_class.claim(tracking, conversation)).to be_nil
    end
  end
end
