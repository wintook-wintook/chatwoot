import axios from 'axios';
import store from '../../googleCalendar';

// fix/calendario_eliminar F3 — eliminar un evento de Google desde el calendario.
const { actions } = store;
global.axios = axios;
vi.mock('axios');

const events = [
  { id: 'suelto' },
  { id: 'base_1', recurringEventId: 'base' },
  { id: 'base_2', recurringEventId: 'base' },
];

describe('googleCalendar · deleteEvent', () => {
  beforeEach(() => vi.clearAllMocks());

  it('lo quita de la pantalla al momento y manda calendario, alcance y aviso', async () => {
    const commit = vi.fn();
    axios.delete.mockResolvedValue({ data: { deleted: true } });

    await actions.deleteEvent(
      { commit, state: { events } },
      { eventId: 'suelto', calendar_id: 'primary', scope: 'one', notify: true }
    );

    expect(commit).toHaveBeenCalledWith('SET_CALENDAR_EVENTS', events.slice(1));
    const [url, config] = axios.delete.mock.calls[0];
    expect(url).toMatch(/\/google_calendar\/events\/suelto$/);
    expect(config.params).toEqual({
      calendar_id: 'primary',
      scope: 'one',
      notify: true,
    });
  });

  it('«Toda la serie» quita todas sus fechas; «Solo este», solo esa', async () => {
    const commit = vi.fn();
    axios.delete.mockResolvedValue({});
    const ctx = { commit, state: { events } };

    await actions.deleteEvent(ctx, {
      eventId: 'base_1',
      scope: 'all',
      seriesId: 'base',
    });
    expect(commit).toHaveBeenLastCalledWith('SET_CALENDAR_EVENTS', [
      { id: 'suelto' },
    ]);

    await actions.deleteEvent(ctx, {
      eventId: 'base_1',
      scope: 'one',
      seriesId: 'base',
    });
    expect(commit).toHaveBeenLastCalledWith('SET_CALENDAR_EVENTS', [
      events[0],
      events[2],
    ]);
  });

  it('si Google falla, el evento regresa y el error sube con su motivo', async () => {
    const commit = vi.fn();
    const error = {
      response: { status: 409, data: { error: 'Es una tarea agendada' } },
    };
    axios.delete.mockRejectedValue(error);

    await expect(
      actions.deleteEvent({ commit, state: { events } }, { eventId: 'suelto' })
    ).rejects.toBe(error);
    expect(commit).toHaveBeenLastCalledWith('SET_CALENDAR_EVENTS', events);
  });
});
