import { shallowMount } from '@vue/test-utils';
import LicenseExpiringBanner from './LicenseExpiringBanner.vue';

// feat/licencias (F5)
let isAdmin = true;
vi.mock('dashboard/composables/useAdmin', () => ({
  useAdmin: () => ({ isAdmin }),
}));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountId: 2 }),
}));

const montar = license =>
  shallowMount(LicenseExpiringBanner, {
    mocks: {
      $t: (clave, args) => (args ? `${clave} ${JSON.stringify(args)}` : clave),
      $store: { getters: { 'accounts/getAccount': () => ({ license }) } },
    },
    computed: {
      getAccount: () => () => ({ license }),
    },
    stubs: ['Banner'],
  });

const licencia = (days, next = null) => ({
  current: { days_left: days, max_agents: 5 },
  next,
});

describe('LicenseExpiringBanner', () => {
  beforeEach(() => {
    isAdmin = true;
    window.localStorage.clear();
  });

  it('aparece con 10 días o menos', () => {
    expect(montar(licencia(10)).vm.shouldShowBanner).toBe(true);
    expect(montar(licencia(11)).vm.shouldShowBanner).toBe(false);
  });

  it('no aparece con periodo en cola, sin licencia ni para quien no es administrador', () => {
    expect(montar(licencia(3, { name: 'Pro' })).vm.shouldShowBanner).toBe(
      false
    );
    expect(montar(null).vm.shouldShowBanner).toBe(false);
    isAdmin = false;
    expect(montar(licencia(3)).vm.shouldShowBanner).toBe(false);
  });

  it('al cerrarlo no vuelve el mismo día', () => {
    const wrapper = montar(licencia(3));
    wrapper.vm.dismiss();

    expect(wrapper.vm.shouldShowBanner).toBe(false);
    expect(montar(licencia(3)).vm.shouldShowBanner).toBe(false);
  });
});
