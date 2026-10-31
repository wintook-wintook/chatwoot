import QuickTaskModal from '../QuickTaskModal.vue';
import AgendaItemsAPI from 'dashboard/api/agendaItems';
import CaseTasksAPI from 'dashboard/api/caseTasks';
import QuickTasksAPI from 'dashboard/api/quickTasks';

vi.mock('dashboard/api/agendaItems', () => ({
  default: { create: vi.fn().mockResolvedValue({}), cases: vi.fn() },
}));
vi.mock('dashboard/api/caseTasks', () => ({
  default: { createTask: vi.fn().mockResolvedValue({}) },
}));
vi.mock('dashboard/api/quickTasks', () => ({
  default: { create: vi.fn().mockResolvedValue({}) },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const { methods } = QuickTaskModal;

const context = data => ({
  ...methods,
  title: 'Llamar',
  assigneeId: 5,
  dueDate: '',
  plannedDate: '2026-11-10',
  time: '',
  isVisit: false,
  address: '',
  contact: null,
  organization: null,
  caseId: '',
  saving: false,
  $t: key => key,
  $emit: vi.fn(),
  $emitter: { emit: vi.fn() },
  ...data,
});

describe('QuickTaskModal', () => {
  beforeEach(() => vi.clearAllMocks());

  it('sin hora ni caso crea una tarea rápida con su fecha programada', async () => {
    const ctx = context({ dueDate: '2026-11-12', contact: { id: 7 } });
    await methods.submit.call(ctx);

    const payload = QuickTasksAPI.create.mock.calls[0][0];
    expect(payload).toMatchObject({
      title: 'Llamar',
      planned_on: '2026-11-10',
      assignee_id: 5,
      contact_id: 7,
    });
    expect(new Date(payload.due_at).getDate()).toBe(12);
    expect(ctx.$emitter.emit).toHaveBeenCalledWith('agendaChanged');
  });

  it('con hora crea una tarea agendada de una hora, para el responsable', async () => {
    await methods.submit.call(context({ time: '10:00' }));

    const payload = AgendaItemsAPI.create.mock.calls[0][0];
    expect(payload.assignee_id).toBe(5);
    expect(
      new Date(payload.ends_at).getTime() -
        new Date(payload.starts_at).getTime()
    ).toBe(60 * 60 * 1000);
    expect(QuickTasksAPI.create).not.toHaveBeenCalled();
  });

  it('con caso y sin hora la crea dentro del caso', async () => {
    await methods.submit.call(context({ caseId: 3 }));

    expect(CaseTasksAPI.createTask).toHaveBeenCalledWith(
      3,
      expect.objectContaining({ title: 'Llamar', planned_on: '2026-11-10' })
    );
    expect(QuickTasksAPI.create).not.toHaveBeenCalled();
  });

  it('sin título no guarda', async () => {
    await methods.submit.call(context({ title: '  ' }));

    expect(QuickTasksAPI.create).not.toHaveBeenCalled();
  });

  it('una visita sin hora no guarda', async () => {
    await methods.submit.call(context({ isVisit: true }));

    expect(QuickTasksAPI.create).not.toHaveBeenCalled();
    expect(AgendaItemsAPI.create).not.toHaveBeenCalled();
  });

  it('con hora y sin fecha no guarda', async () => {
    await methods.submit.call(context({ time: '10:00', plannedDate: '' }));

    expect(AgendaItemsAPI.create).not.toHaveBeenCalled();
  });
});
