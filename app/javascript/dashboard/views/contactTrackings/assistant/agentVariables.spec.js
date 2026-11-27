import {
  cleanVariableName,
  moveStrayVariables,
  parseVariables,
  readVariables,
  serializeVariables,
  strayVariables,
  variablesIndex,
  writeVariables,
} from './agentVariables';

const BECAS = [
  'CARRERA = valor',
  'LIGA_ENTREGADA = NO | SÍ',
  'Inicial: LIGA_ENTREGADA=NO',
].join('\n');

const blocks = extra => [
  { type: 'preamble', text: 'Eres el agente.', gap: 1 },
  { type: 'routes', lines: [], gap: 1 },
  { type: 'section', title: 'ROL', body: 'Atiendes ventas.', gap: 1 },
  ...(extra || []),
];

describe('agentVariables', () => {
  it('lee la sección como la lee el motor', () => {
    expect(parseVariables(BECAS)).toEqual({
      variables: [
        { name: 'CARRERA', options: [], free: true, initial: '' },
        {
          name: 'LIGA_ENTREGADA',
          options: ['NO', 'SÍ'],
          free: false,
          initial: 'NO',
        },
      ],
      extra: [],
    });
  });

  it('escribir lo que se leyó no cambia el texto', () => {
    expect(serializeVariables(parseVariables(BECAS))).toBe(BECAS);
  });

  it('conserva las notas que no son declaraciones', () => {
    const body = `${BECAS}\n\nSolo cambia CARRERA si la dice clara.`;
    const leido = parseVariables(body);
    expect(leido.extra).toEqual(['Solo cambia CARRERA si la dice clara.']);
    expect(serializeVariables(leido)).toBe(body);
  });

  it('acepta opciones y texto libre juntos («VACIO | valor»)', () => {
    const [v] = parseVariables(
      'SISTEMA = VACIO | valor | NO_DISPONIBLE'
    ).variables;
    expect(v).toMatchObject({
      options: ['VACIO', 'NO_DISPONIBLE'],
      free: true,
    });
    expect(serializeVariables({ variables: [v] })).toBe(
      'SISTEMA = VACIO | NO_DISPONIBLE | valor'
    );
  });

  it('deja el nombre como lo acepta el motor', () => {
    expect(cleanVariableName(' liga entregada! ')).toBe('LIGA_ENTREGADA');
    expect(cleanVariableName('2do_paso')).toBe('DO_PASO');
  });

  it('crea [VARIABLES] antes de las demás secciones y la quita si queda vacía', () => {
    const conVars = writeVariables(blocks(), parseVariables(BECAS));
    expect(variablesIndex(conVars)).toBe(2);
    expect(conVars[3].title).toBe('ROL');
    expect(readVariables(conVars).variables).toHaveLength(2);

    const sinVars = writeVariables(conVars, { variables: [], extra: [] });
    expect(variablesIndex(sinVars)).toBe(-1);
    expect(sinVars).toHaveLength(3);
  });

  it('no escribe filas sin nombre o sin valores', () => {
    expect(
      serializeVariables({
        variables: [
          { name: '', options: ['A'], free: false, initial: '' },
          { name: 'X', options: [], free: false, initial: '' },
        ],
      })
    ).toBe('');
  });

  describe('V5 · pasarlas a Variables', () => {
    const dci = blocks([
      {
        type: 'section',
        title: '3. NÚCLEO DCI',
        body: [
          'Registra y actualiza silenciosamente:',
          '* OBJETIVO_COMERCIAL = VACIO | valor',
          '* CIERRE_ENVIADO = NO | SI',
          'Ofrece 10% de beca.',
        ].join('\n'),
        gap: 1,
      },
    ]);

    it('encuentra las sueltas', () => {
      expect(strayVariables(dci).map(v => v.name)).toEqual([
        'OBJETIVO_COMERCIAL',
        'CIERRE_ENVIADO',
      ]);
    });

    it('las quita de su sección y las escribe en [VARIABLES]', () => {
      const movido = moveStrayVariables(dci);
      expect(strayVariables(movido)).toEqual([]);
      const nucleo = movido.find(b => b.title === '3. NÚCLEO DCI');
      expect(nucleo.body).toBe(
        'Registra y actualiza silenciosamente:\nOfrece 10% de beca.'
      );
      expect(movido[variablesIndex(movido)].body).toBe(
        'OBJETIVO_COMERCIAL = VACIO | valor\nCIERRE_ENVIADO = NO | SI'
      );
    });

    it('parte un renglón con varias en una por renglón', () => {
      const movido = moveStrayVariables(
        blocks([
          {
            type: 'section',
            title: 'ESTADOS',
            body: 'CARRERA=VACÍO|valor; LIGA_ENTREGADA=NO|SÍ; REVALIDACIÓN=NO|SÍ.',
            gap: 1,
          },
        ])
      );
      expect(readVariables(movido).variables.map(v => v.name)).toEqual([
        'CARRERA',
        'LIGA_ENTREGADA',
        'REVALIDACIÓN',
      ]);
      expect(readVariables(movido).variables[2].options).toEqual(['NO', 'SÍ']);
    });

    it('si ya existe en [VARIABLES], se queda la de [VARIABLES]', () => {
      const conAmbas = writeVariables(
        dci,
        parseVariables('CIERRE_ENVIADO = NO | SÍ | TAL_VEZ')
      );
      const movido = moveStrayVariables(conAmbas);
      const vars = readVariables(movido).variables;
      expect(vars.map(v => v.name)).toEqual([
        'CIERRE_ENVIADO',
        'OBJETIVO_COMERCIAL',
      ]);
      expect(vars[0].options).toEqual(['NO', 'SÍ', 'TAL_VEZ']);
    });

    it('sin sueltas devuelve los mismos bloques', () => {
      const b = blocks();
      expect(moveStrayVariables(b)).toBe(b);
    });
  });
});
