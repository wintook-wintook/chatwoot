<!--
  Campaña con Vendedor IA · Ofrecer y Reactivar — «Último aviso» (TrackingCampaigns::LastCall): un día antes de que
  termine la promoción, a quien no ha contestado. Con la ventana abierta, la IA lo escribe al momento o un mensaje fijo
  (MessageChoice, con «Redactar con Dali»); pasadas 24 h, la plantilla. .sync: brief (brief.last_call).
-->
<script>
import MessageChoice from './MessageChoice.vue';

export default {
  name: 'LastCall',
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
    // «29 de noviembre»
    endDate() {
      const date = new Date(`${this.brief.valid_until}T12:00:00`);
      return Number.isNaN(date.getTime())
        ? this.brief.valid_until
        : date.toLocaleDateString('es-MX', { day: 'numeric', month: 'long' });
    },
    config() {
      return {
        on: true,
        ai: true,
        text: '',
        template: '',
        ...(this.brief.last_call || {}),
      };
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.LAST_CALL.${key}`, params);
    },
    set(field, value) {
      this.$emit('update:brief', {
        ...this.brief,
        last_call: { ...this.config, [field]: value },
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
      <p class="m-0 text-xs text-slate-500">
        {{ t('HINT', { date: endDate }) }}
      </p>
    </div>
    <label class="flex items-center gap-2 text-sm font-medium">
      <input
        type="checkbox"
        class="!m-0"
        :checked="config.on"
        @change="set('on', $event.target.checked)"
      />
      {{ t('ON') }}
    </label>
    <template v-if="config.on">
      <MessageChoice
        :value="config.text"
        :ai="config.ai !== false"
        :placeholder="t('PLACEHOLDER')"
        :ai-hint="t('AI_HINT')"
        :fixed-hint="t('FIXED_HINT')"
        :maxlength="600"
        :dali="{
          target: 'reminder',
          extra: { kind: 'last_call', pending: true },
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
    </template>
  </section>
</template>
