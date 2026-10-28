import { buildDiagram } from './agentDiagramLayout';
import { pathFromTrace, pathFromDryRun } from './testPath';

// proyecto@diagrama_agente_ia F2 — docs/diagrama_agente_ia_plan.md §4.2
const bloques = () => [
  {
    type: 'routes',
    lines: [
      {
        kind: 'route',
        name: 'cotizar',
        tag: 'cotizar',
        source: '{{doc:Lista}}',
        escalation: '@crear_ticket',
        action: '@crear_ticket',
      },
      { kind: 'route', name: 'soporte', tag: 'soporte', source: '' },
      { kind: 'default', name: 'soporte' },
    ],
  },
  { type: 'section', title: 'MENSAJE DE BIENVENIDA', body: 'Hola' },
];
const diagrama = () => buildDiagram(bloques());

describe('pathFromTrace (en vivo)', () => {
  it('kbase: cliente → ruta → fuente → etiqueta, con los fragmentos en la fuente', () => {
    const camino = pathFromTrace(
      {
        camino: 'kbase',
        ruta: { nombre: 'cotizar', como: 'clasificada' },
        fragmentos: [{ similitud: 0.61 }, { similitud: 0.82 }],
      },
      diagrama(),
      'El kit cuesta…\n\n#cotizar'
    );

    expect(camino.mode).toBe('live');
    expect(camino.nodes).toEqual(
      expect.arrayContaining([
        'client',
        'route:cotizar',
        'source:cotizar',
        'tag:cotizar',
      ])
    );
    expect(camino.nodes).not.toContain('action:cotizar');
    expect(camino.edges).toEqual(
      expect.arrayContaining([
        'client->route:cotizar',
        'route:cotizar->source:cotizar',
      ])
    );
    expect(camino.details['source:cotizar']).toEqual({
      key: 'PATH_FRAGMENTS',
      args: { count: 2, best: '0.82' },
    });
    expect(camino.failed).toEqual([]);
  });

  it('la fuente que no trajo nada y cayó a conversar es el punto débil', () => {
    const camino = pathFromTrace(
      { camino: 'conversacional', ruta: { nombre: 'cotizar' } },
      diagrama()
    );

    expect(camino.failed).toEqual(['source:cotizar']);
    expect(camino.details['source:cotizar'].key).toBe('PATH_SOURCE_EMPTY');
  });

  it('el caso abierto enciende la acción', () => {
    const camino = pathFromTrace(
      { camino: 'ticket', ruta: { nombre: 'cotizar' } },
      diagrama()
    );

    expect(camino.nodes).toContain('action:cotizar');
  });

  it('una ruta sin fuente se enciende entera al conversar, y avisa si cayó por defecto', () => {
    const camino = pathFromTrace(
      {
        camino: 'conversacional',
        ruta: { nombre: 'soporte', como: 'por_defecto' },
        etiqueta_repuesta: '#soporte',
      },
      diagrama()
    );

    expect(camino.nodes).toEqual(
      expect.arrayContaining(['route:soporte', 'source:soporte', 'tag:soporte'])
    );
    expect(camino.failed).toEqual([]);
    expect(camino.details['route:soporte'].key).toBe('PATH_BY_DEFAULT');
  });

  it('la bienvenida y los caminos de antes de las rutas', () => {
    expect(pathFromTrace({ camino: 'bienvenida' }, diagrama()).nodes).toEqual([
      'welcome',
      'client',
    ]);
    expect(pathFromTrace({ camino: 'palabra_clave' }, diagrama()).note).toEqual(
      { key: 'PATH_BEFORE_ROUTES', args: { camino: 'palabra_clave' } }
    );
  });

  it('no inventa: una ruta que ya no está no se pinta', () => {
    const camino = pathFromTrace(
      { camino: 'kbase', ruta: { nombre: 'viejo' } },
      diagrama()
    );

    expect(camino.nodes).toEqual(['client']);
    expect(camino.note).toEqual({
      key: 'PATH_ROUTE_GONE',
      args: { route: 'viejo' },
    });
  });

  it('sin traza solo lo dice', () => {
    expect(pathFromTrace(null, diagrama()).note.key).toBe('PATH_NO_TRACE');
  });

  it('un agente sin rutas enciende la fila conversacional', () => {
    const camino = pathFromTrace(
      { camino: 'conversacional', ruta: { como: 'sin_ruta' } },
      buildDiagram([])
    );

    expect(camino.nodes).toEqual(['conversational', 'client']);
    expect(camino.edges).toEqual(['client->conversational']);
  });
});

describe('pathFromDryRun (en seco)', () => {
  const informe = (cambios = {}) => ({
    routes: { chosen: 'cotizar', default: 'soporte' },
    source: { mode: 'google_doc', items: [{ similarity: 0.7 }] },
    tag: '#cotizar',
    case: { creates: true },
    ...cambios,
  });

  it('ruta, fuente con fragmentos, caso pronosticado y etiqueta', () => {
    const camino = pathFromDryRun(informe(), diagrama());

    expect(camino.mode).toBe('dry');
    expect(camino.nodes).toEqual(
      expect.arrayContaining([
        'route:cotizar',
        'source:cotizar',
        'action:cotizar',
        'tag:cotizar',
      ])
    );
    expect(camino.details['source:cotizar'].args).toEqual({
      count: 1,
      best: '0.70',
    });
  });

  it('una búsqueda sin resultados, una fuente en vivo y una rota', () => {
    expect(
      pathFromDryRun(informe({ source: { items: [] } }), diagrama()).failed
    ).toEqual(['source:cotizar']);
    const vivo = pathFromDryRun(
      informe({ source: { reason: 'live_source' } }),
      diagrama()
    );
    expect(vivo.failed).toEqual([]);
    expect(vivo.details['source:cotizar'].key).toBe('PATH_SOURCE_LIVE');
    expect(
      pathFromDryRun(
        informe({ source: { reason: 'source_missing' } }),
        diagrama()
      ).details['source:cotizar'].key
    ).toBe('PATH_SOURCE_BROKEN');
  });

  it('avisa cuando la elegida es la por defecto', () => {
    const camino = pathFromDryRun(
      informe({
        routes: { chosen: 'soporte', default: 'soporte' },
        source: { reason: 'no_source' },
        case: { creates: false },
      }),
      diagrama()
    );

    expect(camino.details['route:soporte'].key).toBe('PATH_IS_DEFAULT');
    expect(camino.nodes).toContain('source:soporte');
  });

  it('sin rutas declaradas, la fila conversacional', () => {
    expect(
      pathFromDryRun({ routes: { none_declared: true } }, buildDiagram([]))
        .nodes
    ).toEqual(['conversational', 'client']);
  });
});
