require 'rails_helper'

RSpec.describe ContactTrackings::ConversationVariables do
  let(:prompt) do
    <<~PROMPT
      [ROL]
      Eres asesora.
      [VARIABLES]
      CARRERA=VACÍO|valor
      SIGUIENTE_OFERTA=SIN_INSCRIPCION|PRIMERA_BECA|SEGUNDA_BECA|ULTIMA_BECA|AGOTADA
      LIGA_ENTREGADA=NO|SÍ
      Inicial: CARRERA=VACÍO; SIGUIENTE_OFERTA=SIN_INSCRIPCION; LIGA_ENTREGADA=NO.
      [12. INSCRIPCIÓN]
      Marca LIGA_ENTREGADA=SÍ.
    PROMPT
  end
  let(:definition) { described_class.parse(prompt) }

  it 'lee las variables de la sección [VARIABLES] y sus valores iniciales' do
    expect(definition.names).to eq(%w[CARRERA SIGUIENTE_OFERTA LIGA_ENTREGADA])
    expect(definition.initial).to eq('CARRERA' => 'VACÍO', 'SIGUIENTE_OFERTA' => 'SIN_INSCRIPCION', 'LIGA_ENTREGADA' => 'NO')
  end

  it 'no declara nada sin sección [VARIABLES]' do
    expect(described_class.parse("[ROL]\nHola")).to be_blank
  end

  it 'quita la línea VARIABLES y devuelve solo los valores declarados' do
    text = "Tu liga: https://x.mx\nVARIABLES: LIGA_ENTREGADA=si; SIGUIENTE_OFERTA=primera beca; CARRERA=Derecho; OTRA=1\n\n#inscrito"
    clean, changes = described_class.extract(text, definition)

    expect(clean).to eq("Tu liga: https://x.mx\n\n#inscrito")
    expect(changes).to eq('LIGA_ENTREGADA' => 'SÍ', 'SIGUIENTE_OFERTA' => 'PRIMERA_BECA', 'CARRERA' => 'Derecho')
  end

  it 'reconoce la línea suelta de una variable declarada y descarta valores no declarados' do
    clean, changes = described_class.extract("Listo\nLIGA_ENTREGADA=SÍ\nSIGUIENTE_OFERTA=CUARTA_BECA", definition)

    expect(clean).to eq('Listo')
    expect(changes).to eq('LIGA_ENTREGADA' => 'SÍ')
  end

  it 'quita la línea pegada al final de una frase' do
    clean, changes = described_class.extract("Te ofrezco 30%. VARIABLES: SIGUIENTE_OFERTA=AGOTADA; CARRERA=Derecho\n\n-TB", definition)

    expect(clean).to eq("Te ofrezco 30%.\n\n-TB")
    expect(changes).to eq('SIGUIENTE_OFERTA' => 'AGOTADA', 'CARRERA' => 'Derecho')
  end

  it 'deja en paz «variables:» en minúsculas dentro de una respuesta normal' do
    texto = 'Estas son las variables: precio y plazo.'
    expect(described_class.extract(texto, definition)).to eq([texto, {}])
  end

  it 'pisa los iniciales con lo guardado en la conversación del mismo Agente IA' do
    tracking     = instance_double(ContactTracking, complementary_prompt: prompt, tracking_template_id: 7, id: 1)
    conversation = instance_double(Conversation, additional_attributes: { 'agent_variables' => { '7' => { 'CARRERA' => 'Psicología' } } })

    expect(described_class.current(tracking, conversation)['CARRERA']).to eq('Psicología')
    expect(described_class.rule_for(tracking, conversation)).to include("CARRERA=Psicología\nSIGUIENTE_OFERTA=SIN_INSCRIPCION")
  end
end
