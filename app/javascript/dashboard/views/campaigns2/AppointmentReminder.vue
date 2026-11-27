<!--
  Campaña con Vendedor IA · Ofrecer y Reactivar con objetivo «cita» — el recordatorio de la cita
  (TrackingCampaigns::AppointmentReminder): un día antes (o 2 h antes si es el mismo día). Con la ventana abierta, la IA
  lo escribe al momento o un mensaje fijo (MessageChoice, con «Redactar con Dali»); pasadas 24 h, la plantilla del aviso
  de la cita que elijas aquí. .sync: brief (brief.appointment_reminder).
-->
<script>
import MessageChoice from './MessageChoice.vue';

export default {
  name: 'AppointmentReminder',
  components: { MessageChoice },
  props: {
    brief: { type: Object, required: true },
    isWhatsapp: { type: Boolean, default: false },
    templates: { type: Array, default: () => [] },
    campaignId: { type: Number, default: null },
    save: { type: Function, default: null },
  },
  emits: ['update:brief'],
  computed: {
    config() {
      return {
        ai: true,
        text: '',
        template: '',
        ...(this.brief.appointment_reminder || {}),
      };
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.APPOINTMENT_REMINDER.${key}`, params);
    },
    set(field, value) {
      this.$emit('update:brief', {
        ...this.brief,
        appointment_reminder: { ...this.config, [field]: value },
      });
    },
  },
};
</script>

<template>
  <section
    class="flex flex-col gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
  >
    <div>
      <p class="m-0 text-sm font-semibold">{{ t('TITLE') }}</p>
      <p class="m-0 text-xs text-slate-500">{{ t('HINT') }}</p>
    </div>
    <MessageChoice
      :value="config.text"
      :ai="config.ai !== false"
      :placeholder="t('PLACEHOLDER')"
      :ai-hint="t('AI_HINT')"
      :fixed-hint="t('FIXED_HINT')"
      :maxlength="600"
      :dali="{
        target: 'reminder',
        extra: { kind: 'appointment', pending: false },
      }"
      :campaign-id="campaignId"
      :save="save"
      @update:value="set('text', $event)"
      @update:ai="set('ai', $event)"
    />
    <label v-if="isWhatsapp" class="block">
      <span class="field-label">{{ t('TEMPLATE') }}</span>
      <select
        :value="config.template"
        class="!mb-0"
        @change="set('template', $event.target.value)"
      >
        <option value="">{{ t('NO_TEMPLATE') }}</option>
        <option v-for="name in templates" :key="name" :value="name">
          {{ name }}
        </option>
      </select>
      <span class="block text-[11px] text-slate-500">
        {{ t('TEMPLATE_HINT') }}
      </span>
    </label>
  </section>
</template>
