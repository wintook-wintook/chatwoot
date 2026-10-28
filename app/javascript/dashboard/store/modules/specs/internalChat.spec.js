// feat/chat_interno_pulido — contador del menú «Chat interno» y sonido.
import InternalChannelAPI from 'dashboard/api/internalChannel';
import { actions, mutations, getters } from '../internalChat';

vi.mock('dashboard/api/internalChannel', () => ({
  default: { ensure: vi.fn(), unread: vi.fn() },
}));

const message = extra => ({
  inbox_id: 9,
  conversation_id: 7,
  sender: { id: 2 },
  ...extra,
});

describe('internalChat store', () => {
  let dispatch;
  const rootGetters = { getCurrentUserID: 1, getSelectedChat: { id: 5 } };

  beforeEach(() => {
    InternalChannelAPI.ensure.mockResolvedValue({ data: { inbox_id: 9 } });
    InternalChannelAPI.unread.mockResolvedValue({ data: { unread: 3 } });
    dispatch = vi.fn();
    window.playAudioAlert = vi.fn();
  });

  it('guarda la bandeja y pide el contador al dejarla lista', async () => {
    const commit = vi.fn();
    await expect(actions.ensure({ commit, dispatch })).resolves.toBe(9);
    expect(commit).toHaveBeenCalledWith('SET_INBOX_ID', 9);
    expect(dispatch).toHaveBeenCalledWith('fetchUnread');
  });

  it('suena y recalcula con un mensaje de otro agente en una sala que no se ve', () => {
    actions.messageCreated(
      { state: { inboxId: 9 }, dispatch, rootGetters },
      message()
    );
    expect(window.playAudioAlert).toHaveBeenCalled();
    expect(dispatch).toHaveBeenCalledWith('fetchUnread');
  });

  it('no hace nada con lo propio ni con mensajes de otras bandejas', () => {
    const context = { state: { inboxId: 9 }, dispatch, rootGetters };
    actions.messageCreated(context, message({ sender: { id: 1 } }));
    actions.messageCreated(context, message({ inbox_id: 4 }));
    expect(window.playAudioAlert).not.toHaveBeenCalled();
    expect(dispatch).not.toHaveBeenCalled();
  });

  it('no suena si la sala está abierta y a la vista', () => {
    actions.messageCreated(
      {
        state: { inboxId: 9 },
        dispatch,
        rootGetters: { ...rootGetters, getSelectedChat: { id: 7 } },
      },
      message()
    );
    expect(window.playAudioAlert).not.toHaveBeenCalled();
    expect(dispatch).toHaveBeenCalledWith('fetchUnread');
  });

  it('mutaciones y getters', () => {
    const state = { inboxId: null, unread: 0 };
    mutations.SET_INBOX_ID(state, 9);
    mutations.SET_UNREAD(state, 4);
    expect(getters.getInboxId(state)).toBe(9);
    expect(getters.getUnread(state)).toBe(4);
  });
});
