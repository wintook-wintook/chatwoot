require 'rails_helper'

RSpec.describe ContactTrackings::ServiceRequests::Options do
  it 'sin opciones, todo apagado (los agentes de siempre no cambian)' do
    opciones = described_class.parse('@solicitudes -> @crear_ticket(tipo=X) -> @agendar_calendar')

    expect([opciones.assign, opciones.data_first?, opciones.unknown_pending?, opciones.month_first?, opciones.max_missing])
      .to eq([nil, false, false, false, nil])
  end

  it 'asignar sigue funcionando solo, como antes' do
    expect(described_class.parse('@solicitudes(asignar=unidad) -> @crear_ticket').assign).to eq('unidad')
  end

  it 'lee varias opciones separadas por coma, sin importar mayúsculas, espacios ni acentos' do
    opciones = described_class.parse('@solicitudes( asignar=unidad, Datos=Primero, sin_dato = pendiente, fecha=Mes/Día, faltan=2 )')

    expect([opciones.assign, opciones.data_first?, opciones.unknown_pending?, opciones.month_first?, opciones.max_missing])
      .to eq(['unidad', true, true, true, 2])
  end

  it 'un valor que no reconoce no prende nada' do
    opciones = described_class.parse('@solicitudes(datos=despues, fecha=dia/mes, faltan=muchos)')

    expect([opciones.data_first?, opciones.month_first?, opciones.max_missing]).to eq([false, false, nil])
  end
end
