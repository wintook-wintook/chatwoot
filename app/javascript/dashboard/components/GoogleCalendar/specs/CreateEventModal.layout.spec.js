import AgendaItemsAPI from 'dashboard/api/agendaItems';
import CreateEventModal from '../CreateEventModal.vue';

vi.mock('dashboard/api/agendaItems', () => ({
  default: { updateItem: vi.fn().mockResolvedValue({}) },
}));

// feat/ventana_evento_calendario F1 — cabecera + pestañas + pie, invitados por comas.
const { methods, computed } = CreateEventModal;

const withComputed = (ctx, names) => {
  names.forEach(name => {
    ctx[name] = computed[name].call(ctx);
  });
  return ctx;
};

const tabsFor = overrides => {
  const ctx = {
    agendaItem: null,
    isAllDayEvent: false,
    canChooseCase: false,
    participating: false,
    isAgenda: true,
    form: { type: 'event' },
    showAttendees: true,
    participantIds: [],
    attendees: [],
    submitTried: false,
    needsClient: true,
    contact: null,
    caseId: '',
    activeTab: 'client',
    $t: key => key.split('.').pop(),
    ...overrides,
  };
  return withComputed(ctx, [
    'showClientTab',
    'showPeopleTab',
    'peopleCount',
    'clientMissing',
    'tabs',
    'currentTab',
    'tabIndex',
  ]);
};

describe('CreateEventModal · F2 Participantes', () => {
  it('lo escrito mal en el buscador no deja guardar y abre Participantes', () => {
    const ctx = {
      $refs: { people: { flush: () => false } },
      activeTab: 'client',
      showAlert: vi.fn(),
      $t: k => k,
    };
    expect(methods.flushPeople.call(ctx)).toBe(false);
    expect(ctx.activeTab).toBe('people');
    expect(ctx.showAlert).toHaveBeenCalledWith(
      'GOOGLE_CALENDAR.PEOPLE.INVALID_SUBMIT'
    );
    expect(
      methods.flushPeople.call({ $refs: { people: { flush: () => true } } })
    ).toBe(true);
    expect(methods.flushPeople.call({ $refs: {} })).toBe(true);
  });

  it('D4: sugiere al cliente solo si tiene correo', () => {
    const sug = contact => computed.clientSuggestion.call({ contact });
    expect(sug({ name: 'Juan', email: 'j@c.com' })).toEqual({
      name: 'Juan',
      email: 'j@c.com',
    });
    expect(sug({ name: 'Juan' })).toBeNull();
    expect(sug(null)).toBeNull();
  });
});

describe('CreateEventModal · pestañas', () => {
  it('nueva tarea agendada: Cliente | Personas (sin Detalles: la descripción va arriba)', () => {
    const ctx = tabsFor({ participantIds: [4], attendees: ['a@x.com'] });
    expect(ctx.tabs.map(t => t.key)).toEqual(['client', 'people']);
    expect(ctx.tabs[1].count).toBe(2);
  });

  it('todo el día de Google sin caso: sin pestañas', () => {
    const ctx = tabsFor({
      isAllDayEvent: true,
      isAgenda: false,
      showAttendees: false,
      activeTab: 'client',
    });
    expect(ctx.tabs).toEqual([]);
    expect(ctx.currentTab).toBeNull();
  });

  it('si al guardar falta el cliente, Cliente lleva el punto', () => {
    expect(tabsFor({ submitTried: true }).tabs[0].label).toBe('CLIENT •');
    expect(
      tabsFor({ submitTried: true, contact: { id: 1 } }).tabs[0].label
    ).toBe('CLIENT');
  });

  it('D6: con qué pestaña abre', () => {
    const open = ctx => methods.defaultTab.call(ctx);
    expect(open({ agendaItem: null, isEditing: false, internal: false })).toBe(
      'client'
    );
    expect(open({ agendaItem: null, isEditing: false, internal: true })).toBe(
      'people'
    );
    expect(open({ agendaItem: null, isEditing: true })).toBe('people');
    expect(open({ agendaItem: { id: 7 }, lastItemTab: 'people' })).toBe(
      'people'
    );
    expect(open({ agendaItem: { id: 7 }, lastItemTab: null })).toBe('client');
  });

  it('al cambiar de pestaña en una tarea agendada la recuerda', () => {
    const ctx = tabsFor({ agendaItem: { id: 7 } });
    methods.selectTab.call(ctx, 1);
    expect(ctx.activeTab).toBe('people');
    expect(ctx.lastItemTab).toBe('people');
  });
});

describe('CreateEventModal · responsable y títulos', () => {
  it('H2: quien agenda nunca se ofrece como participante', () => {
    const org = ctx => computed.participantsOrganizerId.call(ctx);
    expect(org({ agendaItem: null, scheduleFor: '', currentUserId: 1 })).toBe(
      1
    );
    expect(org({ agendaItem: null, scheduleFor: '4', currentUserId: 1 })).toBe(
      4
    );
    expect(
      org({
        agendaItem: { organizer: { id: 9 } },
        scheduleFor: '',
        currentUserId: 1,
      })
    ).toBe(9);
  });

  it('«Editar tarea agendada» o «Editar evento»', () => {
    const title = ctx => computed.modalTitle.call({ $t: k => k, ...ctx });
    expect(title({ isEditing: true, agendaItem: { id: 7 } })).toBe(
      'GOOGLE_CALENDAR.EDIT_EVENT.TITLE_ITEM'
    );
    expect(title({ isEditing: true, agendaItem: null })).toBe(
      'GOOGLE_CALENDAR.EDIT_EVENT.TITLE'
    );
  });
});

describe('CreateEventModal · F3 invitados al editar una tarea agendada', () => {
  it('se ven si soy el responsable; no si voy como participante', () => {
    const show = ctx => computed.showAttendees.call(ctx);
    expect(show({ form: { type: 'event' }, participating: false })).toBe(true);
    expect(show({ form: { type: 'event' }, participating: true })).toBe(false);
    expect(show({ form: { type: 'task' }, participating: false })).toBe(false);
  });

  it('al guardar manda sus correos invitados', async () => {
    const ctx = {
      agendaItem: { id: 7 },
      attendees: ['jefe@empresa.com'],
      caseId: '',
      itemFields: () => ({ title: 'Visita' }),
    };
    await methods.saveAgendaItem.call(ctx);
    expect(AgendaItemsAPI.updateItem).toHaveBeenCalledWith(7, {
      title: 'Visita',
      attendee_emails: ['jefe@empresa.com'],
    });
  });
});
