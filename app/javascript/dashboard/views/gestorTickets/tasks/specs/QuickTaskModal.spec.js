import QuickTaskModal from '../QuickTaskModal.vue';
import AgendaItemsAPI from 'dashboard/api/agendaItems';
import CaseTasksAPI from 'dashboard/api/caseTasks';
import QuickTasksAPI from 'dashboard/api/quickTasks';
import TaskRecurrencesAPI from 'dashboard/api/taskRecurrences';
import { defaultRecurrence } from 'dashboard/components/recurrence/recurrence';

vi.mock('dashboard/api/agendaItems', () => ({
  default: { create: vi.fn().mockResolvedValue({}), cases: vi.fn() },
}));
vi.mock('dashboard/api/caseTasks', () => ({
  default: { createTask: vi.fn().mockResolvedValue({}) },
}));
vi.mock('dashboard/api/quickTasks', () => ({
  default: { create: vi.fn().mockResolvedValue({}) },
}));
vi.mock('dashboard/api/taskRecurrences', () => ({
  default: { create: vi.fn().mockResolvedValue({ data: {} }) },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const { methods } = QuickTaskModal;

const context = data => ({
  ...methods,
  title: 'Llamar',
  description: '',
  assigneeId: 5,
  participantIds: [],
  repeats: false,
  recurrence: defaultRecurrence(),
  $tc: key => key,
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

  it('«Se repite» crea la tarea que se repite, no una tarea suelta', async () => {
    const recurrence = { ...defaultRecurrence(), weekdays: [1, 4] };
    await methods.submit.call(
      context({ repeats: true, recurrence, time: '09:00', contact: { id: 7 } })
    );
    expect(TaskRecurrencesAPI.create.mock.calls[0][0]).toMatchObject({
      title: 'Llamar',
      starts_on: '2026-11-10',
      at_time: '09:00',
      mode: 'fixed',
      unit: 'week',
      weekdays: [1, 4],
      contact_id: 7,
      assignee_id: 5,
    });
    expect(AgendaItemsAPI.create).not.toHaveBeenCalled();
    expect(QuickTasksAPI.create).not.toHaveBeenCalled();
  });

  it('«Se repite» cada semana sin días no se guarda', async () => {
    const recurrence = { ...defaultRecurrence(), weekdays: [] };
    await methods.submit.call(context({ repeats: true, recurrence }));
    expect(TaskRecurrencesAPI.create).not.toHaveBeenCalled();
  });

  it('con hora manda los participantes, sin repetir al responsable', async () => {
    await methods.submit.call(
      context({ time: '10:00', participantIds: [5, 8, 9] })
    );
    expect(AgendaItemsAPI.create.mock.calls[0][0].participant_ids).toEqual([
      8, 9,
    ]);
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

  it('manda la descripción en los tres caminos', async () => {
    const description = '  Llevar el contrato  ';
    await methods.submit.call(context({ description }));
    await methods.submit.call(context({ description, time: '10:00' }));
    await methods.submit.call(context({ description, caseId: 3 }));

    const expected = 'Llevar el contrato';
    expect(QuickTasksAPI.create.mock.calls[0][0].description).toBe(expected);
    expect(AgendaItemsAPI.create.mock.calls[0][0].description).toBe(expected);
    expect(CaseTasksAPI.createTask.mock.calls[0][1].description).toBe(expected);
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
