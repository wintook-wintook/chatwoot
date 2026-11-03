import TaskReportModal from '../TaskReportModal.vue';
import TaskReportsAPI from 'dashboard/api/taskReports';
import taskReportFlow from 'dashboard/mixins/taskReportFlow';
import { useAlert } from 'dashboard/composables';

vi.mock('dashboard/api/taskReports', () => ({
  default: { send: vi.fn().mockResolvedValue({}) },
}));
vi.mock('dashboard/api/taskOutcomes', () => ({ default: { get: vi.fn() } }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const { methods } = TaskReportModal;
const context = data => ({
  ...methods,
  item: { type: 'task', id: 1, title: 'Llamar' },
  content: 'Le llamé',
  outcomeId: 2,
  files: [],
  saving: false,
  $t: key => key,
  $emit: vi.fn(),
  ...data,
});

describe('TaskReportModal', () => {
  beforeEach(() => vi.clearAllMocks());

  it('sin qué se hizo no concluye', async () => {
    const ctx = context({ content: '   ' });
    await methods.submit.call(ctx);

    expect(TaskReportsAPI.send).not.toHaveBeenCalled();
    expect(useAlert).toHaveBeenCalledWith('TASK_REPORT.REQUIRED');
    expect(ctx.$emit).not.toHaveBeenCalled();
  });

  it('manda el reporte y avisa para seguir concluyendo', async () => {
    const ctx = context();
    await methods.submit.call(ctx);

    expect(TaskReportsAPI.send).toHaveBeenCalledWith(
      { type: 'task', id: 1 },
      { content: 'Le llamé', outcomeId: 2, files: [] }
    );
    expect(ctx.$emit).toHaveBeenCalledWith('reported');
  });

  it('con varias tareas manda un reporte por cada una', async () => {
    const ctx = context({
      item: { type: 'task', ids: [4, 5], title: 'Tareas' },
    });
    await methods.submit.call(ctx);

    expect(TaskReportsAPI.send.mock.calls.map(c => c[0].id)).toEqual([4, 5]);
    expect(ctx.$emit).toHaveBeenCalledWith('reported');
  });

  it('si falla el reporte, la tarea no sigue', async () => {
    TaskReportsAPI.send.mockRejectedValueOnce({});
    const ctx = context();
    await methods.submit.call(ctx);

    expect(ctx.$emit).not.toHaveBeenCalledWith('reported');
  });

  it('el flujo solo sigue después de reportar; cancelar no concluye', () => {
    const then = vi.fn();
    const ctx = { ...taskReportFlow.methods, ...taskReportFlow.data() };

    ctx.askReport({ id: 1 }, then);
    ctx.cancelReport();
    ctx.onReported();
    expect(then).not.toHaveBeenCalled();

    ctx.askReport({ id: 1 }, then);
    ctx.onReported();
    expect(then).toHaveBeenCalledTimes(1);
  });
});
