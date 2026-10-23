<script>
// diag/llamadas_whatsapp (F4) — CLIENTE SIMULADO
// ============================================================================
// Hace lo que haría el celular del cliente, para probar llamadas sin número:
//   llamar al negocio · colgar · contestar/rechazar cuando el negocio llama ·
//   responder «Permitir llamadas».
// El servidor arma el mismo webhook que mandaría Meta (camino real). De vuelta, lo
// que el negocio le manda (answer, fin, llamada entrante, solicitud de permiso) se
// recoge cada segundo (signals). El audio es WebRTC real con la pestaña del agente:
// un tono de prueba o el micrófono.
// Solo con WHATSAPP_CALLS_SIMULATOR=true en el servidor (si no, 404).
// Plan: docs/llamadas_whatsapp_plan.md §4.6
// ============================================================================
import BaseSettingsHeader from 'dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue';
import SimulatorAPI from 'dashboard/api/whatsappCallSimulator';

const STUN = [{ urls: 'stun:stun.l.google.com:19302' }];
const ICE_WAIT_MS = 5000;
const POLL_MS = 1000;

const waitForIce = pc =>
  new Promise(resolve => {
    if (pc.iceGatheringState === 'complete') {
      resolve();
      return;
    }
    const timer = setTimeout(resolve, ICE_WAIT_MS);
    pc.addEventListener('icegatheringstatechange', () => {
      if (pc.iceGatheringState === 'complete') {
        clearTimeout(timer);
        resolve();
      }
    });
  });

export default {
  components: { BaseSettingsHeader },
  data() {
    return {
      disabled: false,
      inboxes: [],
      inboxId: null,
      waId: '5215599990000',
      name: 'Cliente de prueba',
      source: 'tone',
      // idle · calling (yo llamé, suena) · ringing (me llaman) · in_call
      state: 'idle',
      callId: null,
      startedAt: null,
      elapsed: 0,
      incoming: null,
      permission: null,
      log: [],
      pc: null,
      localStream: null,
      audioContext: null,
      pollTimer: null,
      clockTimer: null,
    };
  },
  computed: {
    canCall() {
      return this.inboxId && this.waId && this.state === 'idle';
    },
    clock() {
      const m = String(Math.floor(this.elapsed / 60)).padStart(2, '0');
      const s = String(this.elapsed % 60).padStart(2, '0');
      return `${m}:${s}`;
    },
    stateLabel() {
      return this.t(`STATE.${this.state.toUpperCase()}`);
    },
  },
  async mounted() {
    try {
      const { data } = await SimulatorAPI.inboxes();
      this.inboxes = data;
      this.inboxId = data.length ? data[0].id : null;
    } catch (error) {
      this.disabled = true;
      return;
    }
    this.pollTimer = setInterval(this.poll, POLL_MS);
  },
  beforeDestroy() {
    clearInterval(this.pollTimer);
    this.cleanup();
  },
  methods: {
    t(key, args) {
      return this.$t(`WHATSAPP_CALLS.SIMULATOR.${key}`, args);
    },
    note(texto) {
      const hora = new Date().toLocaleTimeString();
      this.log = [`${hora} · ${texto}`, ...this.log].slice(0, 30);
    },
    // ── Audio: un tono de 440 Hz o el micrófono ─────────────────────────────
    async localAudio() {
      if (this.source === 'mic') {
        return navigator.mediaDevices.getUserMedia({ audio: true });
      }
      this.audioContext = new AudioContext();
      const oscilador = this.audioContext.createOscillator();
      const ganancia = this.audioContext.createGain();
      ganancia.gain.value = 0.05;
      const destino = this.audioContext.createMediaStreamDestination();
      oscilador.frequency.value = 440;
      oscilador.connect(ganancia).connect(destino);
      oscilador.start();
      return destino.stream;
    },
    async buildPeer() {
      this.pc = new RTCPeerConnection({ iceServers: STUN });
      this.localStream = await this.localAudio();
      this.localStream
        .getTracks()
        .forEach(track => this.pc.addTrack(track, this.localStream));
      this.pc.ontrack = event => {
        this.$refs.remoteAudio.srcObject = event.streams[0];
        this.$refs.remoteAudio.play().catch(() => {});
      };
    },
    startClock() {
      this.startedAt = Date.now();
      this.elapsed = 0;
      this.clockTimer = setInterval(() => {
        this.elapsed = Math.floor((Date.now() - this.startedAt) / 1000);
      }, 1000);
    },
    cleanup() {
      clearInterval(this.clockTimer);
      if (this.pc) this.pc.close();
      if (this.localStream) this.localStream.getTracks().forEach(t => t.stop());
      if (this.audioContext) this.audioContext.close().catch(() => {});
      this.pc = null;
      this.localStream = null;
      this.audioContext = null;
      this.callId = null;
      this.state = 'idle';
    },
    // ── El cliente llama al negocio ─────────────────────────────────────────
    async callBusiness() {
      await this.buildPeer();
      const offer = await this.pc.createOffer();
      await this.pc.setLocalDescription(offer);
      await waitForIce(this.pc);
      const { data } = await SimulatorAPI.call({
        inboxId: this.inboxId,
        waId: this.waId,
        name: this.name,
        sdpOffer: this.pc.localDescription.sdp,
      });
      this.callId = data.call_id;
      this.state = 'calling';
      this.note(this.t('LOG.CALLING'));
    },
    async hangup() {
      if (this.callId) {
        await SimulatorAPI.hangup({
          inboxId: this.inboxId,
          callId: this.callId,
          duration: this.state === 'in_call' ? this.elapsed : 0,
        });
      }
      this.note(this.t('LOG.HUNG_UP'));
      this.cleanup();
    },
    // ── El negocio llama al cliente ─────────────────────────────────────────
    async answerIncoming() {
      const llamada = this.incoming;
      this.incoming = null;
      await this.buildPeer();
      await this.pc.setRemoteDescription({ type: 'offer', sdp: llamada.sdp });
      const answer = await this.pc.createAnswer();
      await this.pc.setLocalDescription(answer);
      await waitForIce(this.pc);
      await SimulatorAPI.answer({
        inboxId: this.inboxId,
        callId: llamada.call_id,
        sdpAnswer: this.pc.localDescription.sdp,
      });
      this.callId = llamada.call_id;
      this.state = 'in_call';
      this.startClock();
      this.note(this.t('LOG.ANSWERED'));
    },
    async rejectIncoming() {
      await SimulatorAPI.hangup({
        inboxId: this.inboxId,
        callId: this.incoming.call_id,
        duration: 0,
      });
      this.incoming = null;
      this.state = 'idle';
      this.note(this.t('LOG.REJECTED'));
    },
    async replyPermission(accept) {
      await SimulatorAPI.permission({
        inboxId: this.inboxId,
        waId: this.waId,
        wamid: this.permission.wamid,
        accept,
      });
      this.permission = null;
      this.note(accept ? this.t('LOG.ALLOWED') : this.t('LOG.DENIED'));
    },
    // ── Lo que manda el negocio ──────────────────────────────────────────────
    async poll() {
      if (!this.inboxId || !this.waId) return;
      try {
        const { data } = await SimulatorAPI.signals(this.inboxId, this.waId);
        await data.reduce(
          (anterior, senal) => anterior.then(() => this.handle(senal)),
          Promise.resolve()
        );
      } catch (error) {
        // se reintenta en el siguiente ciclo
      }
    },
    async handle(senal) {
      if (senal.type === 'answer' && this.pc && senal.call_id === this.callId) {
        await this.pc.setRemoteDescription({ type: 'answer', sdp: senal.sdp });
        this.state = 'in_call';
        this.startClock();
        this.note(this.t('LOG.AGENT_ANSWERED'));
      } else if (senal.type === 'ended' && senal.call_id === this.callId) {
        this.note(this.t('LOG.AGENT_ENDED', { reason: senal.reason }));
        this.cleanup();
      } else if (senal.type === 'incoming') {
        this.incoming = senal;
        this.state = 'ringing';
        this.note(this.t('LOG.BUSINESS_CALLING'));
      } else if (senal.type === 'permission_request') {
        this.permission = senal;
        this.note(this.t('LOG.PERMISSION_ASKED'));
      }
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col w-full h-full p-6 overflow-auto bg-white sm:py-8 lg:px-16 dark:bg-slate-900 font-inter"
  >
    <div class="flex flex-col w-full max-w-3xl mx-auto">
      <BaseSettingsHeader :title="t('TITLE')" :description="t('DESCRIPTION')" />

      <p
        v-if="disabled"
        class="p-4 mt-6 text-base rounded-md text-amber-800 bg-amber-50 dark:bg-amber-900/30 dark:text-amber-300"
      >
        {{ t('DISABLED') }}
      </p>

      <template v-else>
        <p
          v-if="!inboxes.length"
          class="mt-6 text-base text-slate-600 dark:text-slate-300"
        >
          {{ t('NO_INBOXES') }}
        </p>

        <div class="grid gap-4 mt-6 sm:grid-cols-2">
          <label>
            {{ t('INBOX') }}
            <select
              v-model="inboxId"
              class="!mb-0"
              :disabled="state !== 'idle'"
            >
              <option
                v-for="inbox in inboxes"
                :key="inbox.id"
                :value="inbox.id"
              >
                {{ inbox.name }} · {{ inbox.phone_number }}
              </option>
            </select>
          </label>
          <label>
            {{ t('SOURCE') }}
            <select v-model="source" class="!mb-0" :disabled="state !== 'idle'">
              <option value="tone">{{ t('SOURCE_TONE') }}</option>
              <option value="mic">{{ t('SOURCE_MIC') }}</option>
            </select>
          </label>
          <label>
            {{ t('WA_ID') }}
            <input
              v-model.trim="waId"
              type="text"
              class="!mb-0"
              :disabled="state !== 'idle'"
            />
          </label>
          <label>
            {{ t('NAME') }}
            <input
              v-model="name"
              type="text"
              class="!mb-0"
              :disabled="state !== 'idle'"
            />
          </label>
        </div>

        <div class="flex flex-wrap items-center gap-3 mt-6">
          <woot-label
            small
            color-scheme="secondary"
            :title="stateLabel"
            class="!mb-0"
          />
          <span v-if="state === 'in_call'" class="font-mono text-base">{{
            clock
          }}</span>
          <woot-button
            v-if="state === 'idle'"
            icon="call"
            color-scheme="success"
            :is-disabled="!canCall"
            @click="callBusiness"
          >
            {{ t('CALL') }}
          </woot-button>
          <woot-button
            v-if="state === 'calling' || state === 'in_call'"
            icon="dismiss-circle"
            color-scheme="alert"
            @click="hangup"
          >
            {{ t('HANG_UP') }}
          </woot-button>
        </div>

        <div
          v-if="incoming"
          class="p-4 mt-6 border rounded-md border-woot-200 bg-woot-25 dark:bg-woot-900/30 dark:border-woot-800"
        >
          <p class="mb-3 text-base font-semibold">
            {{ t('BUSINESS_CALLING') }}
          </p>
          <div class="flex gap-2">
            <woot-button
              icon="call"
              color-scheme="success"
              @click="answerIncoming"
            >
              {{ t('ANSWER') }}
            </woot-button>
            <woot-button
              icon="dismiss-circle"
              color-scheme="alert"
              variant="smooth"
              @click="rejectIncoming"
            >
              {{ t('REJECT') }}
            </woot-button>
          </div>
        </div>

        <div
          v-if="permission"
          class="p-4 mt-6 border rounded-md border-slate-100 dark:border-slate-700"
        >
          <p class="mb-1 text-sm text-slate-500 dark:text-slate-400">
            {{ t('PERMISSION_TITLE') }}
          </p>
          <p class="mb-3 text-base">{{ permission.text }}</p>
          <div class="flex gap-2">
            <woot-button color-scheme="success" @click="replyPermission(true)">
              {{ t('ALLOW') }}
            </woot-button>
            <woot-button
              color-scheme="secondary"
              variant="smooth"
              @click="replyPermission(false)"
            >
              {{ t('DENY') }}
            </woot-button>
          </div>
        </div>

        <h3
          class="mt-8 mb-2 text-base font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ t('LOG_TITLE') }}
        </h3>
        <ul class="text-sm text-slate-600 dark:text-slate-300">
          <li v-for="(linea, i) in log" :key="i">{{ linea }}</li>
          <li v-if="!log.length" class="text-slate-400">
            {{ t('LOG_EMPTY') }}
          </li>
        </ul>
      </template>

      <audio ref="remoteAudio" autoplay class="hidden" />
    </div>
  </div>
</template>
