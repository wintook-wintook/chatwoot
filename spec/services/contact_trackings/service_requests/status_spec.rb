require 'rails_helper'

RSpec.describe ContactTrackings::ServiceRequests::Status do
  it 'solo responde con el resumen cuando preguntan por SUS servicios (conv. 398)' do
    suyos = ['no entendí son dos grúas?', '¿cuántos servicios tengo?', '¿cómo quedaron mis grúas?', '¿qué me apartaste?']
    otros = ['¿Qué tipos de grúas manejan?', 'necesito dos grúas para el lunes', '¿tienen hiab?']

    expect(suyos.map { |t| described_class.asked?(t) }).to all(be(true))
    expect(otros.map { |t| described_class.asked?(t) }).to all(be(false))
  end
end
