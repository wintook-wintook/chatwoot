import { shallowMount } from '@vue/test-utils';
import RouteCatalogModal from './RouteCatalogModal.vue';

// proyecto@asistente_agentes_ia — docs/estructura_agente_arbol_plan.md
const ramas = () => [
  {
    name: 'comercial',
    tag: 'demo',
    description: 'cuanto cuesta, precios',
    source: '{{hoja:Precios}}',
    escalation: '@crear_ticket(tipo=Comercial)',
    action: '@crear_ticket',
    case_type: 'Comercial',
    priority: '',
    scope: 'responde precios con la lista vigente.',
    agents: ['Licencias', 'Ventas'],
  },
  {
    name: 'soporte',
    tag: 'tracking',
    description: 'no puedo entrar, me da error',
    source: '@buscar_articulo',
    escalation: '',
    action: '',
    case_type: '',
    priority: '',
    scope: '',
    agents: ['Soporte v2'],
  },
];

const montar = (props = {}) =>
  shallowMount(RouteCatalogModal, {
    propsData: { show: true, routes: ramas(), ...props },
    mocks: { $t: clave => clave },
    stubs: ['woot-button', 'woot-modal'],
  });

describe('RouteCatalogModal', () => {
  it('busca por nombre, frases, fuente y agente', () => {
    const wrapper = montar();

    wrapper.setData({ query: 'precios' });
    expect(wrapper.vm.filtered.map(r => r.name)).toEqual(['comercial']);

    wrapper.setData({ query: '@buscar_articulo' });
    expect(wrapper.vm.filtered.map(r => r.name)).toEqual(['soporte']);

    wrapper.setData({ query: 'Soporte v2' });
    expect(wrapper.vm.filtered.map(r => r.name)).toEqual(['soporte']);

    wrapper.setData({ query: 'no existe' });
    expect(wrapper.vm.filtered).toEqual([]);
  });

  // Al copiarla van las dos mitades: la rama y su línea de alcance.
  it('entrega la rama y su alcance, sin los datos del catálogo', () => {
    const wrapper = montar();

    wrapper.vm.pick(ramas()[0]);

    expect(wrapper.emitted('pick')[0][0]).toEqual({
      route: {
        kind: 'route',
        name: 'comercial',
        tag: 'demo',
        description: 'cuanto cuesta, precios',
        source: '{{hoja:Precios}}',
        escalation: '@crear_ticket(tipo=Comercial)',
        action: '@crear_ticket',
        case_type: 'Comercial',
        priority: '',
      },
      scope: 'responde precios con la lista vigente.',
    });
  });

  // Dos ramas con el mismo nombre no existen para el motor: se queda con la primera,
  // así que la que el agente ya tiene no se lista.
  it('no lista una rama cuyo nombre el agente ya tiene', () => {
    const wrapper = montar({ takenNames: ['comercial'] });

    expect(wrapper.vm.filtered.map(r => r.name)).toEqual(['soporte']);
    wrapper.vm.pick(ramas()[0]);
    expect(wrapper.emitted('pick')).toBeUndefined();
  });

  it('dice por qué la lista quedó vacía', () => {
    expect(montar({ routes: [] }).vm.emptyMessage).toContain(
      'ROUTE_FIND_EMPTY'
    );
    expect(
      montar({ takenNames: ['comercial', 'soporte'] }).vm.emptyMessage
    ).toContain('ROUTE_FIND_ALL_TAKEN');

    const wrapper = montar();
    wrapper.setData({ query: 'no existe' });
    expect(wrapper.vm.emptyMessage).toContain('ROUTE_FIND_NO_MATCH');
  });

  it('al abrirse limpia la búsqueda anterior', async () => {
    const wrapper = montar({ show: false });

    wrapper.setData({ query: 'algo' });
    await wrapper.setProps({ show: true });

    expect(wrapper.vm.query).toBe('');
  });
});
