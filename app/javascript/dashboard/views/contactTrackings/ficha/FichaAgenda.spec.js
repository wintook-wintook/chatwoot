import { shallowMount } from '@vue/test-utils';
import FichaAgenda from './FichaAgenda.vue';
import TrackingTemplatesAPI from 'dashboard/api/trackingTemplates';

vi.mock('dashboard/api/trackingTemplates', () => ({
  default: { getCalendarIntegrations: vi.fn() },
}));

const esperar = () =>
  new Promise(resolve => {
    setTimeout(resolve);
  });

describe('FichaAgenda', () => {
  beforeEach(() => {
    TrackingTemplatesAPI.getCalendarIntegrations.mockResolvedValue({
      data: [
        {
          id: 3,
          user_name: 'Ana',
          google_email: 'ana@x.com',
          calendars: [
            { id: 'primary', summary: 'Ana', primary: true },
            { id: 'citas@group', summary: 'Citas' },
          ],
        },
        { id: 9, user_name: 'Luis', google_email: 'luis@x.com', calendars: [] },
      ],
    });
  });

  const montar = (value = {}) =>
    shallowMount(FichaAgenda, {
      propsData: { value, integrationIds: [3] },
      mocks: { $t: (clave, args) => (args ? `${clave}:${args.count}` : clave) },
    });

  it('muestra solo las agendas marcadas y elige en qué calendario aparta', async () => {
    const wrapper = montar({ booking_calendar_ids: {} });
    await esperar();
    expect(wrapper.vm.selected.map(i => i.id)).toEqual([3]);
    wrapper.vm.toggleCalendar(wrapper.vm.selected[0], { id: 'citas@group' });
    expect(wrapper.emitted('input')[0][0]).toEqual({
      booking_calendar_ids: { 3: ['citas@group'] },
    });
  });

  it('duración, zona y presentación con valores por omisión', async () => {
    const wrapper = montar();
    await esperar();
    expect(wrapper.vm.duration).toBe(30);
    expect(wrapper.vm.presentation).toBe('detailed');
    expect(wrapper.vm.durationLabel(120)).toBe(
      'TRACKING_TEMPLATES.FICHA.HOURS:2'
    );
    wrapper.vm.set('calendar_event_duration', 60);
    expect(wrapper.emitted('input')[0][0]).toEqual({
      calendar_event_duration: 60,
    });
  });
});
