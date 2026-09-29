# frozen_string_literal: true

# proyecto@asistente_agentes_ia
require 'rails_helper'

RSpec.describe ContactTrackings::TrainingRoutes do
  describe '.parse' do
    it 'parte una rama en los campos que edita el formulario' do
      linea = '@ruta(comercial #precios: cuanto cuesta, precios): {{hoja:Precios}} -> @crear_ticket(tipo=Comercial)'

      expect(described_class.parse(linea).first).to eq(
        'kind' => 'route', 'name' => 'comercial', 'tag' => 'precios',
        'description' => 'cuanto cuesta, precios', 'source' => '{{hoja:Precios}}',
        'escalation' => '@crear_ticket(tipo=Comercial)', 'raw' => linea,
        'action' => '@crear_ticket', 'case_type' => 'Comercial', 'priority' => ''
      )
    end

    # El guion es la marca de "no consulta nada": como campo, es el campo vacío.
    it 'deja la fuente vacía cuando la rama no consulta nada' do
      expect(described_class.parse('@ruta(humano #humano: quiero hablar con alguien): -').first)
        .to include('source' => '', 'escalation' => '')
    end

    it 'reconoce la rama por defecto' do
      expect(described_class.parse('@ruta_por_defecto: comercial').first)
        .to eq('kind' => 'default', 'name' => 'comercial', 'raw' => '@ruta_por_defecto: comercial')
    end

    # Una línea que el parser no reconoce se conserva en su lugar: es lo que el motor
    # va a leer igual, y hacerla desaparecer del formulario la borraría al guardar.
    it 'conserva una línea que no es ninguna de las dos' do
      expect(described_class.parse('# esto es un comentario').first)
        .to eq('kind' => 'other', 'raw' => '# esto es un comentario')
    end
  end

  describe '.compose' do
    # La invariante del formulario: abrir y guardar sin tocar nada no cambia un carácter.
    it 'devuelve la línea original tal cual mientras los campos no cambien' do
      texto = "@ruta( soporte  #soporte : no puedo entrar ):   @discourse   =>  @crear_ticket(tipo=Soporte)\n" \
              '@ruta_por_defecto: soporte'

      expect(described_class.compose(described_class.parse(texto))).to eq(texto)
    end

    it 'reescribe la línea cuando se cambió un campo' do
      entradas = described_class.parse('@ruta(soporte #soporte: no puedo entrar): @discourse')
      entradas.first['source'] = '@buscar_articulo'

      expect(described_class.compose(entradas)).to eq('@ruta(soporte #soporte: no puedo entrar): @buscar_articulo')
    end

    it 'escribe el guion cuando la rama se deja sin fuente' do
      entradas = [{ 'kind' => 'route', 'name' => 'humano', 'tag' => 'humano', 'description' => 'un asesor' }]

      expect(described_class.compose(entradas)).to eq('@ruta(humano #humano: un asesor): -')
    end

    it 'omite la etiqueta y el escalamiento que se dejaron vacíos' do
      entradas = [{ 'kind' => 'route', 'name' => 'soporte', 'description' => 'no abre', 'source' => '@discourse' }]

      expect(described_class.compose(entradas)).to eq('@ruta(soporte: no abre): @discourse')
    end

    # Los campos del formulario son de una sola línea: un salto partiría la línea en dos
    # y el motor dejaría de leer la rama.
    it 'no deja que un salto de línea en un campo parta la rama' do
      entradas = [{ 'kind' => 'route', 'name' => 'soporte', 'description' => "no abre\nni entra", 'source' => '-' }]

      expect(described_class.compose(entradas)).to eq('@ruta(soporte: no abre ni entra): -')
    end

    # El paréntesis cierra la descripción para el parser: dejarlo pasar cortaría la rama.
    it 'saca el paréntesis de cierre de la descripción' do
      entradas = [{ 'kind' => 'route', 'name' => 'soporte', 'description' => 'no abre (nunca)', 'source' => '-' }]

      compuesto = described_class.compose(entradas)

      expect(compuesto).to eq('@ruta(soporte: no abre nunca): -')
      expect(ContactTrackings::RouteMap.parse(compuesto).names).to eq(['soporte'])
    end

    it 'limpia el nombre y la etiqueta de lo que la gramática no admite' do
      entradas = [{ 'kind' => 'route', 'name' => 'Citas Médicas', 'tag' => '#Citado!', 'description' => 'x', 'source' => '-' }]

      expect(described_class.compose(entradas)).to eq('@ruta(citasmdicas #citado: x): -')
    end

    it 'saltea la rama a la que le borraron el nombre' do
      entradas = [{ 'kind' => 'route', 'name' => '', 'description' => 'x', 'source' => '-' },
                  { 'kind' => 'default', 'name' => 'soporte' }]

      expect(described_class.compose(entradas)).to eq("\n@ruta_por_defecto: soporte")
    end
  end

  # Abrir un caso son tres decisiones: que abra, de qué tipo y con qué prioridad.
  describe 'el escalamiento en tres campos' do
    it 'parte @crear_ticket en acción, tipo y prioridad' do
      linea = '@ruta(admin #admin_x: facturas): - -> @crear_ticket(tipo=Administrativo, prioridad=media)'

      expect(described_class.parse(linea).first)
        .to include('action' => '@crear_ticket', 'case_type' => 'Administrativo', 'priority' => 'media')
    end

    it 'deja la acción entera cuando no lleva parámetros' do
      expect(described_class.parse('@ruta(citas #citado: una cita): - -> @agendar_calendar').first)
        .to include('action' => '@agendar_calendar', 'case_type' => '', 'priority' => '')
    end

    it 'vuelve a armar la directiva con lo que se eligió en los selectores' do
      entradas = [{ 'kind' => 'route', 'name' => 'admin', 'description' => 'facturas', 'source' => '',
                    'action' => '@crear_ticket', 'case_type' => 'Comercial', 'priority' => 'alta' }]

      expect(described_class.compose(entradas)).to eq('@ruta(admin: facturas): - -> @crear_ticket(tipo=Comercial, prioridad=alta)')
    end

    it 'omite la prioridad que se dejó sin elegir' do
      entradas = [{ 'kind' => 'route', 'name' => 'admin', 'description' => 'facturas', 'source' => '',
                    'action' => '@crear_ticket', 'case_type' => 'Comercial', 'priority' => '' }]

      expect(described_class.compose(entradas)).to eq('@ruta(admin: facturas): - -> @crear_ticket(tipo=Comercial)')
    end

    # Cambiar solo la prioridad tiene que reescribir la línea, no devolver la original.
    it 'reescribe la línea cuando cambió la prioridad' do
      entradas = described_class.parse('@ruta(admin #admin_x: facturas): - -> @crear_ticket(tipo=Soporte, prioridad=media)')
      entradas.first['priority'] = 'urgente'

      expect(described_class.compose(entradas))
        .to eq('@ruta(admin #admin_x: facturas): - -> @crear_ticket(tipo=Soporte, prioridad=urgente)')
    end

    it 'saca el escalamiento cuando se elige que no haga nada' do
      entradas = described_class.parse('@ruta(admin #admin_x: facturas): @buscar_articulo -> @crear_ticket(tipo=Soporte)')
      entradas.first.merge!('action' => '', 'case_type' => '', 'priority' => '')

      expect(described_class.compose(entradas)).to eq('@ruta(admin #admin_x: facturas): @buscar_articulo')
    end
  end

  # Una línea que empieza con @ruta( y el motor no lee: se ve como rama rota.
  describe 'la rama rota' do
    let(:rota) { '@ruta(informacion_general #informacion: ¿cómo trabajan?, ¿qué me pueden decir?)' }

    it 'se lee a ojo, para mostrarla y abrirla en el formulario' do
      expect(described_class.parse(rota).first).to include(
        'kind' => 'broken', 'name' => 'informacion_general', 'tag' => 'informacion',
        'description' => '¿cómo trabajan?, ¿qué me pueden decir?', 'source' => '', 'raw' => rota
      )
    end

    it 'sin tocarla vuelve igual' do
      expect(described_class.compose(described_class.parse(rota))).to eq(rota)
    end

    it 'editada sale escrita de cero, ya válida' do
      entradas = described_class.parse(rota)
      entradas.first['kind'] = 'route'

      linea = described_class.compose(entradas)
      expect(linea).to eq('@ruta(informacion_general #informacion: ¿cómo trabajan?, ¿qué me pueden decir?): -')
      expect(ContactTrackings::RouteMap.parse(linea).names).to eq(['informacion_general'])
    end

    it 'la rama por defecto no es una rama rota' do
      expect(described_class.parse('@ruta_por_defecto: soporte').first['kind']).to eq('default')
    end
  end

  describe '.sanitize' do
    it 'se queda solo con las claves y los tipos conocidos' do
      lineas = [{ 'kind' => 'route', 'name' => 'soporte', 'password' => 'x' },
                { 'kind' => 'inventado', 'name' => 'nada' }]

      expect(described_class.sanitize(lineas)).to eq([{ 'kind' => 'route', 'name' => 'soporte' }])
    end
  end

  # Lo que ve el formulario y lo que lee el motor tienen que ser lo mismo.
  describe 'contra el parser del motor' do
    it 'lee los mismos campos que RouteMap' do
      texto = '@ruta(comercial #precios: cuanto cuesta): {{hoja:Precios}} -> @crear_ticket(tipo=Comercial)'
      rama = ContactTrackings::RouteMap.parse(texto).routes.first
      campos = described_class.parse(texto).first

      expect(campos.values_at('name', 'tag', 'description', 'source', 'escalation'))
        .to eq([rama.name, rama.tag, rama.description, rama.directive, rama.escalation])
    end
  end
end
