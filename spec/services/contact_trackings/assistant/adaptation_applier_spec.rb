# frozen_string_literal: true

# proyecto@adaptar_prompts_publicados (F1)
require 'rails_helper'

RSpec.describe ContactTrackings::Assistant::AdaptationApplier do
  def aplicar(texto, respuestas)
    described_class.new(texto, respuestas).call
  end

  it 'llena todas las marcas de una variable, sin importar mayúsculas' do
    texto = "Eres de <PENDIENTE: Nombre del negocio>.\nAdiós de <pendiente: nombre del negocio>. <PENDIENTE: Horario>"
    resultado = aplicar(texto, 'var:nombre del negocio' => 'Grúas del Norte')

    expect(resultado.text).to eq("Eres de Grúas del Norte.\nAdiós de Grúas del Norte. <PENDIENTE: Horario>")
    expect(resultado.applied).to eq(['var:nombre del negocio'])
  end

  it 'cambia solo la fuente nombrada y deja el resto del texto igual' do
    texto = "@ruta(ventas: precio): {{doc:Precios}} -> @crear_ticket(tipo=Ventas)\nVer {{ doc : precios }} y {{doc:Otro}}."
    resultado = aplicar(texto, 'google_doc:precios' => 'Lista 2026')

    expect(resultado.text).to eq(
      "@ruta(ventas: precio): {{doc:Lista 2026}} -> @crear_ticket(tipo=Ventas)\nVer {{doc:Lista 2026}} y {{doc:Otro}}."
    )
  end

  it 'reescribe hoja, foro y contpaq' do
    texto = '{{hoja:Catalogo}} @buscar_foro(Foro X) @soporte_contpaq(Kontrolya)'
    resultado = aplicar(texto, 'google_sheet:catalogo' => 'Catálogo 2026',
                               'knowledge_source:foro x' => 'Foro Y',
                               'contpaq_support:kontrolya' => 'Soporte K')

    expect(resultado.text).to eq('{{hoja:Catálogo 2026}} @buscar_foro(Foro Y) @soporte_contpaq(Soporte K)')
  end

  it '{{hoja_buscar:}}: cambia la hoja y conserva las columnas' do
    resultado = aplicar('{{hoja_buscar: Gruas | marca=? | precio}}', 'sheet_lookup:gruas' => 'Grúas 2026')

    expect(resultado.text).to eq('{{hoja_buscar: Grúas 2026 | marca=? | precio}}')
  end

  it '{{consulta:}}: cambia la consulta y conserva conexión y parámetros' do
    resultado = aplicar('{{consulta:sae/saldo(rfc=?)}} y {{consulta:otra}}', 'erp_query:sae/saldo' => 'saldo_cliente')

    expect(resultado.text).to eq('{{consulta:sae/saldo_cliente(rfc=?)}} y {{consulta:otra}}')
  end

  it 'archivo y tipo de caso; las etiquetas no se tocan' do
    texto = "@ruta(ventas #cotizacion: precio): - -> @crear_ticket(tipo=Ventas, prioridad=alta)\n" \
            'Manda {{catalogo}}. Cierra con #cotizacion. No toques #cotizacion_vieja.'
    resultado = aplicar(texto, 'attachment:catalogo' => '{{catalogo_2026}}', 'label:cotizacion' => '#Cotizar',
                               'case_type:ventas' => 'Comercial')

    expect(resultado.text).to eq(
      "@ruta(ventas #cotizacion: precio): - -> @crear_ticket(tipo=Comercial, prioridad=alta)\n" \
      'Manda {{catalogo_2026}}. Cierra con #cotizacion. No toques #cotizacion_vieja.'
    )
    expect(resultado.applied).to contain_exactly('attachment:catalogo', 'case_type:ventas')
    expect(resultado.rejected).to eq([{ key: 'label:cotizacion', reason: 'not_applicable' }])
  end

  it 'aplicar dos veces da el mismo texto' do
    texto = 'Usa {{doc:Precios}} de <PENDIENTE: Negocio>.'
    respuestas = { 'google_doc:precios' => 'Lista', 'var:negocio' => 'Grúas' }
    una = aplicar(texto, respuestas)
    dos = aplicar(una.text, respuestas)

    expect(dos.text).to eq(una.text)
    expect(dos.rejected.pluck(:reason)).to all(eq('not_found'))
  end

  describe 'lo que no se aplica' do
    it 'un valor que cerraría la directiva antes de tiempo' do
      resultado = aplicar('{{doc:Precios}} @buscar_foro(F)', 'google_doc:precios' => 'Lista}} y más',
                                                             'knowledge_source:f' => 'Foro (viejo)')

      expect(resultado.text).to eq('{{doc:Precios}} @buscar_foro(F)')
      expect(resultado.rejected).to contain_exactly({ key: 'google_doc:precios', reason: 'invalid' },
                                                    { key: 'knowledge_source:f', reason: 'invalid' })
    end

    it 'un archivo con espacios, o un valor que es otra marca <PENDIENTE:>' do
      resultado = aplicar('{{catalogo}} <PENDIENTE: Horario>', 'attachment:catalogo' => 'catalogo nuevo',
                                                               'var:horario' => '<PENDIENTE: luego>')

      expect(resultado.rejected.pluck(:reason)).to eq(%w[invalid pending])
      expect(resultado.text).to eq('{{catalogo}} <PENDIENTE: Horario>')
    end

    it 'un valor con \\1 se escribe tal cual (no es una referencia de la regex)' do
      resultado = aplicar('{{doc:Precios}}', 'google_doc:precios' => 'Lista \\1')

      expect(resultado.text).to eq('{{doc:Lista \\1}}')
    end

    it 'un valor vacío deja la marca, y lo que se configura en otra pantalla vuelve como not_applicable' do
      resultado = aplicar('<PENDIENTE: Horario> @agendar_calendar', 'var:horario' => '  ', 'calendar' => 'x')

      expect(resultado.text).to eq('<PENDIENTE: Horario> @agendar_calendar')
      expect(resultado.rejected).to eq([{ key: 'calendar', reason: 'not_applicable' }])
    end
  end
end
