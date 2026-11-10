<!--
  Perfil › «Usar Dali en mi teléfono» — un QR con un enlace de un solo uso (5 min)
  que entra ya firmado al portal de Dali de esta empresa (assistant/mobile_link).
  Sin QR: abrir /dali en el teléfono y entrar con correo y contraseña.
-->
<script>
import QRCode from 'qrcode';
import AssistantAPI from 'dashboard/api/platformAssistant';

const T = 'ASSISTANT.PORTAL.PHONE';

export default {
  name: 'DaliOnPhone',
  data() {
    return { qr: '', secondsLeft: 0, loading: false, error: '' };
  },
  computed: {
    shortUrl() {
      return `${window.location.host}/dali`;
    },
    countdown() {
      const m = Math.floor(this.secondsLeft / 60);
      const s = String(this.secondsLeft % 60).padStart(2, '0');
      return `${m}:${s}`;
    },
  },
  beforeDestroy() {
    this.stopTimer();
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    async show() {
      this.loading = true;
      this.error = '';
      try {
        const { data } = await AssistantAPI.mobileLink();
        this.qr = await QRCode.toDataURL(data.url, { width: 220, margin: 1 });
        this.secondsLeft = data.expires_in;
        this.stopTimer();
        this.timer = setInterval(this.tick, 1000);
      } catch (_e) {
        this.error = this.t('ERROR');
      } finally {
        this.loading = false;
      }
    },
    tick() {
      this.secondsLeft -= 1;
      if (this.secondsLeft <= 0) {
        this.stopTimer();
        this.qr = '';
      }
    },
    stopTimer() {
      if (this.timer) clearInterval(this.timer);
      this.timer = null;
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3 sm:flex-row sm:items-start">
    <div v-if="qr" class="flex flex-col items-center gap-1 shrink-0">
      <img
        :src="qr"
        :alt="t('QR_ALT')"
        width="220"
        height="220"
        class="bg-white border rounded-lg border-slate-100"
      />
      <span class="text-xs text-slate-500">
        {{ t('EXPIRES', { time: countdown }) }}
      </span>
    </div>
    <div class="flex flex-col gap-2 text-sm text-slate-600 dark:text-slate-300">
      <p v-if="qr" class="m-0">{{ t('SCAN') }}</p>
      <p class="m-0">{{ t('OR_URL', { url: shortUrl }) }}</p>
      <p class="m-0">{{ t('INSTALL_HINT') }}</p>
      <div>
        <woot-button
          :is-loading="loading"
          variant="smooth"
          size="small"
          @click="show"
        >
          {{ qr ? t('AGAIN') : t('SHOW') }}
        </woot-button>
      </div>
      <p v-if="error" class="m-0 text-xs text-red-600">{{ error }}</p>
    </div>
  </div>
</template>
