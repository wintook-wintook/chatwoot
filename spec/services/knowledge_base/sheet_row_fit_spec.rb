# frozen_string_literal: true

require 'rails_helper'

# La fila de Bienes Raíces de la cuenta 568 (01/10/2026): 2129 caracteres, con la imagen
# detrás de un perfil de egreso largo. Cortada al final, el modelo nunca veía la imagen.
RSpec.describe KnowledgeBase::SheetRowFit do
  let(:perfil) { "perfil_de_egreso: #{'Gestiona proyectos inmobiliarios y valúa bienes raíces. ' * 11}" }
  let(:fila) do
    ['id_carrera: LIC-BR', 'carrera: Desarrollo y Administración Inmobiliaria en Bienes Raíces',
     'PRIMERA BECA: 28%  toda la Licenciatura, paga $ 2,300.00', "plan_estudios_url: https://neoclase.com/#{'x' * 90}",
     perfil, "notas_validacion: #{'revisado ' * 40}", 'imagen promocion: imagen_promo1'].join("\n")
  end

  it 'deja una fila corta tal cual' do
    expect(described_class.call("carrera: Derecho\nimagen promocion: imagen_promo2", 2000))
      .to eq("carrera: Derecho\nimagen promocion: imagen_promo2")
  end

  it 'cabe en el tope y conserva enteros los campos cortos, aunque estén al final' do
    resultado = described_class.call(fila, 500)

    expect(resultado.size).to be <= 500
    expect(resultado).to include('imagen promocion: imagen_promo1')
    expect(resultado).to include('PRIMERA BECA: 28%  toda la Licenciatura, paga $ 2,300.00')
    expect(resultado).to include('carrera: Desarrollo y Administración Inmobiliaria en Bienes Raíces')
  end

  it 'acorta los valores largos, con su columna a la vista' do
    resultado = described_class.call(fila, 500)
    linea = resultado.lines.find { |l| l.start_with?('perfil_de_egreso:') }

    expect(linea.chomp).to end_with('…')
    expect(linea.size).to be < perfil.size
  end

  it 'una celda en viñetas cuenta como un solo campo: se acorta ella y no las demás' do
    vinetas = Array.new(8) { |n| "• Competencia #{n}: #{'gestión inmobiliaria y valuación de bienes ' * 2}" }
    fila = ['Costo de titulación: Con un monto de $25,428 a $30,272, pueden ir abonando hasta liquidar el total',
            'perfil_de_egreso: Al egresar podrás:', *vinetas, 'imagen promocion: imagen_promo1'].join("\n")

    resultado = described_class.call(fila, 400)

    expect(resultado.size).to be <= 400
    expect(resultado).to include('Costo de titulación: Con un monto de $25,428 a $30,272, pueden ir abonando hasta liquidar el total')
    expect(resultado).to include('imagen promocion: imagen_promo1')
    expect(resultado).to include('…')
  end

  # Cuenta 1128, conv 60 (02/11/2026): la liga del plan de estudios llegaba cortada.
  it 'no acorta un valor de una sola pieza (URL o archivo) aunque sea largo' do
    url = 'https://neoclase.com/wp-content/uploads/2026/09/Plan-de-estudios-de-la-carrera-de-Administracion.pdf'
    resultado = described_class.call([fila, "plan_estudios_url: #{url}"].join("\n"), 600)

    expect(resultado.size).to be <= 600
    expect(resultado).to include("plan_estudios_url: #{url}")
    expect(resultado).to include("plan_estudios_url: https://neoclase.com/#{'x' * 90}")
  end

  # Misma cuenta, fila de Bienes Raíces: la celda sigue con una nota detrás de la URL.
  it 'no parte una URL aunque la celda siga con más texto; corta después de ella' do
    url = 'https://neoclase.com/wp-content/uploads/2026/09/Plan-de-estudios-de-la-carrera-de-INNeo.pdf'
    celda = "plan_estudios_url: #{url} , nota: #{'dentro de la liga encontraras la ubicación de la universidad ' * 3}"
    resultado = described_class.call([fila, celda].join("\n"), 600)
    linea = resultado.lines.find { |l| l.start_with?('plan_estudios_url: https://neoclase.com/wp') }

    expect(resultado.size).to be <= 600
    expect(linea.chomp).to eq("plan_estudios_url: #{url}…")
  end

  it 'si ni acortando todo cabe, corta el final como antes' do
    muchas = Array.new(40) { |n| "columna_#{n}: #{'v' * 70}" }.join("\n")

    expect(described_class.call(muchas, 500).size).to be <= 500
  end
end
