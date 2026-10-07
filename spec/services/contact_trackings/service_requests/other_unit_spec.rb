require 'rails_helper'

RSpec.describe ContactTrackings::ServiceRequests::OtherUnit do
  it 'reconoce cuando piden CAMBIAR la unidad, no cuando piden una más (conv. 398)' do
    cambio = ['Oye pero el segundo es la misma grúa, necesito dos grúas diferentes, tienes otra?', '¿hay otra unidad?', 'cambia la grúa del 2']
    nuevo = ['necesito otra grúa para el martes', 'Necesito además otro low boy', 'el otro son 11 toneladas']

    expect(cambio.map { |t| described_class.asked?(t) }).to all(be(true))
    expect(nuevo.map { |t| described_class.asked?(t) }).to all(be(false))
  end
end
