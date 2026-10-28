import {
  buildDiagram,
  describeSource,
  describeAction,
  truncate,
  NODE_W,
  COL_GAP,
} from './agentDiagramLayout';

// proyecto@diagrama_agente_ia F1 — docs/diagrama_agente_ia_plan.md §4.2
const estructura = () => [
  {
    type: 'routes',
    first_line: 1,
    last_line: 3,
    lines: [
      {
        kind: 'route',
        name: 'cotizar',
        tag: 'cotizar',
        description: 'precios y cotizaciones',
        source: '{{doc:Lista de precios}}',
        escalation: '@crear_ticket(tipo=Venta)',
        action: '@crear_ticket',
        case_type: 'Venta',
      },
      {
        kind: 'route',
        name: 'soporte',
        tag: '',
        description: 'no funciona',
        source: '',
        escalation: '',
      },
      { kind: 'default', name: 'soporte' },
    ],
  },
  { type: 'section', title: 'ROL', body: 'Eres amable.', first_line: 4 },
  {
    type: 'section',
    title: 'MENSAJE DE BIENVENIDA',
    body: 'Hola',
    first_line: 6,
  },
];

const porId = diagrama =>
  Object.fromEntries(diagrama.nodes.map(n => [n.id, n]));

describe('buildDiagram', () => {
  it('arma una fila por ruta: ruta, fuente, acción y etiqueta', () => {
    const nodos = porId(buildDiagram(estructura()));

    expect(nodos['route:cotizar']).toMatchObject({
      label: 'cotizar',
      isDefault: false,
    });
    expect(nodos['source:cotizar']).toMatchObject({
      sourceKind: 'DOC',
      label: 'Lista de precios',
    });
    expect(nodos['action:cotizar']).toMatchObject({
      actionKind: 'TICKET',
      label: 'Venta',
    });
    expect(nodos['tag:cotizar']).toMatchObject({
      label: '#cotizar',
      missing: false,
    });
    // Las cuatro de la fila a la misma altura, en columnas consecutivas.
    const fila = ['route', 'source', 'action', 'tag'].map(
      c => nodos[`${c}:cotizar`]
    );
    expect(new Set(fila.map(n => n.y)).size).toBe(1);
    expect(fila[1].x - fila[0].x).toBe(NODE_W + COL_GAP);
  });

  it('sin acción la fuente va directo a la etiqueta, y sin fuente la línea es punteada', () => {
    const { nodes, edges } = buildDiagram(estructura());

    expect(nodes.find(n => n.id === 'action:soporte')).toBeUndefined();
    expect(
      edges.find(e => e.id === 'source:soporte->tag:soporte')
    ).toBeDefined();
    expect(
      edges.find(e => e.id === 'route:soporte->source:soporte').dashed
    ).toBe(true);
    expect(porId(buildDiagram(estructura()))['source:soporte'].muted).toBe(
      true
    );
  });

  it('marca la ruta por defecto y la etiqueta que falta', () => {
    const nodos = porId(buildDiagram(estructura()));

    expect(nodos['route:soporte'].isDefault).toBe(true);
    expect(nodos['tag:soporte'].missing).toBe(true);
  });

  it('la bienvenida es un ramal propio, punteado, que lleva a su sección', () => {
    const { nodes, edges } = buildDiagram(estructura());
    const bienvenida = nodes.find(n => n.id === 'welcome');

    expect(bienvenida.target).toEqual({ type: 'section', index: 2 });
    expect(edges.find(e => e.id === 'client->welcome').dashed).toBe(true);
  });

  it('el cliente llega a cada ruta y queda centrado en la altura de las filas', () => {
    const { nodes, edges } = buildDiagram(estructura());
    const cliente = nodes.find(n => n.id === 'client');
    const rutas = nodes.filter(n => n.column === 'route');

    expect(edges.filter(e => e.from === 'client')).toHaveLength(rutas.length);
    const centro = (rutas[0].y + rutas[rutas.length - 1].y) / 2;
    expect(cliente.y).toBeCloseTo(centro);
  });

  it('cada arista trae su curva', () => {
    buildDiagram(estructura()).edges.forEach(e =>
      expect(e.d).toMatch(/^M[\d.]+,[\d.]+ C/)
    );
  });

  it('cuelga los hallazgos del comprobador del nodo y del grupo de rutas', () => {
    const issues = {
      'route:cotizar': { level: 'degrading', messages: ['falta descripción'] },
      'route:': { level: 'blocking', messages: ['línea rota'] },
      'section:1': { level: 'degrading', messages: ['vacía'] },
    };
    const diagrama = buildDiagram(estructura(), issues);
    const nodos = porId(diagrama);

    expect(nodos['route:cotizar'].issue).toEqual({
      level: 'blocking',
      messages: ['falta descripción', 'línea rota'],
    });
    expect(nodos['route:soporte'].issue.level).toBe('blocking');
    expect(diagrama.sections.find(s => s.index === 1).issue.messages).toEqual([
      'vacía',
    ]);
  });

  it('un agente sin rutas es conversacional, no un error', () => {
    const diagrama = buildDiagram([
      { type: 'section', title: 'ROL', body: 'x' },
    ]);

    expect(diagrama.routeCount).toBe(0);
    expect(diagrama.nodes.map(n => n.id)).toEqual(['client', 'conversational']);
    expect(diagrama.columns.map(c => c.id)).toEqual(['client', 'route']);
  });

  it('lista las secciones aparte, con su lugar en los bloques', () => {
    expect(
      buildDiagram(estructura()).sections.map(s => [s.index, s.title])
    ).toEqual([
      [1, 'ROL'],
      [2, 'MENSAJE DE BIENVENIDA'],
    ]);
  });

  it('una línea de ruta mal escrita igual se dibuja, marcada', () => {
    const bloques = [
      {
        type: 'routes',
        lines: [{ kind: 'broken', name: 'quejas', source: '' }],
      },
    ];

    expect(porId(buildDiagram(bloques))['route:quejas'].broken).toBe(true);
  });

  it('el alto y el ancho alcanzan para todo', () => {
    const diagrama = buildDiagram(estructura());

    diagrama.nodes.forEach(n => {
      expect(n.x + n.w).toBeLessThanOrEqual(diagrama.width);
      expect(n.y + n.h).toBeLessThanOrEqual(diagrama.height);
    });
  });

  it('sin bloques no revienta', () => {
    expect(buildDiagram().nodes.map(n => n.id)).toEqual([
      'client',
      'conversational',
    ]);
  });
});

describe('describeSource', () => {
  it.each([
    ['@buscar_predefinidas(Gestión)', 'PREDEFINED', 'Gestión'],
    ['@buscar_predefinidas', 'PREDEFINED', ''],
    ['@buscar_articulo', 'ARTICLES', ''],
    ['@buscar_foro(Soporte)', 'FORUM', 'Soporte'],
    ['{{doc:Lista}}', 'DOC', 'Lista'],
    ['{{hoja: Grúas}}', 'SHEET', 'Grúas'],
    ['{{consulta:productos?}}', 'ERP', 'productos'],
    ['', 'NONE', ''],
    ['@algo_nuevo', 'OTHER', '@algo_nuevo'],
  ])('%s → %s', (fuente, kind, name) => {
    expect(describeSource(fuente)).toMatchObject({ kind, name });
  });
});

describe('describeAction', () => {
  it('reconoce caso, agenda y lo demás', () => {
    expect(
      describeAction({ action: '@crear_ticket', case_type: 'Queja' })
    ).toMatchObject({
      kind: 'TICKET',
      name: 'Queja',
    });
    expect(describeAction({ escalation: '@agendar_calendar' }).kind).toBe(
      'CALENDAR'
    );
    expect(describeAction({ escalation: '@humano' })).toMatchObject({
      kind: 'OTHER',
      name: '@humano',
    });
    expect(describeAction({ escalation: '' })).toBeNull();
  });
});

describe('truncate', () => {
  it('corta con puntos suspensivos sin pasarse del tope', () => {
    expect(truncate('abcdefghij', 5)).toBe('abcd…');
    expect(truncate('abc', 5)).toBe('abc');
    expect(truncate(null)).toBe('');
  });
});
