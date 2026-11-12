import { shallowMount } from '@vue/test-utils';
import MyDay from '../MyDay.vue';

// «Mi día» de otra persona (Administrador/Supervisor): solo se ve.
const rows = [
  { id: 1, title: 'Planeada', planned: true, reasons: [] },
  { id: 2, title: 'Sugerida', planned: false, reasons: [] },
];
const agenda = [
  {
    id: 5,
    title: 'Visita',
    status: 'scheduled',
    starts_at: '2026-11-12T16:00',
  },
  {
    id: 6,
    title: 'De caso cerrado',
    status: 'scheduled',
    starts_at: '2026-11-12T17:00',
    case_ticket: { id: 1, folio: 'OPB-1', status: 'closed' },
  },
];
const mount = props =>
  shallowMount(MyDay, {
    propsData: {
      rows,
      meta: { missed: [2], new_urgent: [2], agenda },
      ...props,
    },
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

  it('completa una cita de hoy (no la de un caso cerrado)', () => {
    const wrapper = mount();
    const buttons = wrapper.findAll('[data-test="my-day-complete-meeting"]');
    expect(buttons.length).toBe(1);
    expect(wrapper.vm.canCompleteMeeting(agenda[1])).toBe(false);
    wrapper.vm.$emit('completeMeeting', agenda[0]);
    expect(wrapper.emitted('completeMeeting')[0][0].id).toBe(5);
  });

  it('en el día de otra persona no completa citas', () => {
    const wrapper = mount({ viewingUser: { id: 9, name: 'Ana' } });
    expect(
      wrapper.findAll('[data-test="my-day-complete-meeting"]').length
    ).toBe(0);
  });
});
