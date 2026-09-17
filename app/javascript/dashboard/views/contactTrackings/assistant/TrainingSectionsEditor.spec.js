import { shallowMount } from '@vue/test-utils';
import TrainingSectionsEditor from './TrainingSectionsEditor.vue';

// proyecto@asistente_agentes_ia — docs/formulario_entrenamiento_plan.md
const estructura = () => ({
  version: 1,
  blocks: [
    {
      type: 'routes',
      text: '@ruta(a #aaa: x): -',
      gap: 1,
      lines: [{ kind: 'route', name: 'a', tag: 'aaa', description: 'x' }],
    },
    {
      type: 'section',
      title: 'ROL',
      style: 'bracket',
      header: '[ROL]',
      body: 'Sos amable.',
      gap: 1,
    },
    {
      type: 'section',
      title: 'PERSONALIDAD',
      style: 'markdown2',
      header: '## PERSONALIDAD ##',
      body: '* cercano',
      gap: 0,
    },
  ],
});

const montar = (value = estructura(), titles = {}) =>
  shallowMount(TrainingSectionsEditor, {
    propsData: {
      value,
      titles: { suggested: [], from_account: [], ...titles },
    },
    mocks: {
      $t: (key, args) => (args ? `${key} ${JSON.stringify(args)}` : key),
    },
    stubs: ['woot-button', 'fluent-icon'],
  });

const ultimo = wrapper => {
  const eventos = wrapper.emitted('input');
  return eventos[eventos.length - 1][0].blocks;
};

describe('TrainingSectionsEditor', () => {
  // Guardar sin tocar nada no cambia el prompt: los bloques que no se editan
  // conservan su rótulo original y sus renglones en blanco.
  it('al editar una sección no toca el rótulo ni los espacios de las demás', () => {
    const wrapper = montar();

    wrapper.vm.update(1, { body: 'Sos el asistente del consultorio.' });

    const bloques = ultimo(wrapper);
    expect(bloques[1].body).toBe('Sos el asistente del consultorio.');
    expect(bloques[2]).toMatchObject({ header: '## PERSONALIDAD ##', gap: 0 });
  });

  it('agrega una sección al final, sin rótulo original y separada', () => {
    const wrapper = montar();

    wrapper.vm.addSection('NO SIMULAR');

    const bloques = ultimo(wrapper);
    expect(bloques[3]).toMatchObject({
      type: 'section',
      title: 'NO SIMULAR',
      body: '',
    });
    expect(bloques[3].header).toBeUndefined();
    // La que era última ya no puede quedar pegada a la nueva.
    expect(bloques[2].gap).toBe(1);
  });

  it('limpia corchetes y saltos de línea del nombre, y no agrega un nombre vacío', () => {
    const wrapper = montar();

    wrapper.vm.addSection('  ');
    expect(wrapper.emitted('input')).toBeFalsy();

    wrapper.vm.addSection('RE[GLA]\nX');
    expect(ultimo(wrapper)[3].title).toBe('RE GLA  X');
  });

  it('reordena y el que queda último no arrastra un renglón en blanco extra', () => {
    const wrapper = montar();

    wrapper.vm.move(2, -1);

    const bloques = ultimo(wrapper);
    expect(bloques.map(b => b.title || b.type)).toEqual([
      'routes',
      'PERSONALIDAD',
      'ROL',
    ]);
    expect(bloques[1].gap).toBe(1);
  });

  // Borrar una sección con texto pide confirmar con un segundo clic.
  it('pide confirmar antes de borrar una sección con texto', () => {
    const wrapper = montar();

    wrapper.vm.remove(1);
    expect(wrapper.emitted('input')).toBeFalsy();

    wrapper.vm.remove(1);
    expect(ultimo(wrapper).map(b => b.title || b.type)).toEqual([
      'routes',
      'PERSONALIDAD',
    ]);
  });

  it('inserta una directiva donde estaba el cursor', () => {
    const wrapper = montar();
    const uid = wrapper.vm.blocks[1].uid;
    wrapper.vm.rememberCursor(uid, {
      target: { selectionStart: 3, selectionEnd: 3 },
    });

    expect(wrapper.vm.insertToken('@discourse')).toBe(true);

    expect(ultimo(wrapper)[1].body).toBe('Sos @discourse amable.');
  });

  it('sin cursor, inserta al final de la última sección', () => {
    const wrapper = montar();

    wrapper.vm.insertToken('{{catalogo}}');

    expect(ultimo(wrapper)[2].body).toBe('* cercano {{catalogo}} ');
  });

  it('no sugiere secciones que ya existen', () => {
    const wrapper = montar(estructura(), {
      suggested: ['ROL', 'ESTILO'],
      from_account: ['personalidad', 'SOPORTE'],
    });

    expect(wrapper.vm.suggestions).toEqual({
      suggested: ['ESTILO'],
      fromAccount: ['SOPORTE'],
    });
  });

  // Medido: hasta 31 secciones en un agente.
  it('con muchas secciones las abre plegadas', () => {
    const muchas = {
      blocks: Array.from({ length: 9 }, (_, i) => ({
        type: 'section',
        title: `S${i}`,
        body: 'x',
        gap: 1,
      })),
    };
    const wrapper = montar(muchas);

    expect(Object.values(wrapper.vm.collapsed).every(Boolean)).toBe(true);
    expect(Object.values(montar().vm.collapsed).some(Boolean)).toBe(false);
  });

  // Una rama son DOS cosas: su línea @ruta y su línea en [ALCANCE POR RAMA]. El
  // modal las manda juntas y acá se guardan juntas.
  describe('agregar una rama desde el modal', () => {
    const rama = {
      kind: 'route',
      name: 'comercial',
      description: 'cuanto cuesta',
    };

    it('mete la rama en el bloque de ramas y su línea en el alcance', () => {
      const wrapper = montar({
        blocks: [
          {
            type: 'routes',
            text: '@ruta(a #aaa: x): -',
            gap: 1,
            lines: [{ kind: 'route', name: 'a' }],
          },
          { type: 'section', title: 'ROL', body: 'Sos amable.', gap: 1 },
          {
            type: 'section',
            title: 'ALCANCE POR RAMA',
            body: 'a: atiende lo de siempre.',
            gap: 1,
          },
        ],
      });

      wrapper.vm.addRouteFromModal({ route: rama, scope: 'responde precios' });

      const blocks = ultimo(wrapper);
      expect(blocks[0].lines.map(l => l.name)).toEqual(['a', 'comercial']);
      expect(blocks[2].body).toBe(
        'a: atiende lo de siempre.\ncomercial: responde precios'
      );
    });

    it('crea el bloque de ramas y la sección de alcance si no estaban', () => {
      const wrapper = montar({
        blocks: [
          { type: 'section', title: 'ROL', body: 'Sos amable.', gap: 1 },
        ],
      });

      wrapper.vm.addRouteFromModal({ route: rama, scope: 'responde precios' });

      const blocks = ultimo(wrapper);
      expect(blocks.map(b => b.type)).toEqual(['routes', 'section', 'section']);
      expect(blocks[0].lines).toEqual([rama]);
      // Después de ROL, que es el orden del contrato.
      expect(blocks[2]).toMatchObject({
        title: 'ALCANCE POR RAMA',
        body: 'comercial: responde precios',
      });
    });

    it('deja la rama antes de la rama por defecto', () => {
      const wrapper = montar({
        blocks: [
          {
            type: 'routes',
            text: '',
            gap: 1,
            lines: [
              { kind: 'route', name: 'a' },
              { kind: 'default', name: 'a' },
            ],
          },
        ],
      });

      wrapper.vm.addRouteFromModal({ route: rama, scope: '' });

      expect(ultimo(wrapper)[0].lines.map(l => l.kind)).toEqual([
        'route',
        'route',
        'default',
      ]);
    });

    it('sin alcance escrito no toca ninguna sección', () => {
      const wrapper = montar();

      wrapper.vm.addRouteFromModal({ route: rama, scope: '' });

      expect(ultimo(wrapper).filter(b => b.type === 'section').length).toBe(
        montar().vm.sectionCount
      );
    });

    it('los nombres en uso son los que el modal no deja repetir', () => {
      expect(montar().vm.routeNames).toEqual(['a']);
    });
  });

  // F4: explicar manda la sección con su rótulo; sin permiso, no se ofrece.
  it('explica una sección mandando su rótulo y su cuerpo', () => {
    const wrapper = montar();

    wrapper.vm.explain(wrapper.vm.blocks[2]);

    expect(wrapper.emitted('explain')[0][0]).toBe(
      '## PERSONALIDAD ##\n* cercano'
    );
  });

  it('con la sección vacía manda solo el rótulo', () => {
    const wrapper = montar({
      blocks: [{ type: 'section', title: 'ROL', body: '' }],
    });

    wrapper.vm.explain(wrapper.vm.blocks[0]);

    expect(wrapper.emitted('explain')[0][0]).toBe('[ROL]');
  });
});
