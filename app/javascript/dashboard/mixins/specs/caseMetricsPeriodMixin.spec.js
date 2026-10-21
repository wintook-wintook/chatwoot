import { shallowMount } from '@vue/test-utils';
import caseMetricsPeriodMixin from '../caseMetricsPeriodMixin';

let fetch;
const build = () => {
  fetch = vi.fn();
  return shallowMount(
    {
      mixins: [caseMetricsPeriodMixin],
      render() {
        return null;
      },
      methods: {
        fetch() {
          fetch();
        },
      },
    },
    {}
  ).vm;
};

describe('caseMetricsPeriodMixin', () => {
  it('los períodos viejos (7/30/90 días, Todo) caen en «Este mes»', () => {
    const vm = build();
    vm.restorePeriod({ period: '90d' });
    expect(vm.period).toBe('this_month');
    vm.restorePeriod({ period: 'all' });
    expect(vm.period).toBe('this_month');
    vm.restorePeriod({ period: 'last_quarter' });
    expect(vm.period).toBe('last_quarter');
  });

  it('un personalizado roto cae en «Este mes»; uno válido se conserva', () => {
    const vm = build();
    vm.restorePeriod({ period: 'custom', customFrom: '2026-10-09' });
    expect(vm.period).toBe('this_month');
    vm.restorePeriod({
      period: 'custom',
      customFrom: '2026-10-01',
      customTo: '2026-10-09',
    });
    expect(vm.period).toBe('custom');
    expect(vm.periodState()).toEqual({
      period: 'custom',
      customFrom: '2026-10-01',
      customTo: '2026-10-09',
    });
  });

  it('elegir «Personalizado» arranca con este mes a la fecha y vuelve a pedir', () => {
    const vm = build();
    vm.setPeriod('custom');
    expect(vm.customFrom).toMatch(/^\d{4}-\d{2}-01$/);
    expect(vm.periodRangeOf()).not.toBeNull();
    expect(fetch).toHaveBeenCalled();
  });
});
