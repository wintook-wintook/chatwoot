import * as session from '../whatsappCallSession';
import WhatsappCallsAPI from 'dashboard/api/whatsappCalls';

vi.mock('dashboard/api/whatsappCalls', () => ({
  default: {
    initiate: vi.fn(),
    accept: vi.fn(),
    terminate: vi.fn().mockResolvedValue(),
  },
}));

// Un RTCPeerConnection de prueba: sus métodos no necesitan usar `this`.
/* eslint-disable class-methods-use-this, no-empty-function */
class FakePeer {
  constructor() {
    this.iceGatheringState = 'complete';
    this.localDescription = { sdp: 'v=0 local' };
    this.remote = null;
    FakePeer.last = this;
  }

  addTrack() {}

  addEventListener() {}

  async createOffer() {
    return { type: 'offer', sdp: 'v=0 offer' };
  }

  async createAnswer() {
    return { type: 'answer', sdp: 'v=0 answer' };
  }

  async setLocalDescription() {}

  async setRemoteDescription(desc) {
    this.remote = desc;
  }

  close() {}
}
/* eslint-enable class-methods-use-this, no-empty-function */

describe('Sesión WebRTC de llamadas de WhatsApp', () => {
  beforeEach(() => {
    global.RTCPeerConnection = FakePeer;
    global.navigator.mediaDevices = {
      getUserMedia: vi
        .fn()
        .mockResolvedValue({ getTracks: () => [], getAudioTracks: () => [] }),
    };
    session.cleanup();
  });

  it('si el SDP de Meta llega antes que la respuesta de initiate, se aplica al saber el id', async () => {
    WhatsappCallsAPI.initiate.mockImplementation(async () => {
      await session.applyOutboundAnswer({ id: 11, sdp_answer: 'v=0 meta' });
      return { data: { id: 11 } };
    });

    const resultado = await session.startOutbound(9);

    expect(resultado.call.id).toBe(11);
    expect(FakePeer.last.remote).toEqual({ type: 'answer', sdp: 'v=0 meta' });
    expect(session.isActiveCall(11)).toBe(true);
  });

  it('un 422 con status (permiso) no es error: limpia y lo devuelve', async () => {
    WhatsappCallsAPI.initiate.mockRejectedValue({
      response: { data: { status: 'permission_requested' } },
    });
    const resultado = await session.startOutbound(9);
    expect(resultado.permission.status).toBe('permission_requested');
    expect(session.hasActiveCall()).toBe(false);
  });

  it('contestar manda el answer del navegador', async () => {
    WhatsappCallsAPI.accept.mockResolvedValue({ data: { id: 5 } });
    await session.answerIncoming({
      id: 5,
      sdp_offer: 'v=0 offer',
      ice_servers: [],
    });
    expect(WhatsappCallsAPI.accept).toHaveBeenCalledWith(5, 'v=0 local');
    expect(FakePeer.last.remote).toEqual({ type: 'offer', sdp: 'v=0 offer' });
  });

  it('colgar avisa al servidor y suelta todo', async () => {
    WhatsappCallsAPI.accept.mockResolvedValue({ data: { id: 5 } });
    await session.answerIncoming({ id: 5, sdp_offer: 'v=0', ice_servers: [] });
    await session.hangup();
    expect(WhatsappCallsAPI.terminate).toHaveBeenCalledWith(5);
    expect(session.hasActiveCall()).toBe(false);
  });
});
