<script>
// diag/llamadas_whatsapp (F5) — LA VENTANA DE LLAMADA DE WHATSAPP
// ============================================================================
// Flota sobre el dashboard (arrastrable, como la del webphone de Wavoip; las dos
// conviven: esa solo aparece con una llamada de Wavoip). Se monta una vez en App.vue.
//   sonando    quién llama + bandeja · Contestar / Rechazar · timbre en bucle (el tono
//              que eligió la bandeja: helper/whatsappCallRingtone.js)
//   en curso   cronómetro · Silenciar · Colgar · ir a la conversación
//   saliente   «Conectando…» → «Sonando…» → en curso · Colgar
//   grabando   (F7, P1) punto rojo y el guion para que el agente avise en voz; al
//              cliente además le llega el aviso por WhatsApp (Voice::RecordingNoticeService)
// Los avisos del store (notice) se muestran aquí, que es donde hay $t.
// ============================================================================
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import Draggable from 'dashboard/components/layout/webphoneComponents/Draggable.vue';
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import {
  createRingtone,
  DEFAULT_RINGTONE,
} from 'dashboard/helper/whatsappCallRingtone';

export default {
  components: { Draggable, Thumbnail },
  data() {
    return { now: Date.now(), clockTimer: null, ringtone: null };
  },
  computed: {
    ...mapGetters({
      incoming: 'whatsappCalls/getIncoming',
      active: 'whatsappCalls/getActive',
      isBusy: 'whatsappCalls/isBusy',
      notice: 'whatsappCalls/getNotice',
      accountId: 'getCurrentAccountId',
      getInbox: 'inboxes/getInbox',
    }),
    call() {
      return this.active || this.incoming;
    },
    caller() {
      return (this.call && this.call.caller) || {};
    },
    callerName() {
      return this.caller.name || this.caller.phone || this.t('UNKNOWN');
    },
    inbox() {
      return (
        (this.call && this.getInbox(this.call.inbox_id || this.call.inboxId)) ||
        {}
      );
    },
    inboxName() {
      return this.inbox.name || '';
    },
    ringtoneName() {
      const llamadas = this.inbox.whatsapp_calls || {};
      return llamadas.ringtone || DEFAULT_RINGTONE;
    },
    isRinging() {
      return Boolean(this.incoming) && !this.active;
    },
    statusText() {
      if (this.isRinging) return this.t('INCOMING');
      if (this.active.status === 'connecting') return this.t('CONNECTING');
      if (this.active.status === 'ringing') return this.t('RINGING');
      return this.clock;
    },
    clock() {
      if (!this.active || !this.active.startedAt) return '00:00';
      const segundos = Math.max(
        0,
        Math.floor((this.now - this.active.startedAt) / 1000)
      );
      const m = String(Math.floor(segundos / 60)).padStart(2, '0');
      return `${m}:${String(segundos % 60).padStart(2, '0')}`;
    },
    isRecording() {
      return Boolean(
        this.active &&
          this.active.recording &&
          this.active.status === 'in_progress'
      );
    },
    conversationLink() {
      const id =
        this.call && (this.call.conversationId || this.call.conversation_id);
      return id
        ? frontendURL(conversationUrl({ accountId: this.accountId, id }))
        : '';
    },
  },
  watch: {
    isRinging: {
      immediate: true,
      handler(sonando) {
        if (sonando) this.startRingtone();
        else this.stopRingtone();
      },
    },
    notice(aviso) {
      if (aviso) useAlert(this.$t(aviso.key, aviso.args));
    },
  },
  mounted() {
    this.clockTimer = setInterval(() => {
      this.now = Date.now();
    }, 1000);
  },
  beforeDestroy() {
    clearInterval(this.clockTimer);
    this.stopRingtone();
  },
  methods: {
    t(key, args) {
      return this.$t(`WHATSAPP_CALLS.WIDGET.${key}`, args);
    },
    startRingtone() {
      this.stopRingtone();
      this.ringtone = createRingtone(this.ringtoneName);
      this.ringtone.start();
    },
    stopRingtone() {
      if (this.ringtone) this.ringtone.stop();
      this.ringtone = null;
    },
    answer() {
      this.$store.dispatch('whatsappCalls/answer');
    },
    reject() {
      this.$store.dispatch('whatsappCalls/reject');
    },
    hangup() {
      this.$store.dispatch('whatsappCalls/hangup');
    },
    toggleMute() {
      this.$store.dispatch('whatsappCalls/toggleMute');
    },
    openConversation() {
      if (this.conversationLink) this.$router.push(this.conversationLink);
    },
  },
};
</script>

<template>
  <Draggable v-if="call" :initial-x="60" :initial-y="80">
    <div
      class="flex flex-col items-center w-64 gap-3 p-4 bg-white border shadow-lg rounded-xl dark:bg-slate-900 border-slate-100 dark:border-slate-700"
    >
      <div
        class="flex items-center justify-between w-full text-xs text-slate-500 dark:text-slate-400"
      >
        <span class="truncate">{{ t('TITLE') }}</span>
        <span v-if="inboxName" class="truncate">{{ inboxName }}</span>
      </div>
      <Thumbnail
        :src="caller.avatar || ''"
        :username="callerName"
        size="56px"
      />
      <div class="w-full text-center">
        <p
          class="mb-0 text-base font-semibold truncate text-slate-800 dark:text-slate-100"
        >
          {{ callerName }}
        </p>
        <p
          v-if="caller.phone && caller.name"
          class="mb-0 text-sm text-slate-500 dark:text-slate-400"
        >
          {{ caller.phone }}
        </p>
        <p
          class="mt-1 mb-0 font-mono text-sm text-slate-600 dark:text-slate-300"
        >
          {{ statusText }}
        </p>
      </div>

      <div
        v-if="isRecording"
        class="w-full p-2 text-xs rounded-md bg-red-50 dark:bg-red-900/30 text-red-800 dark:text-red-200"
      >
        <p class="flex items-center gap-1 mb-1 font-semibold">
          <span
            class="inline-block w-2 h-2 bg-red-600 rounded-full animate-pulse"
          />
          {{ t('RECORDING') }}
        </p>
        <p class="mb-0">{{ t('RECORDING_SCRIPT') }}</p>
      </div>

      <div v-if="isRinging" class="flex w-full gap-2">
        <woot-button
          class="flex-1"
          icon="call"
          color-scheme="success"
          :is-loading="isBusy"
          @click="answer"
        >
          {{ t('ANSWER') }}
        </woot-button>
        <woot-button
          class="flex-1"
          icon="dismiss-circle"
          color-scheme="alert"
          variant="smooth"
          :is-disabled="isBusy"
          @click="reject"
        >
          {{ t('REJECT') }}
        </woot-button>
      </div>

      <div v-else class="flex flex-wrap justify-center w-full gap-2">
        <woot-button
          v-if="active.status === 'in_progress'"
          v-tooltip.top="active.muted ? t('UNMUTE') : t('MUTE')"
          :icon="active.muted ? 'microphone-off' : 'microphone'"
          :color-scheme="active.muted ? 'warning' : 'secondary'"
          variant="smooth"
          @click="toggleMute"
        />
        <woot-button
          v-if="conversationLink"
          v-tooltip.top="t('OPEN_CONVERSATION')"
          icon="chat"
          color-scheme="secondary"
          variant="smooth"
          @click="openConversation"
        />
        <woot-button icon="dismiss-circle" color-scheme="alert" @click="hangup">
          {{ t('HANG_UP') }}
        </woot-button>
      </div>
    </div>
  </Draggable>
</template>
