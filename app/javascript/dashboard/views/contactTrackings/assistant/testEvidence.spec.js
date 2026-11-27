import { mentionsConversation } from './conversationReview';
import { evidenceMessage, pathSummary, compareRuns } from './testEvidence';

// proyecto@diagrama_agente_ia F4 — docs/diagrama_agente_ia_plan.md §4.4 y §5
const t = (clave, args) => (args ? `${clave} ${JSON.stringify(args)}` : clave);

const vivo = (cambios = {}) => ({
  at: 'x',
  reply: 'Claro, el kit cuesta $450.\n\n#cotizar',
  cumple: false,
  motivo: 'Inventó un precio',
  fallas: ['precio que no está en la Lista'],
  conversation: 173,
  traza: {
    camino: 'kbase',
    ruta: { nombre: 'cotizar' },
    fuente: { modo: 'google_doc', nombre: 'Lista' },
    fragmentos: [{ similitud: 0.41 }, { similitud: 0.2 }],
  },
  ...cambios,
});

describe('pathSummary', () => {
  it('en vivo: ruta, fuente con fragmentos, quién contestó y la etiqueta', () => {
    expect(pathSummary('live', vivo(), t)).toBe(
      'cotizar → google_doc · Lista (EVIDENCE_FRAGMENTS {"count":2,"best":"0.41"}) → ' +
        'EVIDENCE_ANSWERED_BY {"camino":"kbase"} → #cotizar'
    );
  });

  it('en vivo sin traza lo dice', () => {
    expect(pathSummary('live', vivo({ traza: null }), t)).toBe(
      'EVIDENCE_NO_TRACE'
    );
  });

  it('en seco: ruta, fuente, caso y etiqueta', () => {
    const informe = {
      routes: { chosen: 'cotizar' },
      source: {
        mode: 'google_doc',
        source_name: 'Lista',
        items: [{ similarity: 0.8 }],
      },
      case: { creates: true },
      tag: '#cotizar',
    };

    expect(pathSummary('dry', informe, t)).toBe(
      'cotizar → google_doc · Lista (EVIDENCE_FRAGMENTS {"count":1,"best":"0.80"}) → ' +
        'EVIDENCE_CASE → #cotizar'
    );
    expect(
      pathSummary(
        'dry',
        { routes: { chosen: 'soporte' }, source: { reason: 'no_source' } },
        t
      )
    ).toBe('soporte → EVIDENCE_NO_SOURCE');
  });
});

describe('evidenceMessage', () => {
  it('lleva cliente, respuesta, camino, veredicto y la pregunta', () => {
    const texto = evidenceMessage(
      [{ message: '¿precio del kit?', live: vivo() }],
      t
    );

    expect(texto).toContain('EVIDENCE_INTRO {"count":1}');
    expect(texto).toContain('CUSTOMER ¿precio del kit?');
    expect(texto).toContain('AGENT Claro, el kit cuesta $450.');
    expect(texto).toContain(
      'VERDICT ❌ Inventó un precio (precio que no está en la Lista)'
    );
    expect(texto).toContain('EVIDENCE_TEST_ID {"id":173}');
    expect(texto).toContain('EVIDENCE_ASK');
  });

  it('no dispara la revisión de una conversación real', () => {
    const real = (clave, args) =>
      clave === 'EVIDENCE_TEST_ID'
        ? `Prueba #${args.id} del canal de pruebas`
        : clave;

    expect(
      mentionsConversation(
        evidenceMessage([{ message: 'hola', live: vivo() }], real)
      )
    ).toBe(false);
  });

  it('las que nunca corrieron no van, y hay tope', () => {
    const filas = Array.from({ length: 8 }, (_, i) => ({
      message: `m${i}`,
      dry: { routes: { chosen: 'x' } },
    }));
    filas.unshift({ message: 'nunca' });

    const texto = evidenceMessage(filas, t);
    expect(texto).not.toContain('nunca');
    expect(texto).toContain('EVIDENCE_INTRO {"count":5}');
    expect(evidenceMessage([{ message: 'nunca' }], t)).toBe('');
  });
});

describe('compareRuns', () => {
  it('cuenta antes y ahora, y separa lo arreglado de lo roto', () => {
    const corrida = cumple => ({ at: 'x', cumple });
    const casos = [
      {
        id: 1,
        message: 'a',
        previous_live: corrida(true),
        last_live: corrida(false),
      },
      {
        id: 2,
        message: 'b',
        previous_live: corrida(false),
        last_live: corrida(true),
      },
      {
        id: 3,
        message: 'c',
        previous_live: corrida(true),
        last_live: corrida(true),
      },
      { id: 4, message: 'd', previous_live: {}, last_live: corrida(false) },
    ];

    const comparado = compareRuns(casos);

    expect(comparado).toMatchObject({ compared: 3, before: 2, after: 2 });
    expect(comparado.broken.map(c => c.id)).toEqual([1]);
    expect(comparado.fixed.map(c => c.id)).toEqual([2]);
  });
});

// F5
describe('evidencia de un diálogo', () => {
  it('lleva cada turno, no solo el primero', () => {
    const texto = evidenceMessage(
      [
        {
          message: 'quiero cita',
          turns: ['quiero cita', 'el martes'],
          live: vivo({
            dialog: [
              { customer: 'quiero cita', reply: '¿Qué día?' },
              { customer: 'el martes', reply: 'Listo' },
            ],
          }),
        },
      ],
      t
    );

    expect(texto).toContain('CUSTOMER quiero cita\nAGENT ¿Qué día?');
    expect(texto).toContain('CUSTOMER el martes\nAGENT Listo');
  });

  it('en seco lleva los mensajes del cliente', () => {
    const texto = evidenceMessage(
      [{ message: 'a', turns: ['a', 'b'], dry: { routes: { chosen: 'x' } } }],
      t
    );

    expect(texto).toContain('CUSTOMER a\nCUSTOMER b');
  });
});
