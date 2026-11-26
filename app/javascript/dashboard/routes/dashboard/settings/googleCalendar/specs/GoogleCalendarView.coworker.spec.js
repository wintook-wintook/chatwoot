import AgendaItemsAPI from 'dashboard/api/agendaItems';
import { useAlert } from 'dashboard/composables';
import GoogleCalendarView from '../GoogleCalendarView.vue';
import CancelItemModal from 'dashboard/components/cancel/CancelItemModal.vue';

// feat/ventana_evento_calendario F5 (D7) — cancelar o eliminar lo del compañero.
vi.mock('dashboard/api/agendaItems', () => ({
  default: { updateItem: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const { methods, computed } = GoogleCalendarView;

const event = overrides => ({
  agentId: 4,
  name: 'Andres',
  eventId: 'e1',
  summary: 'Junta',
  recurringEventId: null,
  guests: 0,
  agendaItem: null,
  canSchedule: true,
  ...overrides,
});

const ctxWith = overrides => {
  const ctx = {
    ...GoogleCalendarView.data(),
    $t: key => key,
    $store: { dispatch: vi.fn().mockResolvedValue() },
    ...overrides,
  };
  Object.keys(methods).forEach(name => {
    ctx[name] = methods[name].bind(ctx);
  });
  ctx.fetchData = vi.fn();
  return ctx;
};

const can = coworkerEvent => {
  const ctx = { coworkerEvent };
  ctx.coworkerCanEdit = computed.coworkerCanEdit.call(ctx);
  return {
    cancel: computed.coworkerCanCancel.call(ctx),
    del: computed.coworkerCanDelete.call(ctx),
  };
};

describe('GoogleCalendarView · evento de un compañero (F5)', () => {
  beforeEach(() => vi.clearAllMocks());

  it('sin «Hacer cambios»: solo lectura', () => {
    expect(can(event({ canSchedule: false }))).toEqual({
      cancel: false,
      del: false,
    });
  });

  it('con permiso: tarea agendada → Cancelar; solo Google → Eliminar', () => {
    expect(can(event({ agendaItem: { id: 7 } }))).toEqual({
      cancel: true,
      del: false,
    });
    expect(can(event())).toEqual({ cancel: false, del: true });
  });

  it('Cancelar abre la ventana de motivo sin «reprogramar» y al terminar quita el evento', async () => {
    AgendaItemsAPI.updateItem.mockResolvedValue({ data: {} });
    const ctx = ctxWith({
      coworkerEvent: event({ agendaItem: { id: 7, title: 'Visita' } }),
    });
    ctx.cancelCoworkerItem();
    expect(ctx.coworkerEvent).toBeNull();
    expect(ctx.cancelTarget).toEqual({ id: 7, title: 'Visita' });
    expect(ctx.cancelCoworkerRef).toEqual({ agentId: 4, eventId: 'e1' });

    await ctx.submitCancel({ reason_id: 2 });
    expect(AgendaItemsAPI.updateItem).toHaveBeenCalledWith(7, {
      reason_id: 2,
      status: 'cancelled',
    });
    expect(ctx.$store.dispatch).toHaveBeenCalledWith(
      'googleCalendar/removeCoworkerEvent',
      {
        agentId: 4,
        eventId: 'e1',
      }
    );
    expect(ctx.cancelCoworkerRef).toBeNull();
  });

  it('Eliminar manda su agente, el alcance y el aviso, y cierra', async () => {
    const ctx = ctxWith({
      coworkerEvent: event({ recurringEventId: 's', guests: 2 }),
      coworkerDeleteScope: 'all',
    });
    await ctx.deleteCoworkerEvent();
    expect(ctx.$store.dispatch).toHaveBeenCalledWith(
      'googleCalendar/deleteCoworkerEvent',
      {
        agentId: 4,
        eventId: 'e1',
        scope: 'all',
        notify: true,
        seriesId: 's',
      }
    );
    expect(useAlert).toHaveBeenCalledWith(
      'GOOGLE_CALENDAR.DELETE_EVENT.DELETE_DONE'
    );
    expect(ctx.coworkerEvent).toBeNull();
  });

  it('si el servidor lo rechaza muestra su motivo y no cierra', async () => {
    const ctx = ctxWith({ coworkerEvent: event() });
    ctx.$store.dispatch.mockRejectedValue({
      response: { data: { error: 'Tu compañero no te dio permiso' } },
    });
    await ctx.deleteCoworkerEvent();
    expect(useAlert).toHaveBeenCalledWith('Tu compañero no te dio permiso');
    expect(ctx.coworkerEvent).not.toBeNull();
  });

  it('la ventana de motivo puede saltarse «¿Prefieres reprogramarla?»', () => {
    const watch = CancelItemModal.watch.show;
    const ctx = {
      isMeeting: true,
      allowReschedule: false,
      reasons: [1],
      emptyForm: () => ({}),
    };
    watch.call(ctx, true);
    expect(ctx.step).toBe('form');
    const ctx2 = { ...ctx, allowReschedule: true };
    watch.call(ctx2, true);
    expect(ctx2.step).toBe('ask');
  });
});
