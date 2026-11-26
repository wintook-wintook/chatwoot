<!--
  diag/waba F3 — «Reconectar con Meta» para una bandeja de WhatsApp Cloud que ya existe.
  Abre la ventana oficial de Meta; el servidor guarda el token nuevo en la MISMA bandeja (rechaza
  otro número), vuelve a suscribir y quita la marca de reconexión. Conversaciones, contactos,
  plantillas y agentes no se tocan.
    variant="banner"  aviso rojo arriba de la bandeja cuando Meta rechazó su permiso
    variant="button"  botón (pestaña Diagnóstico)
  appBroken: la app de Meta del sistema está mal configurada → el botón no sirve y lo dice.
-->
<script>
import { useAlert } from 'dashboard/composables';
import Banner from 'dashboard/components/ui/Banner.vue';
import WhatsappChannel from 'dashboard/api/channel/whatsappChannel';
import embeddedSignupMixin from './embeddedSignupMixin';

const T = 'WHATSAPP_HEALTH.RECONNECT';

export default {
  name: 'WhatsappReauthorize',
  components: { Banner },
  mixins: [embeddedSignupMixin],
  props: {
    inbox: { type: Object, required: true },
    variant: { type: String, default: 'button' },
    appBroken: { type: Boolean, default: false },
  },
  emits: ['reconnected'],
  data() {
    return { saving: false };
  },
  computed: {
    disabledReason() {
      if (this.appBroken || !this.signupAvailable) {
        return this.t('APP_BROKEN');
      }
      return '';
    },
    busy() {
      return this.saving || this.signupOpen;
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    start() {
      if (this.disabledReason) {
        useAlert(this.disabledReason);
        return;
      }
      if (!this.openSignup()) useAlert(this.t('SDK_NOT_LOADED'));
    },
    async onSignupComplete(payload) {
      this.saving = true;
      try {
        await WhatsappChannel.createEmbeddedSignup({
          ...payload,
          inbox_id: this.inbox.id,
        });
        useAlert(this.t('DONE'));
        this.$store.dispatch('inboxes/get');
        this.$emit('reconnected');
      } catch (error) {
        useAlert(error?.response?.data?.error || this.t('ERROR'));
      } finally {
        this.saving = false;
      }
    },
    onSignupCancel(message) {
      useAlert(message || this.t('CANCELLED'));
    },
  },
};
</script>

<template>
  <Banner
    v-if="variant === 'banner'"
    color-scheme="alert"
    class="justify-start mx-8 mt-5 rounded-md"
    :banner-message="t('BANNER')"
    :action-button-label="t('BUTTON')"
    has-action-button
    data-test="whatsapp-reconnect-banner"
    @click="start"
  />
  <span v-else class="inline-flex flex-col items-end gap-1">
    <woot-button
      size="small"
      variant="smooth"
      :is-loading="busy"
      :disabled="!!disabledReason"
      :title="disabledReason"
      data-test="whatsapp-reconnect"
      @click="start"
    >
      {{ t('BUTTON') }}
    </woot-button>
    <span
      class="max-w-[16rem] text-xs text-right text-slate-500 dark:text-slate-400"
    >
      {{ disabledReason || t('HINT') }}
    </span>
  </span>
</template>
