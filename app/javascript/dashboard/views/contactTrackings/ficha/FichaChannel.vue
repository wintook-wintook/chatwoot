<script>
// feat/ficha_agente_ia — CANAL Y SEGUIMIENTO (antes de las fuentes)
// ============================================================================
// Pedido del usuario (10/11/2026): el canal y el seguimiento se piden ANTES de las
// fuentes, porque con WhatsApp hay que elegir la plantilla de cada intento. Lo mismo que
// la Ficha › Agente seguimiento:
//   Canal*  ·  Tiempo entre intentos · Intervalo · Núm. intentos
//   WhatsApp: plantilla por intento (obligatoria)  ·  Correo: firma
// Los canales: las bandejas con el bot de seguimiento activo (como EditTemplate).
// v-model: { inboxId, retryValue, retryUnit, attempts, groupSeconds, whatsappTemplates: [], emailSignature }
//
// fix/campanas (punto 3): a la derecha, siempre a la vista, la plantilla del intento
// seleccionado como la verá el cliente (TemplatePreview de Configuración › Plantillas de
// WhatsApp). Se selecciona con clic en el intento o al elegirle plantilla. Sale del módulo
// de plantillas y, si ahí no está, de lo que trae Meta en la bandeja.
// ============================================================================
import { mapGetters } from 'vuex';
import TemplatePreview from 'dashboard/routes/dashboard/settings/whatsappTemplates/TemplatePreview.vue';
import {
  formFromMetaTemplate,
  formFromTemplate,
} from 'dashboard/routes/dashboard/settings/whatsappTemplates/templateEditor';

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
  components: { TemplatePreview },
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Object, required: true },
  },
  emits: ['input'],
  data() {
    // previewIndex: el intento cuya plantilla se ve a la derecha
    return { units: UNITS, maxAttempts: MAX_ATTEMPTS, previewIndex: 0 };
  },
  computed: {
    ...mapGetters({
      appIntegrations: 'integrations/getAppIntegrations',
      inboxes: 'inboxes/getInboxes',
      moduleTemplates: 'whatsappTemplates/getTemplates',
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
    // Las plantillas tal como las trae Meta en la bandeja (con sus components).
    metaTemplates() {
      if (this.kind !== 'whatsapp') return [];
      return (
        this.$store.getters['inboxes/getWhatsAppTemplates'](
          Number(this.value.inboxId)
        ) || []
      );
    },
    waTemplates() {
      return this.metaTemplates.map(item => ({
        name: item.name,
        language: item.language,
      }));
    },
    channelId() {
      const inbox = (this.inboxes || []).find(
        item => item.id === Number(this.value.inboxId)
      );
      return inbox ? inbox.channel_id : null;
    },
    // La vista previa del intento abierto: del módulo de plantillas (trae el archivo del
    // encabezado) o, si no está ahí, de Meta.
    previewName() {
      return (this.value.whatsappTemplates || [])[this.previewIndex] || '';
    },
    previewTitle() {
      const n = this.previewIndex + 1;
      return this.previewName
        ? this.t('WA_PREVIEW_TITLE', { n, name: this.previewName })
        : this.t('ATTEMPT_N', { n });
    },
    previewEmptyText() {
      return this.previewName
        ? this.t('WA_PREVIEW_MISSING')
        : this.t('WA_PREVIEW_EMPTY');
    },
    previewForm() {
      const nombre = this.previewName;
      if (!nombre) return null;
      const delModulo = (this.moduleTemplates || []).find(
        item =>
          item.name === nombre && item.channel_whatsapp_id === this.channelId
      );
      if (delModulo) return formFromTemplate(delModulo);
      const deMeta = this.metaTemplates.find(item => item.name === nombre);
      return deMeta ? formFromMetaTemplate(deMeta) : null;
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
  watch: {
    'value.inboxId': function cambiarBandeja() {
      this.previewIndex = 0;
      this.loadModuleTemplates();
    },
  },
  async mounted() {
    if (!this.appIntegrations || !this.appIntegrations.length)
      await this.$store.dispatch('integrations/get');
    this.loadModuleTemplates();
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
      if (this.previewIndex >= n) this.previewIndex = n - 1;
    },
    // Mensajes seguidos (ContactTrackings::MessageBurst): 0 = sin espera, hasta 30 s.
    setGroupSeconds(valor) {
      this.set('groupSeconds', Math.min(30, Math.max(0, Number(valor) || 0)));
    },
    setTemplate(indice, nombre) {
      const plantillas = [...(this.value.whatsappTemplates || [])];
      plantillas[indice] = nombre;
      this.set('whatsappTemplates', plantillas);
      this.previewIndex = indice;
    },
    selectPreview(indice) {
      this.previewIndex = indice;
    },
    // Las plantillas del módulo traen el archivo del encabezado; si falla, queda Meta.
    async loadModuleTemplates() {
      if (this.kind !== 'whatsapp') return;
      try {
        await this.$store.dispatch(
          'whatsappTemplates/fetch',
          Number(this.value.inboxId)
        );
      } catch (error) {
        // sin el módulo, la vista previa sale de lo que trae Meta
      }
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
      <label class="!m-0 sm:col-span-3">
        {{ t('GROUP_SECONDS') }}
        <input
          type="number"
          min="0"
          max="30"
          class="!mb-0 sm:!w-32"
          :value="value.groupSeconds || 0"
          @input="setGroupSeconds($event.target.value)"
        />
        <span class="block text-xs text-slate-500 dark:text-slate-400">
          {{ t('GROUP_SECONDS_HELP') }}
        </span>
      </label>
    </div>

    <!-- WhatsApp: una plantilla por intento (la ventana de 24 h la exige).
         Izquierda (40 %) los intentos; derecha (60 %) la plantilla del intento
         seleccionado, siempre a la vista. En celular, una debajo de otra. -->
    <div v-if="kind === 'whatsapp'" class="flex flex-col gap-2">
      <span class="text-sm text-slate-800 dark:text-slate-100">
        {{ t('WA_TEMPLATES') }}
      </span>
      <p v-if="!waTemplates.length" class="!m-0 text-xs text-amber-800">
        {{ t('WA_NONE') }}
      </p>
      <div v-else class="grid gap-4 md:grid-cols-5">
        <div class="flex flex-col gap-2 md:col-span-2">
          <div
            v-for="indice in attemptList"
            :key="indice"
            class="flex items-center gap-2 p-2 border border-solid rounded-lg cursor-pointer"
            :class="
              previewIndex === indice
                ? 'border-woot-500 bg-woot-50 dark:bg-woot-900/30'
                : 'border-slate-100 dark:border-slate-700'
            "
            @click="selectPreview(indice)"
            @focusin="selectPreview(indice)"
          >
            <span
              class="w-20 text-sm shrink-0 text-slate-600 dark:text-slate-300"
            >
              {{ t('ATTEMPT_N', { n: indice + 1 }) }}
            </span>
            <select
              class="!mb-0 min-w-0"
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
        </div>
        <div
          class="flex flex-col gap-2 p-3 rounded-lg md:col-span-3 md:sticky md:top-0 self-start w-full bg-slate-50 dark:bg-slate-800"
        >
          <span class="text-xs font-medium text-slate-600 dark:text-slate-300">
            {{ previewTitle }}
          </span>
          <TemplatePreview v-if="previewForm" :form="previewForm" />
          <p v-else class="!m-0 text-xs text-slate-500 dark:text-slate-400">
            {{ previewEmptyText }}
          </p>
        </div>
      </div>
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
