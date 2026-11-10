import Kanban from '../../Kanban.vue';

// Soltar una tarjeta en una columna que cierra pregunta qué pasa con lo pendiente.
const { methods } = Kanban;
const ticket = { id: 5 };
const context = (ask, dispatch = vi.fn().mockResolvedValue()) => ({
  ...methods,
  $refs: { tasksOnClose: { ask } },
  $store: { dispatch },
  $t: key => key,
  $emitter: { emit: vi.fn() },
  fetch: vi.fn(),
  outcomeMove: null,
});

describe('Tablero: cerrar arrastrando', () => {
  it('pregunta y manda la decisión', async () => {
    const ask = vi.fn().mockResolvedValue({ pending_tasks: 'keep' });
    const ctx = context(ask);

    await methods.commercialMove.call(ctx, ticket, {
      id: 9,
      statuses: ['closed'],
    });

    expect(ask).toHaveBeenCalledWith(5, 'closed');
    expect(ctx.$store.dispatch.mock.calls[0][1]).toMatchObject({
      pending_tasks: 'keep',
    });
  });

  it('con «Volver» la tarjeta no se mueve', async () => {
    const ctx = context(vi.fn().mockResolvedValue(null));

    await methods.commercialMove.call(ctx, ticket, {
      id: 9,
      statuses: ['cancelled'],
    });

    expect(ctx.$store.dispatch).not.toHaveBeenCalled();
  });

  it('no pregunta en columnas que no cierran', async () => {
    const ask = vi.fn();
    const ctx = context(ask);

    await methods.commercialMove.call(ctx, ticket, {
      id: 9,
      statuses: ['in_progress'],
    });

    expect(ask).not.toHaveBeenCalled();
    expect(ctx.$store.dispatch).toHaveBeenCalled();
  });

  it('si pide resultado, no vuelve a preguntar al reintentar', async () => {
    const ask = vi.fn().mockResolvedValue({ pending_tasks: 'keep' });
    const dispatch = vi
      .fn()
      .mockRejectedValueOnce({ response: { data: { requires_outcome: true } } })
      .mockResolvedValue();
    const ctx = context(ask, dispatch);
    const column = { id: 9, statuses: ['closed'] };

    await methods.commercialMove.call(ctx, ticket, column);
    methods.confirmOutcomeMove.call(ctx, { outcome: 'lost' });
    await vi.waitFor(() => expect(dispatch).toHaveBeenCalledTimes(2));

    expect(ask).toHaveBeenCalledTimes(1);
    expect(dispatch.mock.calls[1][1]).toMatchObject({
      pending_tasks: 'keep',
      closure: { outcome: 'lost' },
    });
  });
});
