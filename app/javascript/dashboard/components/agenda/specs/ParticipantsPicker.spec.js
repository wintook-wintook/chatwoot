import ParticipantsPicker from '../ParticipantsPicker.vue';
import AgendaItemsAPI from 'dashboard/api/agendaItems';

vi.mock('dashboard/api/agendaItems', () => ({
  default: { busy: vi.fn().mockResolvedValue({ data: { busy: [] } }) },
}));

const { methods, computed } = ParticipantsPicker;

const context = data => ({
  ...methods,
  value: [],
  organizerId: 1,
  startsAt: '2026-11-25T10:00',
  endsAt: '2026-11-25T11:00',
  excludeId: null,
  current: [],
  busy: [],
  agents: [
    { id: 1, name: 'Ana' },
    { id: 2, name: 'Beto' },
  ],
  $emit: vi.fn(),
  ...data,
});

describe('ParticipantsPicker', () => {
  beforeEach(() => vi.clearAllMocks());

  it('no ofrece al responsable', () => {
    expect(computed.options.call(context()).map(a => a.id)).toEqual([2]);
  });

  it('agrega y quita participantes', () => {
    const ctx = context({ value: [2] });
    methods.toggle.call(ctx, 2);
    expect(ctx.$emit).toHaveBeenCalledWith('input', []);
    methods.toggle.call(context(), 3);
  });

  it('pregunta si ya tienen algo a esa hora y lo avisa', async () => {
    AgendaItemsAPI.busy.mockResolvedValueOnce({
      data: { busy: [{ user_id: 2, name: 'Beto', items: [] }] },
    });
    const ctx = context({ value: [2] });
    await methods.checkBusy.call(ctx);
    expect(AgendaItemsAPI.busy.mock.calls[0][0]).toMatchObject({
      user_ids: [2],
    });
    expect(ctx.busy[0].name).toBe('Beto');
  });

  it('sin participantes no pregunta', async () => {
    await methods.checkBusy.call(context());
    expect(AgendaItemsAPI.busy).not.toHaveBeenCalled();
  });
});
