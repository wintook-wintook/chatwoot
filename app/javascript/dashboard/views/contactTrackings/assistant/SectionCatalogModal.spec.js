import { shallowMount } from '@vue/test-utils';
import SectionCatalogModal from './SectionCatalogModal.vue';

// proyecto@asistente_agentes_ia — docs/estructura_agente_arbol_plan.md
const secciones = () => [
  {
    title: 'ROL',
    body: 'Sos un asesor de licencias.',
    style: 'bracket',
    lines: 1,
    agents: ['Licencias'],
  },
  {
    title: 'ROL',
    body: 'Sos cercano y directo.',
    style: 'bracket',
    lines: 1,
    agents: ['Soporte v2'],
  },
  {
    title: 'ETIQUETAS',
    body: 'Cerrá cada turno con una sola etiqueta.',
    style: 'bracket',
    lines: 1,
    agents: ['Soporte v2'],
  },
];

const montar = (props = {}) =>
  shallowMount(SectionCatalogModal, {
    propsData: { show: true, sections: secciones(), ...props },
    mocks: {
      $t: (clave, args) => (args ? `${clave} ${JSON.stringify(args)}` : clave),
    },
    stubs: ['woot-button', 'woot-modal'],
  });

describe('SectionCatalogModal', () => {
  // El mismo nombre escrito distinto aparece dos veces: comparar eso es el punto.
  it('muestra las dos versiones del mismo nombre', () => {
    expect(montar().vm.filtered.filter(s => s.title === 'ROL')).toHaveLength(2);
  });

  it('busca por nombre, contenido y agente', () => {
    const wrapper = montar();

    wrapper.setData({ query: 'cercano' });
    expect(wrapper.vm.filtered.map(s => s.body)).toEqual([
      'Sos cercano y directo.',
    ]);

    wrapper.setData({ query: 'licencias' });
    expect(wrapper.vm.filtered.map(s => s.agents[0])).toEqual(['Licencias']);

    wrapper.setData({ query: 'etiquetas' });
    expect(wrapper.vm.filtered.map(s => s.title)).toEqual(['ETIQUETAS']);
  });

  it('entrega el nombre y el texto de la sección elegida', () => {
    const wrapper = montar();

    wrapper.vm.pick(secciones()[1]);

    expect(wrapper.emitted('pick')[0][0]).toEqual({
      title: 'ROL',
      body: 'Sos cercano y directo.',
    });
  });

  // Dos rótulos iguales confunden al agente: no sabe cuál de los dos aplica.
  it('no deja copiar una sección que el agente ya tiene, sin importar mayúsculas', () => {
    const wrapper = montar({ takenTitles: ['rol'] });

    expect(wrapper.vm.taken(secciones()[0])).toBe(true);
    expect(wrapper.vm.taken(secciones()[2])).toBe(false);
    wrapper.vm.pick(secciones()[0]);

    expect(wrapper.emitted('pick')).toBeUndefined();
  });

  it('al abrirse limpia la búsqueda anterior', async () => {
    const wrapper = montar({ show: false });

    wrapper.setData({ query: 'algo' });
    await wrapper.setProps({ show: true });

    expect(wrapper.vm.query).toBe('');
  });
});
