import { actions, mutations, state as initialState } from '../../whatsappCalls';
import * as session from 'dashboard/helper/whatsappCallSession';
import WhatsappCallsAPI from 'dashboard/api/whatsappCalls';

vi.mock('dashboard/helper/whatsappCallSession', () => ({
  answerIncoming: vi.fn(),
  startOutbound: vi.fn(),
  applyOutboundAnswer: vi.fn(),
  hangup: vi.fn().mockResolvedValue(),
  cleanup: vi.fn(),
  finishCall: vi.fn().mockResolvedValue(),
  armRecorder: vi.fn(),
  toggleMute: vi.fn().mockReturnValue(true),
}));
vi.mock('dashboard/api/whatsappCalls', () => ({
  default: { reject: vi.fn().mockResolvedValue() },
}));

// Un contexto real con las mutaciones, para ver cómo queda el estado.
const contexto = (estado = {}) => {
  const state = { ...initialState, ...estado };
  const commit = (tipo, valor) => mutations[tipo](state, valor);
  return { state, commit, rootGetters: { getCurrentUserID: 1 } };
};

const llamada = {
  id: 5,
  conversation_id: 9,
  inbox_id: 3,
  caller: { name: 'Juan' },
  sdp_offer: 'v=0',
};

describe('whatsappCalls — eventos', () => {
  it('suena una entrante, pero no si ya hay una llamada', () => {
    const ctx = contexto();
    actions.onIncoming(ctx, llamada);
    expect(ctx.state.incoming).toEqual(llamada);

    const ocupado = contexto({ active: { id: 1 } });
    actions.onIncoming(ocupado, llamada);
    expect(ocupado.state.incoming).toBeNull();
  });

  it('si la contestó otro agente, deja de sonar; si la contesté yo, no', () => {
    const ctx = contexto({ incoming: llamada });
    actions.onAccepted(ctx, { id: 5, accepted_by_agent_id: 1 });
    expect(ctx.state.incoming).toEqual(llamada);
    actions.onAccepted(ctx, { id: 5, accepted_by_agent_id: 2 });
    expect(ctx.state.incoming).toBeNull();
  });

  it('al terminar la activa, cierra el audio y sube lo grabado', () => {
    session.finishCall.mockResolvedValue();
    const ctx = contexto({ active: { id: 5 } });
    actions.onEnded(ctx, { id: 5 });
    expect(ctx.state.active).toBeNull();
    expect(session.finishCall).toHaveBeenCalled();
  });

  it('cuando el cliente contesta la saliente, arranca el cronómetro', () => {
    const ctx = contexto({ active: { id: 7, status: 'ringing' } });
    actions.onOutboundAccepted(ctx, { id: 7 });
    expect(ctx.state.active.status).toBe('in_progress');
    expect(ctx.state.active.startedAt).toBeTruthy();
    expect(session.armRecorder).toHaveBeenCalledWith(7);
  });

  it('el permiso concedido deja un aviso para el widget', () => {
    const ctx = contexto();
    actions.onPermissionGranted(ctx, { contact_name: 'Juan' });
    expect(ctx.state.notice).toMatchObject({
      key: 'WHATSAPP_CALLS.WIDGET.PERMISSION_GRANTED',
      args: { name: 'Juan' },
    });
  });
});

describe('whatsappCalls — acciones del agente', () => {
  beforeEach(() => {
    WhatsappCallsAPI.reject.mockResolvedValue();
    session.hangup.mockResolvedValue();
    session.toggleMute.mockReturnValue(true);
  });

  it('contestar pasa la entrante a activa', async () => {
    session.answerIncoming.mockResolvedValue({ id: 5 });
    const ctx = contexto({ incoming: llamada });
    await actions.answer(ctx);
    expect(ctx.state.incoming).toBeNull();
    expect(ctx.state.active).toMatchObject({
      id: 5,
      direction: 'inbound',
      status: 'in_progress',
    });
  });

  it('si otro ya la contestó (409), avisa', async () => {
    session.answerIncoming.mockRejectedValue({ response: { status: 409 } });
    const ctx = contexto({ incoming: llamada });
    await actions.answer(ctx);
    expect(ctx.state.active).toBeNull();
    expect(ctx.state.notice.key).toBe('WHATSAPP_CALLS.WIDGET.ALREADY_TAKEN');
  });

  it('rechazar avisa al servidor y deja de sonar', async () => {
    const ctx = contexto({ incoming: llamada });
    await actions.reject(ctx);
    expect(WhatsappCallsAPI.reject).toHaveBeenCalledWith(5);
    expect(ctx.state.incoming).toBeNull();
  });

  it('llamar: si Meta acepta queda sonando del lado del cliente', async () => {
    session.startOutbound.mockResolvedValue({ call: { id: 11 } });
    const ctx = contexto();
    await actions.call(ctx, {
      id: 9,
      inbox_id: 3,
      meta: { sender: { name: 'Ana' } },
    });
    expect(ctx.state.active).toMatchObject({
      id: 11,
      status: 'ringing',
      direction: 'outbound',
    });
  });

  it('llamar sin permiso: avisa que se pidió y no queda llamada', async () => {
    session.startOutbound.mockResolvedValue({
      permission: { status: 'permission_requested' },
    });
    const ctx = contexto();
    await actions.call(ctx, { id: 9, inbox_id: 3 });
    expect(ctx.state.active).toBeNull();
    expect(ctx.state.notice.key).toBe(
      'WHATSAPP_CALLS.WIDGET.PERMISSION_REQUESTED'
    );
  });

  it('silenciar cambia muted', () => {
    const ctx = contexto({ active: { id: 5, muted: false } });
    actions.toggleMute(ctx);
    expect(ctx.state.active.muted).toBe(true);
  });
});
