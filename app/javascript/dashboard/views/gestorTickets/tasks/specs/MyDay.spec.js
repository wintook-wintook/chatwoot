import { shallowMount } from '@vue/test-utils';
import MyDay from '../MyDay.vue';

// «Mi día» de otra persona (Administrador/Supervisor): solo se ve.
const rows = [
  { id: 1, title: 'Planeada', planned: true, reasons: [] },
  { id: 2, title: 'Sugerida', planned: false, reasons: [] },
];
const mount = props =>
  shallowMount(MyDay, {
    propsData: { rows, meta: { missed: [2], new_urgent: [2] }, ...props },
    mocks: {
      $t: (key, args) => (args ? `${key}:${JSON.stringify(args)}` : key),
      $emitter: { on: vi.fn(), off: vi.fn() },
      $store: { getters: { getCurrentUserID: 7 } },
    },
    stubs: { FluentIcon: true, WootButton: true },
  });

describe('MyDay', () => {
  it('lo mío: avisos, orden propio y lo hecho hoy por mí', () => {
    const wrapper = mount();
    expect(wrapper.find('[data-test="my-day-viewing"]').exists()).toBe(false);
    expect(wrapper.findComponent({ name: 'MyDayNotices' }).exists()).toBe(true);
    expect(wrapper.vm.missedRows.length).toBe(1);
    expect(wrapper.vm.doneTodayFilters.user_id).toBe(7);
  });

  it('el de otra persona: solo ver, sin avisos ni planear', () => {
    const wrapper = mount({ viewingUser: { id: 9, name: 'Ana' } });
    expect(wrapper.find('[data-test="my-day-viewing"]').text()).toContain(
      'Ana'
    );
    expect(wrapper.findComponent({ name: 'MyDayNotices' }).exists()).toBe(
      false
    );
    expect(wrapper.vm.missedRows).toEqual([]);
    expect(wrapper.vm.urgentRow).toBeNull();
    expect(wrapper.vm.doneTodayFilters.user_id).toBe(9);
    wrapper
      .findAllComponents({ name: 'MyDayTaskRow' })
      .wrappers.forEach(row => expect(row.props('readonly')).toBe(true));
  });
});
