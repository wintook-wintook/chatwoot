<!--
  Campaña con IA · Invitar — en «Mensajes»: los recordatorios a los que CONFIRMARON (TrackingCampaigns::EventReminders):
  un día antes y una hora antes del evento, cada uno se prende o apaga y su texto se puede cambiar (vacío = el de
  fábrica). En WhatsApp, a quien no escribió en 24 h solo le llega con la plantilla elegida.
  .sync: brief (reminders { day_before, hour_before, day_text, hour_text, template })
-->
<script>
const DEFAULTS = {
  day_before:
    '¡Hola {{nombre}}! 😊 Te recordamos que mañana es {{evento}}: {{cuando}}. {{lugar}} ¡Te esperamos!',
  hour_before:
    '¡Hola {{nombre}}! En una hora empieza {{evento}}. {{liga}} ¡Nos vemos!',
};
const TEXT_KEYS = { day_before: 'day_text', hour_before: 'hour_text' };

export default {
  name: 'EventReminders',
  props: {
    brief: { type: Object, required: true },
    isWhatsapp: { type: Boolean, default: false },
    templates: { type: Array, default: () => [] },
  },
  emits: ['update:brief'],
  data() {
    return { kinds: ['day_before', 'hour_before'], textKeys: TEXT_KEYS };
  },
  computed: {
    reminders() {
      return {
        day_before: true,
        hour_before: true,
        day_text: '',
        hour_text: '',
        template: '',
        ...(this.brief.reminders || {}),
      };
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.REMINDERS.${key}`, params);
    },
    set(field, value) {
      this.$emit('update:brief', {
        ...this.brief,
        reminders: { ...this.reminders, [field]: value },
      });
    },
    placeholder(kind) {
      return DEFAULTS[kind];
    },
  },
};
</script>

<template>
  <section
    class="flex flex-col gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
  >
    <p class="m-0 text-sm font-semibold">{{ t('TITLE') }}</p>
    <p class="m-0 text-xs text-slate-500">{{ t('HINT') }}</p>
    <div v-for="kind in kinds" :key="kind" class="flex flex-col gap-1">
      <label class="flex items-center gap-2 text-sm">
        <input
          :checked="reminders[kind]"
          type="checkbox"
          class="!m-0"
          @change="set(kind, $event.target.checked)"
        />
        {{ t(`KINDS.${kind}`) }}
      </label>
      <textarea
        v-if="reminders[kind]"
        :value="reminders[textKeys[kind]]"
        rows="2"
        maxlength="600"
        class="!mb-0 text-sm"
        :placeholder="placeholder(kind)"
        @input="set(textKeys[kind], $event.target.value)"
      />
    </div>
    <p class="m-0 text-[11px] text-slate-500">{{ t('VARIABLES') }}</p>
    <label v-if="isWhatsapp" class="block">
      <span class="field-label">{{ t('TEMPLATE') }}</span>
      <select
        :value="reminders.template"
        class="!mb-0"
        @change="set('template', $event.target.value)"
      >
        <option value="">{{ t('NO_TEMPLATE') }}</option>
        <option v-for="name in templates" :key="name" :value="name">
          {{ name }}
        </option>
      </select>
      <span class="block text-xs text-slate-500">{{ t('TEMPLATE_HINT') }}</span>
    </label>
  </section>
</template>
