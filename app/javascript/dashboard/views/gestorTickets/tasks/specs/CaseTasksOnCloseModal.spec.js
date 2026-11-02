import CaseTasksOnCloseModal from '../CaseTasksOnCloseModal.vue';
import CaseTasksAPI from 'dashboard/api/caseTasks';
import CaseMeetingsAPI from 'dashboard/api/caseMeetings';

vi.mock('dashboard/api/caseTasks', () => ({
  default: {
    getAll: vi.fn(),
    updateTask: vi.fn().mockResolvedValue({}),
  },
}));
vi.mock('dashboard/api/caseMeetings', () => ({
  default: { upcoming: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const { methods } = CaseTasksOnCloseModal;
const context = () => ({
  ...methods,
  ...CaseTasksOnCloseModal.data(),
  $t: key => key,
});
const pending = [
  { id: 1, title: 'Llamar', status: 'pending' },
  { id: 2, title: 'Documenta', status: 'pending', documentation: true },
  { id: 3, title: 'Revisar', status: 'pending', report_required: false },
];

describe('CaseTasksOnCloseModal', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    CaseMeetingsAPI.upcoming.mockResolvedValue({
      data: { case_meetings: [], cancel_default: true },
    });
  });

  it('sin pendientes no pregunta', async () => {
    CaseTasksAPI.getAll.mockResolvedValue({
      data: { case_tasks: [{ id: 1, status: 'done' }] },
    });
    const ctx = context();

    expect(await methods.ask.call(ctx, 5, 'cancelled')).toEqual({});
    expect(ctx.show).toBe(false);
  });

  it('pregunta, y regresar deja el caso sin cerrar', async () => {
    CaseTasksAPI.getAll.mockResolvedValue({ data: { case_tasks: pending } });
    const ctx = context();
    const answer = methods.ask.call(ctx, 5);
    await vi.waitFor(() => expect(ctx.show).toBe(true));

    ctx.finish(null);

    expect(await answer).toBeNull();
  });

  it('conservar se manda como decisión', async () => {
    CaseTasksAPI.getAll.mockResolvedValue({ data: { case_tasks: pending } });
    const ctx = context();
    const answer = methods.ask.call(ctx, 5);
    await vi.waitFor(() => expect(ctx.show).toBe(true));

    ctx.decision = 'keep';
    ctx.confirm();

    expect((await answer).pending_tasks).toBe('keep');
    expect(CaseTasksAPI.updateTask).not.toHaveBeenCalled();
  });

  it('concluir pide un reporte sin la lista de la orden ni «Documenta…», y concluye', async () => {
    CaseTasksAPI.getAll.mockResolvedValue({ data: { case_tasks: pending } });
    const ctx = context();
    const answer = methods.ask.call(ctx, 5);
    await vi.waitFor(() => expect(ctx.show).toBe(true));

    ctx.decision = 'conclude';
    ctx.confirm();
    expect(ctx.reportItem.ids).toEqual([1]);

    await ctx.conclude();

    expect((await answer).pending_tasks).toBe('cancel');
    expect(CaseTasksAPI.updateTask.mock.calls.map(c => c[1])).toEqual([1, 3]);
  });

  it('con tareas agendadas a futuro pregunta aunque no haya tareas', async () => {
    CaseTasksAPI.getAll.mockResolvedValue({ data: { case_tasks: [] } });
    CaseMeetingsAPI.upcoming.mockResolvedValue({
      data: { case_meetings: [{ id: 9, title: 'Cita' }], cancel_default: true },
    });
    const ctx = context();
    const answer = methods.ask.call(ctx, 5, 'cancelled');
    await vi.waitFor(() => expect(ctx.show).toBe(true));

    ctx.confirm();

    expect((await answer).cancel_meetings).toBe(true);
  });

  it('si desmarca la casilla no se cancelan', async () => {
    CaseTasksAPI.getAll.mockResolvedValue({ data: { case_tasks: [] } });
    CaseMeetingsAPI.upcoming.mockResolvedValue({
      data: { case_meetings: [{ id: 9, title: 'Cita' }], cancel_default: true },
    });
    const ctx = context();
    const answer = methods.ask.call(ctx, 5, 'cancelled');
    await vi.waitFor(() => expect(ctx.show).toBe(true));

    ctx.cancelMeetings = false;
    ctx.confirm();

    expect((await answer).cancel_meetings).toBeUndefined();
  });
});
