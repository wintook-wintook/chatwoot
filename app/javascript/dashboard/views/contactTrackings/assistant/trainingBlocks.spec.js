import {
  addRoute,
  moveSection,
  canMoveSection,
  moveRoute,
  canMoveRoute,
  setScopeLine,
  scopeTextFor,
  addSection,
  defaultRouteName,
  moveBlock,
  removeBlock,
  removeRoute,
  replaceRoute,
  routeNames,
  scopeTitleFrom,
  setDefaultRoute,
  withGaps,
  withScopeLine,
  withoutScopeLine,
} from './trainingBlocks';

// proyecto@asistente_agentes_ia — docs/estructura_agente_arbol_plan.md
const rama = (name, extra = {}) => ({ kind: 'route', name, ...extra });

const estructura = () => [
  {
    type: 'routes',
    text: '',
    gap: 1,
    lines: [
      rama('soporte'),
      rama('comercial'),
      { kind: 'default', name: 'soporte' },
    ],
  },
  { type: 'section', title: 'ROL', body: 'Sos amable.', gap: 1 },
  {
    type: 'section',
    title: 'ALCANCE POR RAMA',
    body: 'soporte: atiende fallas.\ncomercial: atiende precios.',
    gap: 0,
  },
];

describe('trainingBlocks', () => {
  describe('las ramas', () => {
    it('lista los nombres de las ramas, sin la rama por defecto', () => {
      expect(routeNames(estructura())).toEqual(['soporte', 'comercial']);
      expect(defaultRouteName(estructura())).toBe('soporte');
    });

    it('agrega la rama antes de la rama por defecto y su línea de alcance', () => {
      const blocks = addRoute(estructura(), rama('admin'), 'atiende facturas');

      expect(blocks[0].lines.map(l => l.name)).toEqual([
        'soporte',
        'comercial',
        'admin',
        'soporte',
      ]);
      expect(blocks[2].body).toBe(
        'soporte: atiende fallas.\ncomercial: atiende precios.\nadmin: atiende facturas'
      );
    });

    it('crea el bloque de ramas si es la primera', () => {
      const blocks = addRoute(
        [{ type: 'section', title: 'ROL', body: 'x', gap: 1 }],
        rama('soporte'),
        ''
      );

      expect(blocks.map(b => b.type)).toEqual(['routes', 'section']);
      expect(blocks[0].lines).toEqual([rama('soporte')]);
    });

    // El lugar de una rama se cuenta entre RAMAS, no entre líneas: el bloque también
    // lleva la rama por defecto y lo que el parser no reconoce.
    it('reemplaza la rama que está en ese lugar entre las ramas', () => {
      const blocks = replaceRoute(estructura(), 1, { name: 'ventas' });

      expect(blocks[0].lines.map(l => `${l.kind}:${l.name}`)).toEqual([
        'route:soporte',
        'route:ventas',
        'default:soporte',
      ]);
    });

    it('quita la rama y su línea de alcance', () => {
      const blocks = removeRoute(estructura(), 0);

      expect(routeNames(blocks)).toEqual(['comercial']);
      expect(blocks[2].body).toBe('comercial: atiende precios.');
    });

    it('puede quitar la rama dejando su línea de alcance', () => {
      const blocks = removeRoute(estructura(), 0, { withScope: false });

      expect(blocks[2].body).toContain('soporte: atiende fallas.');
    });

    // El orden de las ramas es el orden en que se leen las líneas @ruta.
    it('cambia una rama de lugar con su rama vecina', () => {
      const blocks = moveRoute(estructura(), 0, 1);

      expect(blocks[0].lines.map(l => `${l.kind}:${l.name}`)).toEqual([
        'route:comercial',
        'route:soporte',
        'default:soporte',
      ]);
    });

    // La línea de la rama por defecto se queda donde está: no es una rama.
    it('no mueve una rama más allá de la última', () => {
      const blocks = estructura();

      expect(moveRoute(blocks, 1, 1)).toBe(blocks);
      expect(canMoveRoute(blocks, 1, 1)).toBe(false);
      expect(canMoveRoute(blocks, 1, -1)).toBe(true);
      expect(canMoveRoute(blocks, 0, -1)).toBe(false);
    });

    it('cambia y quita la rama por defecto', () => {
      expect(defaultRouteName(setDefaultRoute(estructura(), 'comercial'))).toBe(
        'comercial'
      );
      expect(defaultRouteName(setDefaultRoute(estructura(), ''))).toBe('');
    });

    it('agrega la línea @ruta_por_defecto si no estaba', () => {
      const sinDefecto = [
        { type: 'routes', text: '', gap: 1, lines: [rama('soporte')] },
      ];

      expect(defaultRouteName(setDefaultRoute(sinDefecto, 'soporte'))).toBe(
        'soporte'
      );
    });
  });

  describe('el alcance por rama', () => {
    it('crea la sección después de la primera si no existe', () => {
      const blocks = withScopeLine(
        [
          { type: 'routes', text: '', gap: 1, lines: [] },
          { type: 'section', title: 'ROL', body: 'x', gap: 1 },
          { type: 'section', title: 'ESTILO', body: 'y', gap: 0 },
        ],
        'soporte',
        'atiende fallas'
      );

      expect(blocks.map(b => b.title)).toEqual([
        undefined,
        'ROL',
        'ALCANCE POR RAMA',
        'ESTILO',
      ]);
      expect(blocks[2].body).toBe('soporte: atiende fallas');
    });

    it('usa el nombre que la cuenta ya le da a la sección', () => {
      expect(scopeTitleFrom(['ROL', 'ALCANCE POR TEMA'])).toBe(
        'ALCANCE POR TEMA'
      );
      expect(scopeTitleFrom(['ROL'])).toBe('ALCANCE POR RAMA');
    });

    it('no toca nada si no se escribió el alcance', () => {
      const blocks = estructura();

      expect(withScopeLine(blocks, 'admin', '')).toBe(blocks);
    });

    it('lee la línea de alcance de una rama, sin el nombre', () => {
      expect(scopeTextFor(estructura(), 'comercial')).toBe('atiende precios.');
      expect(scopeTextFor(estructura(), 'admin')).toBe('');
    });

    it('reescribe la línea de alcance al editarla', () => {
      const blocks = setScopeLine(estructura(), {
        previousName: 'soporte',
        name: 'soporte',
        scope: 'atiende fallas y errores',
      });

      expect(blocks[2].body).toBe(
        'comercial: atiende precios.\nsoporte: atiende fallas y errores'
      );
    });

    // Renombrar la rama tiene que renombrar su línea, no dejar dos.
    it('al renombrar la rama, se lleva su línea de alcance', () => {
      const blocks = setScopeLine(estructura(), {
        previousName: 'soporte',
        name: 'soporte_nuevo',
        scope: 'atiende fallas',
      });

      expect(blocks[2].body).toBe(
        'comercial: atiende precios.\nsoporte_nuevo: atiende fallas'
      );
    });

    it('sin texto, la rama queda sin línea de alcance', () => {
      const blocks = setScopeLine(estructura(), {
        previousName: 'soporte',
        name: 'soporte',
        scope: '',
      });

      expect(blocks[2].body).toBe('comercial: atiende precios.');
    });

    it('no confunde una rama con otra que empieza igual', () => {
      const blocks = withoutScopeLine(
        [
          {
            type: 'section',
            title: 'ALCANCE POR RAMA',
            body: 'soporte: fallas.\nsoporte_tecnico: visitas.',
            gap: 0,
          },
        ],
        'soporte'
      );

      expect(blocks[0].body).toBe('soporte_tecnico: visitas.');
    });
  });

  describe('las secciones', () => {
    it('agrega la sección al final, limpiando el nombre', () => {
      const blocks = addSection(estructura(), ' [nuevo] ');

      expect(blocks[blocks.length - 1]).toMatchObject({
        type: 'section',
        title: 'nuevo',
        body: '',
      });
    });

    it('no agrega una sección sin nombre', () => {
      const blocks = estructura();

      expect(addSection(blocks, '  ')).toBe(blocks);
    });

    it('mueve un bloque y deja los renglones en blanco donde van', () => {
      const blocks = moveBlock(estructura(), 1, 1);

      expect(blocks.map(b => b.title)).toEqual([
        undefined,
        'ALCANCE POR RAMA',
        'ROL',
      ]);
      // El que dejó de ser el último gana su renglón en blanco (venía en 0), para
      // no quedar pegado al siguiente. El que quedó último conserva el suyo: los
      // renglones del final son parte del texto original y no se tocan.
      expect(blocks[1].gap).toBe(1);
      expect(blocks[2].gap).toBe(1);
    });

    // El orden importa: el modelo lee las secciones en el orden en que están.
    describe('mover una sección', () => {
      const conTexto = () => [
        { type: 'preamble', text: 'AGENTE v1', gap: 1 },
        { type: 'routes', text: '', gap: 1, lines: [] },
        { type: 'section', title: 'ROL', body: 'a', gap: 1 },
        { type: 'section', title: 'ESTILO', body: 'b', gap: 1 },
        { type: 'section', title: 'PROHIBIDO', body: 'c', gap: 0 },
      ];

      it('cambia el orden con la sección vecina', () => {
        expect(moveSection(conTexto(), 3, 1).map(b => b.title)).toEqual([
          undefined,
          undefined,
          'ROL',
          'PROHIBIDO',
          'ESTILO',
        ]);
      });

      // El bloque de ramas no se cruza: la primera sección ya es la primera.
      it('no cruza el bloque de ramas ni el texto inicial', () => {
        const blocks = conTexto();

        expect(moveSection(blocks, 2, -1)).toBe(blocks);
        expect(canMoveSection(blocks, 2, -1)).toBe(false);
        expect(canMoveSection(blocks, 2, 1)).toBe(true);
      });

      it('la última sección no baja más', () => {
        const blocks = conTexto();

        expect(moveSection(blocks, 4, 1)).toBe(blocks);
        expect(canMoveSection(blocks, 4, 1)).toBe(false);
      });

      // El texto inicial no lleva rótulo: siempre va primero.
      it('el texto inicial no se mueve', () => {
        const blocks = conTexto();

        expect(moveSection(blocks, 0, 1)).toBe(blocks);
      });
    });

    it('no mueve más allá de los extremos', () => {
      const blocks = estructura();

      expect(moveBlock(blocks, 0, -1)).toBe(blocks);
      expect(moveBlock(blocks, 2, 1)).toBe(blocks);
    });

    it('quita un bloque', () => {
      expect(removeBlock(estructura(), 1).map(b => b.title)).toEqual([
        undefined,
        'ALCANCE POR RAMA',
      ]);
    });
  });

  it('el último bloque no cuelga un renglón en blanco', () => {
    const blocks = withGaps([
      { type: 'section', title: 'A', body: 'x', gap: 0 },
      { type: 'section', title: 'B', body: 'y', gap: 3 },
    ]);

    expect(blocks.map(b => b.gap)).toEqual([1, 3]);
  });
});
