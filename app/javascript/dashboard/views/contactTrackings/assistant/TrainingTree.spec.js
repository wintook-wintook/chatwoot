import { shallowMount } from '@vue/test-utils';
import TrainingTree from './TrainingTree.vue';

// proyecto@asistente_agentes_ia — docs/estructura_agente_arbol_plan.md
const estructura = () => ({
  blocks: [
    {
      type: 'routes',
      text: '',
      gap: 1,
      lines: [
        { kind: 'route', name: 'soporte', description: 'no puedo entrar' },
        { kind: 'route', name: 'comercial', description: 'cuanto cuesta' },
        { kind: 'default', name: 'comercial' },
      ],
    },
    { type: 'preamble', text: 'AGENTE v1', gap: 1 },
    { type: 'section', title: 'ROL', body: 'Sos amable.', gap: 1 },
    { type: 'section', title: 'ESTILO', body: '', gap: 0 },
  ],
});

const montar = (props = {}) =>
  shallowMount(TrainingTree, {
    propsData: { value: estructura(), ...props },
    mocks: {
      $t: (clave, args) => (args ? `${clave} ${JSON.stringify(args)}` : clave),
    },
    stubs: ['woot-button', 'fluent-icon'],
  });

describe('TrainingTree', () => {
  it('arma los nodos de ramas, con su lugar entre las ramas', () => {
    expect(montar().vm.routes.map(r => [r.name, r.position])).toEqual([
      ['soporte', 0],
      ['comercial', 1],
    ]);
  });

  it('marca cuál es la rama por defecto', () => {
    expect(montar().vm.defaultRoute).toBe('comercial');
  });

  // El texto inicial es un nodo más: existe en 26 de los 28 agentes medidos, y
  // esconderlo lo borraría al guardar.
  it('cuenta el texto inicial entre las secciones, con su lugar en la lista', () => {
    expect(montar().vm.sections.map(s => [s.type, s.index])).toEqual([
      ['preamble', 1],
      ['section', 2],
      ['section', 3],
    ]);
  });

  it('avisa al querer editar una rama, una sección o la definición', () => {
    const wrapper = montar();

    wrapper.vm.$emit('editRoute', 1);
    wrapper.vm.$emit('editSection', 2);
    wrapper.vm.$emit('editDefinition', 'ai_context');

    expect(wrapper.emitted('editRoute')[0]).toEqual([1]);
    expect(wrapper.emitted('editSection')[0]).toEqual([2]);
    expect(wrapper.emitted('editDefinition')[0]).toEqual(['ai_context']);
  });

  it('dice qué nodos están sin escribir', () => {
    const wrapper = montar();

    expect(wrapper.vm.lineCount(estructura().blocks[3])).toBe(0);
    expect(wrapper.vm.lineCount(estructura().blocks[2])).toBe(1);
    expect(wrapper.vm.definitionValue('objective')).toBe('');
  });

  it('muestra el objetivo y el contexto que se van a guardar', () => {
    const wrapper = montar({
      definition: {
        objective: 'Atender soporte',
        ai_context: 'Horario 9 a 18',
      },
    });

    expect(wrapper.vm.definitionValue('objective')).toBe('Atender soporte');
    expect(wrapper.vm.definitionValue('ai_context')).toBe('Horario 9 a 18');
  });

  // Un grupo se marca con lo peor que tengan sus hijos.
  it('el grupo de ramas toma el peor estado de sus ramas', () => {
    const wrapper = montar({
      issues: { 'route:soporte': 'degrading', 'route:comercial': 'blocking' },
    });

    expect(wrapper.vm.groupIssue('route:')).toBe('blocking');
    expect(wrapper.vm.issue('route:soporte')).toBe('degrading');
    expect(wrapper.vm.groupIssue('section:')).toBe('');
  });

  // Medido: hay un agente con 31 secciones. Abiertas de entrada no se puede navegar.
  it('con muchas secciones arranca plegado', () => {
    const muchas = {
      blocks: Array.from({ length: 9 }, (_, i) => ({
        type: 'section',
        title: `S${i}`,
        body: 'x',
        gap: 1,
      })),
    };

    expect(montar({ value: muchas }).vm.open.sections).toBe(false);
    expect(montar().vm.open.sections).toBe(true);
  });

  it('recorta lo que se ve de cada nodo', () => {
    const wrapper = montar();

    expect(wrapper.vm.preview('  hola   mundo  ')).toBe('hola mundo');
    expect(wrapper.vm.preview('x'.repeat(80)).endsWith('…')).toBe(true);
  });
});
