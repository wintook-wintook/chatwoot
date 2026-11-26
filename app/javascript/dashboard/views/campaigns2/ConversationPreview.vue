<!--
  Campaña con Vendedor IA por WhatsApp — la conversación como la vería el contacto, en orden y con los datos de
  ejemplo llenos: 1) la apertura (plantilla), 2) el contacto contesta «sí», 3) el «Mensaje 2» con sus imágenes (o, en
  Encuesta, la primera pregunta) y 4) desde ahí la IA contesta sus dudas.
-->
<script>
import { fillTemplate, fillCampaignText, sampleValues } from './campaignFlow';

export default {
  name: 'ConversationPreview',
  props: {
    template: { type: Object, default: null },
    rules: { type: Object, default: () => ({}) },
    brief: { type: Object, required: true },
    kind: { type: String, default: 'offer' },
    event: { type: Object, default: null },
  },
  computed: {
    samples() {
      return sampleValues(this.brief, this.event);
    },
    opener() {
      return this.template
        ? fillTemplate(this.template.body, this.rules, this.samples)
        : '';
    },
    header() {
      return this.template?.header
        ? fillTemplate(this.template.header, this.rules, this.samples)
        : '';
    },
    second() {
      if (this.kind === 'survey') {
        return (
          (this.brief.survey_questions || []).find(q => (q || '').trim()) || ''
        );
      }
      const text = fillCampaignText(this.brief.content, this.samples);
      if (this.kind !== 'invite' || !text) return text;
      // Invitar: la liga de registro sale al final si no está en el texto (Skills::CampaignNotes#with_registration).
      return (this.brief.links || [])
        .filter(l => l.use === 'package' && l.url && !text.includes(l.url))
        .reduce((all, l) => `${all.trimEnd()}\n\n${l.name}: ${l.url}`, text);
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.FLOW.PREVIEW.${key}`, params);
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col w-full max-w-xs gap-2 p-3 mx-auto rounded-2xl bg-[#efeae2] dark:bg-slate-700"
  >
    <p class="m-0 text-[10px] text-center text-slate-500">{{ t('STEP_1') }}</p>
    <div
      v-if="template"
      class="self-start max-w-[90%] p-2 text-sm bg-white rounded-lg shadow-sm dark:bg-slate-800 text-slate-800 dark:text-slate-100"
    >
      <p v-if="header" class="m-0 mb-1 font-semibold">{{ header }}</p>
      <p class="m-0 whitespace-pre-line">{{ opener }}</p>
      <p v-if="template.footer" class="m-0 mt-1 text-xs text-slate-500">
        {{ template.footer }}
      </p>
      <div
        v-for="button in template.buttons || []"
        :key="button"
        class="py-1 mt-1 text-xs text-center border-t text-woot-600 border-slate-100 dark:border-slate-700"
      >
        {{ button }}
      </div>
    </div>
    <p v-else class="m-0 text-xs text-center text-slate-500">
      {{ $t('CAMPAIGNS2.MESSAGES.NO_TEMPLATE_PREVIEW') }}
    </p>

    <div
      class="self-end max-w-[80%] p-2 text-sm rounded-lg bg-[#d9fdd3] dark:bg-woot-800 text-slate-800 dark:text-slate-100"
    >
      {{ kind === 'survey' ? t('REPLY_SURVEY') : t('REPLY') }}
    </div>

    <p class="m-0 text-[10px] text-center text-slate-500">{{ t('STEP_2') }}</p>
    <div
      v-if="kind !== 'survey'"
      class="self-start px-2 py-1 text-xs bg-white rounded-lg dark:bg-slate-800 text-slate-500"
    >
      {{ t('IMAGES') }}
    </div>
    <div
      class="self-start max-w-[90%] p-2 text-sm bg-white rounded-lg shadow-sm dark:bg-slate-800 text-slate-800 dark:text-slate-100 whitespace-pre-line"
    >
      {{ second || t('AI_WRITES') }}
    </div>

    <p class="m-0 text-[10px] text-center text-slate-500">
      {{ t(`AFTER.${kind === 'survey' ? 'survey' : 'sale'}`) }}
    </p>
  </div>
</template>
