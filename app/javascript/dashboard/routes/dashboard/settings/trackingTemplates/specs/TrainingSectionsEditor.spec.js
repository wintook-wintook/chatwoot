import { shallowMount } from '@vue/test-utils';
import TrainingSectionsEditor from '../TrainingSectionsEditor.vue';

// proyecto@asistente_agentes_ia — docs/formulario_entrenamiento_plan.md
const estructura = () => ({
  version: 1,
  blocks: [
    { type: 'routes', text: '@ruta(a #aaa: x): -', gap: 1 },
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

  it('ofrece agregar ramas solo si no hay un bloque de ramas', () => {
    const sinRamas = { blocks: estructura().blocks.slice(1) };
    const wrapper = montar(sinRamas);

    wrapper.vm.addRoutes();

    expect(ultimo(wrapper)[0]).toMatchObject({ type: 'routes', text: '' });
    expect(montar().vm.hasRoutes).toBe(true);
  });
});
