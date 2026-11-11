import {
  cleanConstantName,
  constantUsage,
  constantsIndex,
  parseConstants,
  readConstants,
  serializeConstants,
  writeConstants,
} from './agentConstants';

const BODY = [
  'EMPRESA = Kontrolya',
  'LIGA (liga) = https://kontrolya.com/agenda/',
  'Q1 (pregunta) = ¿Qué sistemas utilizas hoy? → guarda en SISTEMA',
  'CIERRE = Ahora que ya entendí 👌',
  '',
  '  Agenda aquí 👇 %LIGA%',
].join('\n');

const blocks = extra => [
  { type: 'preamble', text: 'Hola de %EMPRESA%', gap: 1 },
  {
    type: 'routes',
    text: '@ruta(demo: quiero una demo de %EMPRESA%): -',
    lines: [
      {
        kind: 'route',
        name: 'demo',
        raw: '@ruta(demo: quiero una demo de %EMPRESA%): -',
      },
    ],
    gap: 1,
  },
  { type: 'section', title: 'VARIABLES', body: 'SISTEMA = valor', gap: 1 },
  {
    type: 'section',
    title: 'BIENVENIDA',
    body: 'Haz %Q1%. Cierra con %CIERRE%',
    gap: 1,
  },
  ...(extra || []),
];

describe('agentConstants', () => {
  it('lee la sección como el motor', () => {
    const { constants } = parseConstants(BODY);
    expect(constants.map(c => [c.name, c.type])).toEqual([
      ['EMPRESA', 'texto'],
      ['LIGA', 'liga'],
      ['Q1', 'pregunta'],
      ['CIERRE', 'texto'],
    ]);
    expect(constants[2]).toMatchObject({
      value: '¿Qué sistemas utilizas hoy?',
      savesTo: 'SISTEMA',
    });
    expect(constants[3].value).toBe(
      'Ahora que ya entendí 👌\n\nAgenda aquí 👇 %LIGA%'
    );
  });

  it('escribir lo que se leyó no cambia el texto', () => {
    expect(serializeConstants(parseConstants(BODY))).toBe(BODY);
  });

  it('deja el nombre como lo acepta el motor', () => {
    expect(cleanConstantName('Liga de agenda')).toBe('LIGA_DE_AGENDA');
    expect(cleanConstantName('1 empresa!')).toBe('EMPRESA');
  });

  it('crea [DATOS FIJOS] después de [VARIABLES] y la quita si queda vacía', () => {
    const con = writeConstants(blocks(), parseConstants(BODY));
    expect(constantsIndex(con)).toBe(3);
    expect(con[2].title).toBe('VARIABLES');
    expect(readConstants(con).constants).toHaveLength(4);
    const sin = writeConstants(con, { constants: [], extra: [] });
    expect(constantsIndex(sin)).toBe(-1);
  });

  it('la pregunta sin variable no escribe «guarda en»', () => {
    expect(
      serializeConstants({
        constants: [
          {
            name: 'Q2',
            type: 'pregunta',
            value: '¿Dónde nos conociste?',
            savesTo: '',
          },
        ],
      })
    ).toBe('Q2 (pregunta) = ¿Dónde nos conociste?');
  });

  it('dice dónde se usa cada uno, también desde otro dato fijo', () => {
    const con = writeConstants(blocks(), parseConstants(BODY));
    const uso = constantUsage(con, readConstants(con).constants);
    expect(uso.EMPRESA).toEqual({ count: 2, places: ['', '@demo'] });
    expect(uso.Q1.places).toEqual(['BIENVENIDA']);
    expect(uso.LIGA.places).toEqual(['%CIERRE%']);
  });
});
