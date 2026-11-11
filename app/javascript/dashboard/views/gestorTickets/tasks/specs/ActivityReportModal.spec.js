import ActivityReportModal from '../ActivityReportModal.vue';
import TaskReportsAPI from 'dashboard/api/taskReports';

vi.mock('dashboard/api/taskReports', () => ({
  default: {
    sendActivity: vi.fn().mockResolvedValue({}),
    sendProgress: vi.fn().mockResolvedValue({}),
  },
}));
vi.mock('dashboard/api/taskOutcomes', () => ({ default: { get: vi.fn() } }));
vi.mock('dashboard/api/agendaItems', () => ({ default: { cases: vi.fn() } }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const { methods } = ActivityReportModal;

const context = data => ({
  ...methods,
  title: ' Llamada ',
  content: ' Confirmó la entrega ',
  date: '2026-11-04',
  time: '10:30',
  outcomeId: '',
  files: [],
  minutes: 45,
  minutesRequired: true,
  contact: null,
  organization: null,
  caseId: '',
  task: null,
  tasks: [],
  taskId: '',
  progressTask: null,
  saving: false,
  $t: key => key,
  $emit: vi.fn(),
  $emitter: { emit: vi.fn() },
  ...data,
});

describe('ActivityReportModal', () => {
  beforeEach(() => vi.clearAllMocks());

  it('sin cliente la manda interna, con la hora en que se hizo', async () => {
    const ctx = context();
    await methods.submit.call(ctx);

    const payload = TaskReportsAPI.sendActivity.mock.calls[0][0];
    expect(payload).toMatchObject({
      title: 'Llamada',
      content: 'Confirmó la entrega',
      caseId: '',
      contactId: undefined,
      organizationId: undefined,
      minutes: 45,
    });
    expect(new Date(payload.doneAt).getHours()).toBe(10);
    expect(ctx.$emitter.emit).toHaveBeenCalledWith('taskReportsChanged');
    expect(ctx.$emit).toHaveBeenCalledWith('close');
  });

  it('manda el contacto, la organización y el caso elegidos', async () => {
    await methods.submit.call(
      context({ contact: { id: 7 }, organization: { id: 9 }, caseId: 3 })
    );

    expect(TaskReportsAPI.sendActivity.mock.calls[0][0]).toMatchObject({
      contactId: 7,
      organizationId: 9,
      caseId: 3,
    });
  });

  it('con tarea es su avance: va a la tarea y avisa a su caso', async () => {
    const task = { id: 5, title: 'Llamar', case_ticket_id: 3 };
    const ctx = context({ title: '', task, progressTask: task });
    await methods.submit.call(ctx);

    expect(TaskReportsAPI.sendActivity).not.toHaveBeenCalled();
    expect(TaskReportsAPI.sendProgress.mock.calls[0][0]).toBe(5);
    expect(TaskReportsAPI.sendProgress.mock.calls[0][1]).toMatchObject({
      content: 'Confirmó la entrega',
      minutes: 45,
    });
    expect(ctx.$emitter.emit).toHaveBeenCalledWith('taskReportsChanged', {
      taskId: 5,
      caseId: 3,
    });
    expect(ctx.$emit).toHaveBeenCalledWith('close');
  });

  it('sin título, sin qué se hizo o sin el tiempo exigido no guarda', async () => {
    await methods.submit.call(context({ title: '  ' }));
    await methods.submit.call(context({ content: '  ' }));
    await methods.submit.call(context({ minutes: null }));

    expect(TaskReportsAPI.sendActivity).not.toHaveBeenCalled();
  });
});
