import axios from 'axios';
import cannedResponse from '../../cannedResponse';
import * as types from '../../../mutation-types';

const { actions } = cannedResponse;
const commit = vi.fn();
global.axios = axios;
vi.mock('axios');

// proyecto@respuestas_predefinidas R1
describe('#actions (vectorizar)', () => {
  beforeEach(() => commit.mockClear());

  it('vectorizeCannedResponse manda a vectorizar y guarda el estado que regresa', async () => {
    axios.post.mockResolvedValue({
      data: { id: 3, embedding_state: 'pending' },
    });

    await actions.vectorizeCannedResponse({ commit }, 3);

    expect(axios.post).toHaveBeenCalledWith(
      expect.stringContaining('/canned_responses/3/vectorize')
    );
    expect(commit).toHaveBeenCalledWith(types.default.EDIT_CANNED, {
      id: 3,
      embedding_state: 'pending',
    });
  });

  it('refreshCannedResponses vuelve a leer la lista sin la marca de cargando', async () => {
    axios.get.mockResolvedValue({ data: [{ id: 1 }] });

    await actions.refreshCannedResponses({ commit });

    expect(commit.mock.calls).toEqual([
      [types.default.SET_CANNED, [{ id: 1 }]],
    ]);
  });

  it('si falla la lectura, queda lo que había', async () => {
    axios.get.mockRejectedValue(new Error('x'));

    await actions.refreshCannedResponses({ commit });

    expect(commit).not.toHaveBeenCalled();
  });
});
