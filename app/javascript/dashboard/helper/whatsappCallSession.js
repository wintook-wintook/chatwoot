// diag/llamadas_whatsapp (F5) — EL AUDIO DE UNA LLAMADA DE WHATSAPP EN EL NAVEGADOR
// ============================================================================
// Portado de la v4.19 (dashboard/composables/useWhatsappCallSession.js), sin
// grabación (F7). El audio va directo del navegador a Meta (WebRTC); el servidor solo
// pasa el SDP. Estado a nivel de módulo: una sola llamada a la vez por pestaña, y lo
// tienen a la mano los eventos de ActionCable y el aviso al cerrar la pestaña.
//
//   entrante  answerIncoming: micrófono → setRemote(offer) → createAnswer → POST accept
//   saliente  startOutbound:  micrófono → createOffer → POST initiate; el SDP de Meta
//             llega después por ActionCable (applyOutboundAnswer). Puede llegar ANTES
//             de que initiate responda: se guarda por id y se aplica al saber el id.
//   colgar    hangup → POST terminate; al cerrar la pestaña, fetch keepalive.
// ============================================================================
import Cookies from 'js-cookie';
import WhatsappCallsAPI from 'dashboard/api/whatsappCalls';

const DEFAULT_ICE = [{ urls: 'stun:stun.l.google.com:19302' }];
const ICE_WAIT_MS = 10000;

let pc = null;
let localStream = null;
let remoteAudio = null;
let activeCallId = null;
const pendingAnswers = new Map();

const waitForIce = peer =>
  new Promise(resolve => {
    if (peer.iceGatheringState === 'complete') {
      resolve();
      return;
    }
    const timer = setTimeout(resolve, ICE_WAIT_MS);
    peer.addEventListener('icegatheringstatechange', () => {
      if (peer.iceGatheringState === 'complete') {
        clearTimeout(timer);
        resolve();
      }
    });
  });

const ensureRemoteAudio = () => {
  if (remoteAudio) return remoteAudio;
  remoteAudio = document.createElement('audio');
  remoteAudio.autoplay = true;
  remoteAudio.style.display = 'none';
  document.body.appendChild(remoteAudio);
  return remoteAudio;
};

const buildPeer = async iceServers => {
  localStream = await navigator.mediaDevices.getUserMedia({ audio: true });
  pc = new RTCPeerConnection({
    iceServers: iceServers && iceServers.length ? iceServers : DEFAULT_ICE,
  });
  localStream.getTracks().forEach(track => pc.addTrack(track, localStream));
  pc.ontrack = event => {
    const audio = ensureRemoteAudio();
    [audio.srcObject] = event.streams;
    audio.play().catch(() => {});
  };
};

export const cleanup = () => {
  if (localStream) localStream.getTracks().forEach(track => track.stop());
  if (pc) pc.close();
  if (remoteAudio) remoteAudio.srcObject = null;
  pc = null;
  localStream = null;
  activeCallId = null;
  pendingAnswers.clear();
};

export const hasActiveCall = () => Boolean(activeCallId || pc);

// Devuelve la llamada (push_event_data). Un 409 (otro contestó / ya colgó) se propaga.
export const answerIncoming = async call => {
  try {
    await buildPeer(call.ice_servers);
    await pc.setRemoteDescription({ type: 'offer', sdp: call.sdp_offer });
    await pc.setLocalDescription(await pc.createAnswer());
    await waitForIce(pc);
    activeCallId = call.id;
    const { data } = await WhatsappCallsAPI.accept(call.id, pc.localDescription.sdp);
    return data;
  } catch (error) {
    cleanup();
    throw error;
  }
};

// { call } si Meta aceptó llamar; { permission } si hubo que pedir permiso (422).
export const startOutbound = async conversationId => {
  try {
    await buildPeer(DEFAULT_ICE);
    await pc.setLocalDescription(await pc.createOffer());
    await waitForIce(pc);
    const { data } = await WhatsappCallsAPI.initiate(
      conversationId,
      pc.localDescription.sdp
    );
    activeCallId = data.id;
    if (pendingAnswers.has(data.id)) {
      await pc.setRemoteDescription({ type: 'answer', sdp: pendingAnswers.get(data.id) });
      pendingAnswers.delete(data.id);
    }
    return { call: data };
  } catch (error) {
    cleanup();
    const respuesta = error && error.response && error.response.data;
    if (respuesta && respuesta.status) return { permission: respuesta };
    throw error;
  }
};

export const applyOutboundAnswer = async ({ id, sdp_answer: sdpAnswer }) => {
  if (!sdpAnswer) return;
  if (pc && activeCallId === id) {
    await pc.setRemoteDescription({ type: 'answer', sdp: sdpAnswer });
  } else {
    pendingAnswers.set(id, sdpAnswer);
  }
};

export const hangup = async () => {
  const callId = activeCallId;
  cleanup();
  if (callId) await WhatsappCallsAPI.terminate(callId);
};

export const isActiveCall = callId => activeCallId === callId;

// Devuelve si quedó en silencio.
export const toggleMute = () => {
  if (!localStream) return false;
  const [track] = localStream.getAudioTracks();
  if (!track) return false;
  track.enabled = !track.enabled;
  return !track.enabled;
};

// Al cerrar la pestaña a media llamada: fetch con keepalive y los encabezados de
// sesión (sendBeacon no puede mandarlos). Sin esto Meta la deja viva ~60 s.
const terminateOnUnload = () => {
  if (!activeCallId) return;
  try {
    const sesion = JSON.parse(Cookies.get('cw_d_session_info') || '{}');
    const accountId = window.location.pathname.split('/')[3];
    fetch(`/api/v1/accounts/${accountId}/whatsapp_calls/${activeCallId}/terminate`, {
      method: 'POST',
      keepalive: true,
      headers: {
        'Content-Type': 'application/json',
        'access-token': sesion['access-token'] || '',
        client: sesion.client || '',
        uid: sesion.uid || '',
        expiry: sesion.expiry || '',
        'token-type': 'Bearer',
      },
      body: '{}',
    }).catch(() => {});
  } catch (error) {
    // nada que hacer al cerrar
  }
};

if (typeof window !== 'undefined') {
  window.addEventListener('pagehide', terminateOnUnload);
}
