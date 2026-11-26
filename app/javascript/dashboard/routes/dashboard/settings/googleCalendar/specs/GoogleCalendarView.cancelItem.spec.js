import AgendaItemsAPI from 'dashboard/api/agendaItems';
import { useAlert } from 'dashboard/composables';
import GoogleCalendarView from '../GoogleCalendarView.vue';

// fix/calendario_eliminar F2 — de la ventana del evento a «Cancelar con motivo».
vi.mock('dashboard/api/agendaItems', () => ({
  default: { updateItem: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const { methods } = GoogleCalendarView;

const ctxWith = overrides => {
  const ctx = {
    ...GoogleCalendarView.data(),
    editingEvent: { id: 'ev1' },
    showCreateModal: true,
    $t: key => key,
    ...overrides,
  };
  Object.keys(methods).forEach(name => {
    ctx[name] = methods[name].bind(ctx);
  });
  ctx.fetchData = vi.fn();
  return ctx;
};

describe('GoogleCalendarView · cancelar tarea agendada', () => {
  beforeEach(() => vi.clearAllMocks());

  it('cierra la ventana del evento y abre la de cancelar, sabiendo si hay cliente', () => {
    const ctx = ctxWith();
    ctx.openCancelItem({ id: 7, title: 'Visita', contact: { id: 3 } });

    expect(ctx.showCreateModal).toBe(false);
    expect(ctx.cancelTarget).toMatchObject({ id: 7, has_client: true });
    expect(ctx.cancelEvent).toEqual({ id: 'ev1' });

    ctx.openCancelItem({ id: 8, title: 'Interna' });
    expect(ctx.cancelTarget.has_client).toBe(false);
  });

  it('«Reprogramar» vuelve a la ventana del mismo evento', () => {
    const ctx = ctxWith();
    ctx.openCancelItem({ id: 7 });
    ctx.rescheduleInstead();

    expect(ctx.cancelTarget).toBeNull();
    expect(ctx.showCreateModal).toBe(true);
    expect(ctx.editingEvent).toEqual({ id: 'ev1' });
  });

  it('manda status cancelled con el motivo y recarga', async () => {
    AgendaItemsAPI.updateItem.mockResolvedValue({ data: {} });
    const ctx = ctxWith();
    ctx.openCancelItem({ id: 7 });
    const reason = {
      reason_id: 2,
      comment: '',
      minutes: '',
      scope: 'one',
      notify_client: false,
    };
    await ctx.submitCancel(reason);

    expect(AgendaItemsAPI.updateItem).toHaveBeenCalledWith(7, {
      ...reason,
      status: 'cancelled',
    });
    expect(useAlert).toHaveBeenCalledWith(
      'GOOGLE_CALENDAR.EDIT_EVENT.CANCEL_ITEM_DONE'
    );
    expect(ctx.cancelTarget).toBeNull();
    expect(ctx.fetchData).toHaveBeenCalled();
  });

  it('avisa si se le escribió al cliente', async () => {
    AgendaItemsAPI.updateItem.mockResolvedValue({
      data: { client_notice: { sent: true } },
    });
    const ctx = ctxWith();
    ctx.openCancelItem({ id: 7, contact: { id: 3 } });
    await ctx.submitCancel({ notify_client: true });

    expect(useAlert).toHaveBeenCalledWith('CANCEL_ITEM.NOTICE_SENT');
  });

  it('si el servidor lo rechaza, deja la ventana abierta con el motivo', async () => {
    AgendaItemsAPI.updateItem.mockRejectedValue({
      response: { data: { error: 'Ticket cerrado' } },
    });
    const ctx = ctxWith();
    ctx.openCancelItem({ id: 7 });
    await ctx.submitCancel({});

    expect(ctx.cancelError).toBe('Ticket cerrado');
    expect(ctx.cancelTarget).not.toBeNull();
    expect(ctx.cancelBusy).toBe(false);
  });
});
