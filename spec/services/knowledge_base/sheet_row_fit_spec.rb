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

  it 'si ni acortando todo cabe, corta el final como antes' do
    muchas = Array.new(40) { |n| "columna_#{n}: #{'v' * 70}" }.join("\n")

    expect(described_class.call(muchas, 500).size).to be <= 500
  end
end
