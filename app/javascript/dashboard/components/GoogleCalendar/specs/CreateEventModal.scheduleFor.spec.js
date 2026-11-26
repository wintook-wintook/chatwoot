import CreateEventModal from '../CreateEventModal.vue';

// fix/calendario_google F3b — «Agendar a»: qué se manda al servidor en cada camino.
const { methods, computed } = CreateEventModal;

const baseCtx = overrides => {
  const ctx = {
    form: {
      type: 'event',
      summary: 'Visita',
      description: '',
      all_day: false,
      start_time: '2026-11-26T07:00',
      end_time: '2026-11-26T07:15',
      calendar_id: 'ana@gmail.com',
    },
    attendees: [],
    participantIds: [5, 9],
    scheduleFor: '',
    isVisit: false,
    address: '',
    contact: { id: 3 },
    caseId: '',
    isEditing: false,
    $store: { dispatch: vi.fn() },
    ...overrides,
  };
  ctx.schedulingForOther = computed.schedulingForOther.call(ctx);
  ctx.itemFields = () => methods.itemFields.call(ctx);
  ctx.clientFields = () => methods.clientFields.call(ctx);
  return ctx;
};

describe('CreateEventModal · Agendar a', () => {
  it('para mí: mi calendario elegido, sin agent_id ni responsable', () => {
    const ctx = baseCtx();
    expect(methods.googlePayload.call(ctx)).toMatchObject({
      calendar_id: 'ana@gmail.com',
    });
    expect(methods.googlePayload.call(ctx).agent_id).toBeUndefined();

    methods.createAgendaItem.call(ctx);
    const payload = ctx.$store.dispatch.mock.calls[0][1];
    expect(payload).toMatchObject({ calendar_id: 'ana@gmail.com' });
    expect(payload.assignee_id).toBeUndefined();
    expect(payload.participant_ids).toEqual([5, 9]);
  });

  it('evento interno para un compañero: manda agent_id', () => {
    const ctx = baseCtx({ scheduleFor: '9' });
    expect(methods.googlePayload.call(ctx)).toMatchObject({ agent_id: 9 });
  });

  it('tarea agendada para un compañero: su principal, él responsable y no repetido como participante', () => {
    const ctx = baseCtx({ scheduleFor: '9' });
    methods.createAgendaItem.call(ctx);
    const payload = ctx.$store.dispatch.mock.calls[0][1];
    expect(payload).toMatchObject({ calendar_id: 'primary', assignee_id: 9 });
    expect(payload.participant_ids).toEqual([5]);
  });

  it('al editar nunca se agenda a otro', () => {
    const ctx = baseCtx({ scheduleFor: '9', isEditing: true });
    expect(ctx.schedulingForOther).toBe(false);
  });

  it('solo ofrece compañeros con «Hacer cambios»', () => {
    const ctx = {
      agents: [
        { id: 4, name: 'Andres' },
        { id: 9, available_name: 'Beto', name: 'Roberto' },
      ],
      coworkers: [
        { agent_id: 4, can_schedule: false },
        { agent_id: 9, can_schedule: true },
        { agent_id: 77, can_schedule: true },
      ],
    };
    expect(computed.scheduleOptions.call(ctx)).toEqual([
      { id: 9, name: 'Beto' },
    ]);
  });
});
