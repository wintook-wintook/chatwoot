<script>
// feat/ficha_agente_ia — CANAL Y SEGUIMIENTO (antes de las fuentes)
// ============================================================================
// Pedido del usuario (10/11/2026): el canal y el seguimiento se piden ANTES de las
// fuentes, porque con WhatsApp hay que elegir la plantilla de cada intento. Lo mismo que
// la Ficha › Agente seguimiento:
//   Canal*  ·  Tiempo entre intentos · Intervalo · Núm. intentos
//   WhatsApp: plantilla por intento (obligatoria)  ·  Correo: firma
// Los canales: las bandejas con el bot de seguimiento activo (como EditTemplate).
// v-model: { inboxId, retryValue, retryUnit, attempts, whatsappTemplates: [], emailSignature }
// ============================================================================
import { mapGetters } from 'vuex';

const UNITS = ['minutes', 'hours', 'days'];
const MAX_ATTEMPTS = 6;

// Las bandejas con el bot de seguimiento activo (la misma regla que la Ficha).
export const trackingChannels = (appIntegrations, inboxes) => {
  const app = (appIntegrations || []).find(item => item.id === 'tracking_bot');
  if (!app || !app.enabled) return [];
  return (app.hooks || [])
    .filter(hook => hook.status === true && hook.inbox && hook.inbox.id)
    .map(hook => {
      const inbox = (inboxes || []).find(
        item => item.id === Number(hook.inbox.id)
      );
      return {
        id: Number(hook.inbox.id),
        name: inbox ? inbox.name : hook.inbox.name,
        channelType: inbox ? inbox.channel_type : null,
      };
    });
};

export const channelKind = inbox => {
  const tipo = (inbox && inbox.channelType) || '';
  if (/whatsapp/i.test(tipo)) return 'whatsapp';
  if (tipo === 'Channel::Email') return 'email';
  return 'other';
};

export default {
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Object, required: true },
  },
  emits: ['input'],
  data() {
    return { units: UNITS, maxAttempts: MAX_ATTEMPTS };
  },
  computed: {
    ...mapGetters({
      appIntegrations: 'integrations/getAppIntegrations',
      inboxes: 'inboxes/getInboxes',
    }),
    channels() {
      return trackingChannels(this.appIntegrations, this.inboxes);
    },
    selected() {
      return this.channels.find(item => item.id === Number(this.value.inboxId));
    },
    kind() {
      return channelKind(this.selected);
    },
    waTemplates() {
      if (this.kind !== 'whatsapp') return [];
      const lista =
        this.$store.getters['inboxes/getWhatsAppTemplates'](
          Number(this.value.inboxId)
        ) || [];
      return lista.map(item => ({ name: item.name, language: item.language }));
    },
    attemptList() {
      return Array.from({ length: this.value.attempts || 1 }, (_, i) => i);
    },
    missingTemplates() {
      return (
        this.kind === 'whatsapp' &&
        this.attemptList.some(i => !(this.value.whatsappTemplates || [])[i])
      );
    },
  },
  async mounted() {
    if (!this.appIntegrations || !this.appIntegrations.length)
      await this.$store.dispatch('integrations/get');
  },
  methods: {
    t(key, args) {
      return this.$t(`TRACKING_TEMPLATES.FICHA.${key}`, args);
    },
    set(campo, valor) {
      this.$emit('input', { ...this.value, [campo]: valor });
    },
    setAttempts(valor) {
      const n = Math.min(MAX_ATTEMPTS, Math.max(1, Number(valor) || 1));
      const plantillas = (this.value.whatsappTemplates || []).slice(0, n);
      this.$emit('input', {
        ...this.value,
        attempts: n,
        whatsappTemplates: plantillas,
      });
    },
    setTemplate(indice, nombre) {
      const plantillas = [...(this.value.whatsappTemplates || [])];
      plantillas[indice] = nombre;
      this.set('whatsappTemplates', plantillas);
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <p class="!m-0 text-sm text-slate-600 dark:text-slate-300">
      {{ t('CHANNEL_HINT') }}
    </p>
    <p
      v-if="!channels.length"
      class="!m-0 px-3 py-2 text-sm rounded-lg bg-amber-50 text-amber-800 dark:bg-amber-900/30 dark:text-amber-200"
    >
      {{ t('CHANNEL_NONE') }}
    </p>
    <div class="grid gap-3 sm:grid-cols-3">
      <label class="!m-0 sm:col-span-3">
        {{ t('INBOX') }}
        <span class="text-red-500">{{ t('REQUIRED_MARK') }}</span>
        <select
          class="!mb-0"
          :value="value.inboxId || ''"
          @change="set('inboxId', $event.target.value)"
        >
          <option value="">{{ t('INBOX_CHOOSE') }}</option>
          <option v-for="item in channels" :key="item.id" :value="item.id">
            {{ item.name }}
          </option>
        </select>
      </label>
      <label class="!m-0">
        {{ t('RETRY_VALUE') }}
        <input
          type="number"
          min="1"
          class="!mb-0"
          :value="value.retryValue"
          @input="set('retryValue', Number($event.target.value) || 1)"
        />
      </label>
      <label class="!m-0">
        {{ t('RETRY_UNIT') }}
        <select
          class="!mb-0"
          :value="value.retryUnit"
          @change="set('retryUnit', $event.target.value)"
        >
          <option v-for="unidad in units" :key="unidad" :value="unidad">
            {{ t(`UNIT_${unidad.toUpperCase()}`) }}
          </option>
        </select>
      </label>
      <label class="!m-0">
        {{ t('ATTEMPTS') }}
        <input
          type="number"
          min="1"
          :max="maxAttempts"
          class="!mb-0"
          :value="value.attempts"
          @input="setAttempts($event.target.value)"
        />
      </label>
    </div>

    <!-- WhatsApp: una plantilla por intento (la ventana de 24 h la exige) -->
    <div v-if="kind === 'whatsapp'" class="flex flex-col gap-2">
      <span class="text-sm text-slate-800 dark:text-slate-100">
        {{ t('WA_TEMPLATES') }}
      </span>
      <p v-if="!waTemplates.length" class="!m-0 text-xs text-amber-800">
        {{ t('WA_NONE') }}
      </p>
      <template v-else>
        <div
          v-for="indice in attemptList"
          :key="indice"
          class="flex items-center gap-2"
        >
          <span
            class="w-24 text-sm shrink-0 text-slate-600 dark:text-slate-300"
          >
            {{ t('ATTEMPT_N', { n: indice + 1 }) }}
          </span>
          <select
            class="!mb-0"
            :value="(value.whatsappTemplates || [])[indice] || ''"
            @change="setTemplate(indice, $event.target.value)"
          >
            <option value="">{{ t('WA_CHOOSE') }}</option>
            <option
              v-for="plantilla in waTemplates"
              :key="`${plantilla.name}-${plantilla.language}`"
              :value="plantilla.name"
            >
              {{ plantilla.name }} ({{ plantilla.language }})
            </option>
          </select>
        </div>
      </template>
      <p v-if="missingTemplates" class="!m-0 text-xs text-red-600">
        {{ t('WA_MISSING') }}
      </p>
    </div>

    <label v-if="kind === 'email'" class="!m-0">
      {{ t('EMAIL_SIGNATURE') }}
      <textarea
        rows="3"
        maxlength="500"
        class="!mb-0"
        :value="value.emailSignature"
        @input="set('emailSignature', $event.target.value)"
      />
    </label>
  </div>
</template>
