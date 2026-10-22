// diag/llamadas_whatsapp (F5) — EL AUDIO DE UNA LLAMADA DE WHATSAPP EN EL NAVEGADOR
// ============================================================================
// Portado de la v4.19 (dashboard/composables/useWhatsappCallSession.js). El audio va directo del navegador a Meta (WebRTC); el servidor solo
// pasa el SDP. Estado a nivel de módulo: una sola llamada a la vez por pestaña, y lo
// tienen a la mano los eventos de ActionCable y el aviso al cerrar la pestaña.
//
//   entrante  answerIncoming: micrófono → setRemote(offer) → createAnswer → POST accept
//   saliente  startOutbound:  micrófono → createOffer → POST initiate; el SDP de Meta
//             llega después por ActionCable (applyOutboundAnswer). Puede llegar ANTES
//             de que initiate responda: se guarda por id y se aplica al saber el id.
//   colgar    hangup → POST terminate; al cerrar la pestaña, fetch keepalive.
//   grabar    (F7) solo si la llamada trae recording_enabled. Mezcla micrófono + voz
//             del cliente y la graba (Opus 48 kbps). Entrante: desde que el agente
//             contesta. Saliente: desde que el cliente contesta (armRecorder, con el
//             ACCEPTED de Meta), para no grabar el timbre. Al colgar —de cualquier
//             lado— se pasa a OGG y se sube (finishCall); si falla, se pierde.
// ============================================================================
import Cookies from 'js-cookie';
import WhatsappCallsAPI from 'dashboard/api/whatsappCalls';
import { remuxWebmToOgg } from 'dashboard/components/widgets/WootWriter/utils/webmOpusToOgg';

const DEFAULT_ICE = [{ urls: 'stun:stun.l.google.com:19302' }];
const ICE_WAIT_MS = 10000;
// Un pedazo por segundo: si el cliente cuelga de golpe, ya hay audio en memoria.
const RECORDING_TIMESLICE_MS = 1000;
// Pasar a OGG es en memoria; arriba de esto (~3 h a 48 kbps) se sube el WebM tal cual.
const MAX_REMUX_BYTES = 64 * 1024 * 1024;
const RECORDER_MIME_CANDIDATES = [
  'audio/webm;codecs=opus',
  'audio/webm',
  'audio/ogg;codecs=opus',
];

let pc = null;
let localStream = null;
let remoteStream = null;
let remoteAudio = null;
let activeCallId = null;
const pendingAnswers = new Map();

let recordingEnabled = false;
let recorderArmed = false;
let mediaRecorder = null;
let recorderChunks = [];
let audioContext = null;

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

const setupRecorder = () => {
  if (!recordingEnabled || !recorderArmed || mediaRecorder) return;
  if (!localStream || !remoteStream || !window.MediaRecorder) return;
  // Sin la pista del cliente la mezcla sería silencio: se espera a ontrack.
  if (remoteStream.getAudioTracks().length === 0) return;
  const mimeType = RECORDER_MIME_CANDIDATES.find(tipo =>
    window.MediaRecorder.isTypeSupported(tipo)
  );
  if (!mimeType) return;

  audioContext = new AudioContext({ sampleRate: 48000 });
  // Arranca suspendido por las reglas de autoplay: sin resume() graba silencio.
  audioContext.resume().catch(() => {});
  const destino = audioContext.createMediaStreamDestination();
  audioContext.createMediaStreamSource(localStream).connect(destino);
  audioContext.createMediaStreamSource(remoteStream).connect(destino);

  recorderChunks = [];
  mediaRecorder = new window.MediaRecorder(destino.stream, {
    mimeType,
    audioBitsPerSecond: 48000,
  });
  mediaRecorder.ondataavailable = event => {
    if (event.data && event.data.size > 0) recorderChunks.push(event.data);
  };
  mediaRecorder.start(RECORDING_TIMESLICE_MS);
};

const buildPeer = async iceServers => {
  localStream = await navigator.mediaDevices.getUserMedia({ audio: true });
  pc = new RTCPeerConnection({
    iceServers: iceServers && iceServers.length ? iceServers : DEFAULT_ICE,
  });
  remoteStream = new MediaStream();
  localStream.getTracks().forEach(track => pc.addTrack(track, localStream));
  pc.ontrack = event => {
    // El mismo MediaStream siempre: la grabación ya lo está escuchando.
    const pistas =
      event.streams && event.streams[0]
        ? event.streams[0].getTracks()
        : [event.track];
    pistas.forEach(pista => {
      if (!remoteStream.getTracks().includes(pista))
        remoteStream.addTrack(pista);
    });
    const audio = ensureRemoteAudio();
    audio.srcObject = remoteStream;
    audio.play().catch(() => {});
    setupRecorder();
  };
};

// Detiene la grabación y devuelve lo grabado (o null), sin subirlo.
const stopRecorder = async () => {
  if (mediaRecorder && mediaRecorder.state !== 'inactive') {
    await new Promise(resolve => {
      mediaRecorder.addEventListener('stop', resolve, { once: true });
      try {
        mediaRecorder.stop();
      } catch (error) {
        resolve();
      }
    });
  }
  if (!recorderChunks.length) return null;
  return new Blob(recorderChunks, { type: recorderChunks[0].type });
};

export const uploadRecording = async (callId, grabacion) => {
  if (!callId || !grabacion) return;
  let archivo = grabacion;
  let nombre = 'llamada.ogg';
  // OGG trae la duración real (el WebM de MediaRecorder no, y falla en celulares).
  if (archivo.type.startsWith('audio/webm')) {
    nombre = 'llamada.webm';
    if (archivo.size <= MAX_REMUX_BYTES) {
      try {
        archivo = await remuxWebmToOgg(archivo);
        nombre = 'llamada.ogg';
      } catch (error) {
        // se sube el WebM tal cual
      }
    }
  }
  try {
    await WhatsappCallsAPI.uploadRecording(callId, archivo, nombre);
  } catch (error) {
    // el servidor es idempotente; si no se pudo, la llamada queda sin audio
  }
};

export const cleanup = () => {
  if (mediaRecorder && mediaRecorder.state !== 'inactive') {
    try {
      mediaRecorder.stop();
    } catch (error) {
      // ya estaba detenida
    }
  }
  if (audioContext && audioContext.state !== 'closed') {
    audioContext.close().catch(() => {});
  }
  if (localStream) localStream.getTracks().forEach(track => track.stop());
  if (remoteStream) remoteStream.getTracks().forEach(track => track.stop());
  if (pc) pc.close();
  if (remoteAudio) remoteAudio.srcObject = null;
  pc = null;
  localStream = null;
  remoteStream = null;
  activeCallId = null;
  pendingAnswers.clear();
  mediaRecorder = null;
  recorderChunks = [];
  audioContext = null;
  recordingEnabled = false;
  recorderArmed = false;
};

// Fin de la llamada sin importar quién colgó: guarda la grabación, limpia y la sube.
export const finishCall = async () => {
  const callId = activeCallId;
  const grabacion = recordingEnabled ? await stopRecorder() : null;
  cleanup();
  await uploadRecording(callId, grabacion);
};

// Saliente: el cliente contestó (ACCEPTED de Meta); desde aquí se graba.
export const armRecorder = callId => {
  if (callId && callId !== activeCallId) return;
  recorderArmed = true;
  setupRecorder();
};

export const isRecording = () => Boolean(mediaRecorder);

export const hasActiveCall = () => Boolean(activeCallId || pc);

// Devuelve la llamada (push_event_data). Un 409 (otro contestó / ya colgó) se propaga.
export const answerIncoming = async call => {
  try {
    recordingEnabled = call.recording_enabled === true;
    // Entrante: se graba desde que el agente contesta (su clic).
    recorderArmed = true;
    await buildPeer(call.ice_servers);
    await pc.setRemoteDescription({ type: 'offer', sdp: call.sdp_offer });
    await pc.setLocalDescription(await pc.createAnswer());
    await waitForIce(pc);
    activeCallId = call.id;
    const { data } = await WhatsappCallsAPI.accept(
      call.id,
      pc.localDescription.sdp
    );
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
    recordingEnabled = data.recording_enabled === true;
    if (pendingAnswers.has(data.id)) {
      await pc.setRemoteDescription({
        type: 'answer',
        sdp: pendingAnswers.get(data.id),
      });
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
  const grabacion = recordingEnabled ? await stopRecorder() : null;
  cleanup();
  if (callId) await WhatsappCallsAPI.terminate(callId);
  await uploadRecording(callId, grabacion);
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
    fetch(
      `/api/v1/accounts/${accountId}/whatsapp_calls/${activeCallId}/terminate`,
      {
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
      }
    ).catch(() => {});
  } catch (error) {
    // nada que hacer al cerrar
  }
};

if (typeof window !== 'undefined') {
  window.addEventListener('pagehide', terminateOnUnload);
}
