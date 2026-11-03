import { shallowMount } from '@vue/test-utils';
import LicenseStatusCard from '../LicenseStatusCard.vue';

// feat/licencias — la tarjeta de Configuración › Licencia y › General
const periodo = (name, extra = {}) => ({
  name,
  license_type: 'paid',
  max_agents: 5,
  starts_at: '2026-11-01T00:00:00Z',
  expires_at: '2026-12-01T00:00:00Z',
  days_left: 29,
  ...extra,
});
const montar = (license, propsData = {}) =>
  shallowMount(LicenseStatusCard, {
    propsData: { license, ...propsData },
    mocks: {
      $t: (clave, args) => (args ? `${clave} ${JSON.stringify(args)}` : clave),
      $i18n: { locale: 'es' },
    },
    stubs: ['woot-label', 'router-link'],
  });

describe('LicenseStatusCard', () => {
  it('muestra toda la fila, en orden y numerada', () => {
    const wrapper = montar({
      agents_count: 4,
      current: periodo('Profesional'),
      queue: [periodo('Semestral'), periodo('Anual', { max_agents: 9 })],
    });

    const filas = wrapper.findAll('li');
    expect(filas).toHaveLength(2);
    expect(filas.at(0).text()).toContain('Semestral');
    expect(filas.at(1).text()).toContain('Anual');
    expect(filas.at(1).text()).toContain('"count":9');
    expect(wrapper.vm.agentsPercent).toBe(80);
  });

  it('sin fila lo dice; las cuentas viejas con solo `next` también se ven', () => {
    expect(
      montar({ agents_count: 1, current: periodo('Pro'), queue: [] }).text()
    ).toContain('QUEUE_EMPTY');
    expect(
      montar({
        agents_count: 1,
        current: periodo('Pro'),
        next: periodo('Anual'),
      }).vm.queue
    ).toHaveLength(1);
  });

  it('el estado cambia de color a 10 días o menos y si venció', () => {
    expect(
      montar({ agents_count: 1, current: periodo('Pro', { days_left: 9 }) }).vm
        .stateScheme
    ).toBe('warning');
    expect(montar({ agents_count: 1, current: null }).vm.stateScheme).toBe(
      'alert'
    );
  });

  it('en General va compacta: con «Ver licencia» y sin el aviso de solo lectura', () => {
    const general = montar(
      { agents_count: 1, current: periodo('Pro') },
      { compact: true }
    );
    expect(general.find('router-link-stub').exists()).toBe(true);
    expect(general.text()).not.toContain('READ_ONLY');
    expect(
      montar({ agents_count: 1, current: periodo('Pro') }).text()
    ).toContain('READ_ONLY');
  });
});
