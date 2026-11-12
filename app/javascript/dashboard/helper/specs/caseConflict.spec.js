import { emitter } from 'shared/helpers/mitt';
import {
  changedFields,
  expectedState,
  findCaseTicket,
  guarded,
  CONFLICT_EVENT,
} from '../caseConflict';

const ticket = {
  id: 7,
  status: 'in_progress',
  case_type_column_id: 3,
  amount: 1000,
  probability: 50,
  custom_attributes: { root_cause: 'x' },
};

describe('caseConflict', () => {
  it('solo manda lo que cambió y lo que se veía de eso', () => {
    const { payload, expected } = changedFields(ticket, {
      amount: '1200',
      probability: 50,
      custom_attributes: { root_cause: 'x', workaround: 'y' },
    });
    expect(payload).toEqual({
      amount: '1200',
      custom_attributes: { workaround: 'y' },
    });
    expect(expected).toEqual({
      amount: 1000,
      custom_attributes: { workaround: null },
    });
  });

  it('si nada cambió manda igual, sin expected', () => {
    expect(changedFields(ticket, { amount: 1000 })).toEqual({
      payload: { amount: 1000 },
      expected: undefined,
    });
  });

  it('el estado y la etapa de donde parte', () => {
    expect(expectedState(ticket, true)).toEqual({
      expected_status: 'in_progress',
      expected_column_id: 3,
    });
    expect(expectedState(null)).toEqual({});
  });

  it('busca el caso en la lista, el tablero o el activo', () => {
    expect(findCaseTicket({ boardTickets: [ticket] }, '7')).toBe(ticket);
    expect(findCaseTicket(undefined, 7)).toBeNull();
  });

  it('ante conflicto avisa con un reintento a la fuerza', async () => {
    const send = vi
      .fn()
      .mockRejectedValueOnce({
        response: { status: 409, data: { conflict: true, fields: [] } },
      })
      .mockResolvedValueOnce({ data: 'ok' });
    const heard = vi.fn();
    emitter.on(CONFLICT_EVENT, heard);

    await expect(guarded(send)).rejects.toBeTruthy();
    const event = heard.mock.calls[0][0];
    expect(await event.retry()).toEqual({ data: 'ok' });
    expect(send).toHaveBeenLastCalledWith({ force: true });
    emitter.off(CONFLICT_EVENT, heard);
  });
});
