import CreateEventModal from '../CreateEventModal.vue';

// fix/calendario_eliminar F3 — «Eliminar evento» / «Quitar de mi calendario».
const { methods, computed } = CreateEventModal;

const ctxFor = (props = {}, overrides = {}) => {
  const ctx = {
    editEvent: {
      id: 'ev1',
      extendedProps: { calendarId: 'primary', attendees: [], ...props },
    },
    calendars: [
      { id: 'ana@gmail.com', primary: true, access_role: 'owner' },
      { id: 'festivos', access_role: 'reader' },
    ],
    isGoogleEvent: true,
    agendaItem: null,
    deleteScope: 'one',
    deleteNotify: true,
    form: { summary: 'Junta' },
    $t: (key, vars) => (vars ? `${key}:${JSON.stringify(vars)}` : key),
    $store: { dispatch: vi.fn().mockResolvedValue() },
    $emit: vi.fn(),
    showAlert: vi.fn(),
    ...overrides,
  };
  ['eventCalendar', 'isOrganizer', 'seriesId', 'deleteGuests'].forEach(k => {
    ctx[k] = computed[k].call(ctx);
  });
  ctx.canDeleteEvent = computed.canDeleteEvent.call(ctx);
  ctx.deleteTexts = computed.deleteTexts.call(ctx);
  ctx.onClose = vi.fn();
  return ctx;
};

describe('CreateEventModal · Eliminar evento', () => {
  it('sale en mis eventos de Google sin tarea', () => {
    expect(ctxFor().canDeleteEvent).toBe(true);
  });

  it('no sale si es tarea agendada (se cancela), ni en calendarios de solo lectura', () => {
    expect(ctxFor({}, { agendaItem: { id: 7 } }).canDeleteEvent).toBe(false);
    expect(ctxFor({}, { isGoogleEvent: false }).canDeleteEvent).toBe(false);
    expect(ctxFor({ calendarId: 'festivos' }).canDeleteEvent).toBe(false);
  });

  it('si me invitaron dice «Quitar de mi calendario»', () => {
    expect(ctxFor().deleteTexts.button).toBe(
      'GOOGLE_CALENDAR.DELETE_EVENT.DELETE'
    );
    expect(ctxFor({ organizerSelf: false }).deleteTexts.button).toBe(
      'GOOGLE_CALENDAR.DELETE_EVENT.REMOVE'
    );
  });

  it('cuenta solo a los demás invitados (no a mí)', () => {
    const ctx = ctxFor({
      attendees: [{ email: 'yo', self: true }, { email: 'b' }, { email: 'c' }],
    });
    expect(ctx.deleteGuests).toBe(2);
  });

  it('organizador con invitados: avisa; recarga, avisa en pantalla y cierra', async () => {
    const ctx = ctxFor({ attendees: [{ email: 'b' }] });
    await methods.deleteEvent.call(ctx);

    expect(ctx.$store.dispatch).toHaveBeenCalledWith(
      'googleCalendar/deleteEvent',
      {
        eventId: 'ev1',
        calendar_id: 'primary',
        scope: 'one',
        notify: true,
        seriesId: null,
      }
    );
    expect(ctx.showAlert).toHaveBeenCalledWith(
      'GOOGLE_CALENDAR.DELETE_EVENT.DELETE_DONE'
    );
    expect(ctx.$emit).toHaveBeenCalledWith('created');
    expect(ctx.onClose).toHaveBeenCalled();
  });

  it('sin invitados, despalomeado o como invitado: no avisa', async () => {
    const cases = [
      ctxFor(),
      ctxFor({ attendees: [{ email: 'b' }] }, { deleteNotify: false }),
      ctxFor({ attendees: [{ email: 'b' }], organizerSelf: false }),
    ];
    await Promise.all(cases.map(ctx => methods.deleteEvent.call(ctx)));
    cases.forEach(ctx =>
      expect(ctx.$store.dispatch.mock.calls[0][1].notify).toBe(false)
    );
  });

  it('serie: manda el alcance elegido; suelto siempre «one»', async () => {
    const serie = ctxFor({ recurringEventId: 'base' }, { deleteScope: 'all' });
    await methods.deleteEvent.call(serie);
    expect(serie.$store.dispatch.mock.calls[0][1]).toMatchObject({
      scope: 'all',
      seriesId: 'base',
    });

    const suelto = ctxFor({}, { deleteScope: 'all' });
    await methods.deleteEvent.call(suelto);
    expect(suelto.$store.dispatch.mock.calls[0][1].scope).toBe('one');
  });

  it('si el servidor lo rechaza muestra su motivo y no cierra', async () => {
    const ctx = ctxFor();
    ctx.$store.dispatch.mockRejectedValue({
      response: { data: { error: 'Es una tarea agendada' } },
    });
    await methods.deleteEvent.call(ctx);

    expect(ctx.showAlert).toHaveBeenCalledWith('Es una tarea agendada');
    expect(ctx.onClose).not.toHaveBeenCalled();
    expect(ctx.deleteBusy).toBe(false);
  });
});
