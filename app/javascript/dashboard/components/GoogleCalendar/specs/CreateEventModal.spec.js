import CreateEventModal from '../CreateEventModal.vue';

// Plan-Agenda — el formulario del calendario: qué guarda en cada caso.
const { methods, computed } = CreateEventModal;

const context = (overrides = {}) => ({
  ...methods,
  ...overrides.methods,
  form: {
    type: 'event',
    summary: 'Visita',
    description: '',
    calendar_id: 'primary',
    start_time: '2026-11-10T10:00',
    end_time: '2026-11-10T11:00',
    due_date: '2026-11-10',
    ...overrides.form,
  },
  attendees: [],
  attendeeInputValue: '',
  address: '',
  isVisit: false,
  contact: null,
  caseId: '',
  needsClient: true,
  isAgenda: true,
  agendaItem: null,
  isEditing: false,
  isGoogleEvent: false,
  editEvent: null,
  showAlert: vi.fn(),
  $t: key => key,
  $emit: vi.fn(),
  $store: { dispatch: vi.fn().mockResolvedValue() },
  ...overrides.data,
});

describe('CreateEventModal (agenda)', () => {
  it('no guarda sin contacto ni caso', async () => {
    const ctx = context();
    await methods.submit.call(ctx);

    expect(ctx.$store.dispatch).not.toHaveBeenCalled();
    expect(ctx.showAlert).toHaveBeenCalledWith(
      'GOOGLE_CALENDAR.AGENDA_LINK.CLIENT_REQUIRED'
    );
  });

  it('sin título no guarda y lo dice', async () => {
    const ctx = context({
      data: { contact: { id: 7 } },
      form: { summary: '  ' },
    });
    await methods.submit.call(ctx);

    expect(ctx.$store.dispatch).not.toHaveBeenCalled();
    expect(ctx.showAlert).toHaveBeenCalledWith(
      'GOOGLE_CALENDAR.AGENDA_LINK.TITLE_REQUIRED'
    );
  });

  it('si el servidor rechaza, muestra su motivo', async () => {
    const ctx = context({ data: { contact: { id: 7 } } });
    ctx.$store.dispatch.mockRejectedValue({
      response: { data: { error: ['Ese evento ya tiene una tarea'] } },
    });
    await methods.submit.call(ctx);

    expect(ctx.showAlert).toHaveBeenCalledWith('Ese evento ya tiene una tarea');
  });

  it('con hora crea una tarea agendada de Kontrolya con su contacto y su caso', async () => {
    const ctx = context({ data: { contact: { id: 7 }, caseId: 3 } });
    await methods.submit.call(ctx);

    expect(ctx.$store.dispatch).toHaveBeenCalledWith(
      'googleCalendar/createAgendaItem',
      expect.objectContaining({
        title: 'Visita',
        contact_id: 7,
        case_ticket_id: 3,
      })
    );
  });

  it('interno sigue yendo solo a Google', async () => {
    const ctx = context({ data: { needsClient: false, isAgenda: false } });
    await methods.submit.call(ctx);

    expect(ctx.$store.dispatch).toHaveBeenCalledWith(
      'googleCalendar/createEvent',
      expect.objectContaining({ summary: 'Visita' })
    );
  });

  it('un evento de Google se guarda y su tarea nace ligada a él', async () => {
    const ctx = context({
      data: {
        contact: { id: 7 },
        isEditing: true,
        isGoogleEvent: true,
        editEvent: { id: 'evt1' },
      },
    });
    await methods.submit.call(ctx);

    expect(ctx.$store.dispatch.mock.calls.map(call => call[0])).toEqual([
      'googleCalendar/updateEvent',
      'googleCalendar/createAgendaItem',
    ]);
    expect(ctx.$store.dispatch.mock.calls[1][1]).toMatchObject({
      google_event_id: 'evt1',
      contact_id: 7,
    });
  });

  it('un evento de Google de todo el día no pide contacto ni crea tarea', () => {
    const ctx = { isGoogleEvent: true, editEvent: { allDay: true } };
    const isAllDayEvent = computed.isAllDayEvent.call(ctx);

    expect(isAllDayEvent).toBe(true);
    expect(
      computed.isAgenda.call({
        agendaItem: null,
        internal: false,
        isAllDayEvent,
      })
    ).toBe(false);
  });

  it('solo ofrece casos si hay contacto u organización y aún no tiene caso', () => {
    const base = { isAgenda: true, agendaItem: null };
    expect(computed.canChooseCase.call({ ...base, contact: null })).toBeFalsy();
    expect(
      computed.canChooseCase.call({ ...base, contact: { id: 1 } })
    ).toBeTruthy();
    expect(
      computed.canChooseCase.call({
        ...base,
        organization: { id: 1 },
        agendaItem: { case_ticket: { id: 2 } },
      })
    ).toBeFalsy();
  });
});
