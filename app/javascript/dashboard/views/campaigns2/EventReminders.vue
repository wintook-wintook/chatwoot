<!--
  Campaña con IA · Invitar — en «Mensajes»: los recordatorios del evento (TrackingCampaigns::EventReminders):
  un día antes y una hora antes. Cada uno se prende o apaga y elige a quién: «Solo a los que confirmaron» o
  «Confirmados y los que no han contestado» (a estos les llega una última invitación, con su propio texto). De
  fábrica: un día antes a los dos grupos; una hora antes, solo a los confirmados. Nunca a los que dijeron que no.
  En WhatsApp, a quien no escribió en 24 h solo le llega con plantilla (una para confirmados y otra, opcional, para
  los que no han contestado).
  .sync: brief (reminders { day_before, hour_before, day_who, hour_who, day_text, day_pending_text, hour_text,
  hour_pending_text, template, pending_template })
-->
<script>
const DEFAULTS = {
  day_before:
    '¡Hola {{nombre}}! 😊 Te recordamos que mañana es {{evento}}: {{cuando}}. {{lugar}} ¡Te esperamos!',
  hour_before:
    '¡Hola {{nombre}}! En una hora empieza {{evento}}. {{liga}} ¡Nos vemos!',
  day_before_pending:
    '¡Hola {{nombre}}! Mañana es {{evento}}: {{cuando}}. ¿Te apartamos tu lugar? {{liga}}',
  hour_before_pending:
    '¡Hola {{nombre}}! En una hora empieza {{evento}}. ¿Te animas? {{liga}}',
};
const PREFIX = { day_before: 'day', hour_before: 'hour' };
const DEFAULT_WHO = { day_before: 'pending', hour_before: 'confirmed' };

export default {
  name: 'EventReminders',
  props: {
    brief: { type: Object, required: true },
    isWhatsapp: { type: Boolean, default: false },
    templates: { type: Array, default: () => [] },
  },
  emits: ['update:brief'],
  data() {
    return {
      kinds: ['day_before', 'hour_before'],
      whoOptions: ['confirmed', 'pending'],
    };
  },
  computed: {
    reminders() {
      return {
        day_before: true,
        hour_before: true,
        day_who: DEFAULT_WHO.day_before,
        hour_who: DEFAULT_WHO.hour_before,
        template: '',
        pending_template: '',
        ...(this.brief.reminders || {}),
      };
    },
    anyPending() {
      return this.kinds.some(
        kind => this.reminders[kind] && this.who(kind) === 'pending'
      );
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
    prefix(kind) {
      return PREFIX[kind];
    },
    who(kind) {
      return this.reminders[`${PREFIX[kind]}_who`] || DEFAULT_WHO[kind];
    },
    textKey(kind, pending) {
      return `${PREFIX[kind]}_${pending ? 'pending_text' : 'text'}`;
    },
    placeholder(kind, pending) {
      return DEFAULTS[pending ? `${kind}_pending` : kind];
    },
  },
};
</script>

<template>
  <section
    class="flex flex-col gap-3 p-3 border rounded-md border-slate-100 dark:border-slate-700"
  >
    <div>
      <p class="m-0 text-sm font-semibold">{{ t('TITLE') }}</p>
      <p class="m-0 text-xs text-slate-500">{{ t('HINT') }}</p>
    </div>
    <div
      v-for="kind in kinds"
      :key="kind"
      class="flex flex-col gap-1 pb-2 border-b border-slate-50 dark:border-slate-800 last:border-b-0"
    >
      <div class="flex flex-wrap items-center gap-2">
        <label class="flex items-center gap-2 mb-0 text-sm font-medium">
          <input
            :checked="reminders[kind]"
            type="checkbox"
            class="!m-0"
            @change="set(kind, $event.target.checked)"
          />
          {{ t(`KINDS.${kind}`) }}
        </label>
        <select
          v-if="reminders[kind]"
          :value="who(kind)"
          class="!mb-0 !w-auto !h-8 !py-0 text-sm"
          @change="set(`${prefix(kind)}_who`, $event.target.value)"
        >
          <option v-for="option in whoOptions" :key="option" :value="option">
            {{ t(`WHO.${option}`) }}
          </option>
        </select>
      </div>
      <template v-if="reminders[kind]">
        <span class="text-xs text-slate-500">{{ t('TO_CONFIRMED') }}</span>
        <textarea
          :value="reminders[textKey(kind, false)]"
          rows="2"
          maxlength="600"
          class="!mb-0 text-sm"
          :placeholder="placeholder(kind, false)"
          @input="set(textKey(kind, false), $event.target.value)"
        />
        <template v-if="who(kind) === 'pending'">
          <span class="text-xs text-slate-500">{{ t('TO_PENDING') }}</span>
          <textarea
            :value="reminders[textKey(kind, true)]"
            rows="2"
            maxlength="600"
            class="!mb-0 text-sm"
            :placeholder="placeholder(kind, true)"
            @input="set(textKey(kind, true), $event.target.value)"
          />
        </template>
      </template>
    </div>
    <p class="m-0 text-[11px] text-slate-500">{{ t('NEVER') }}</p>
    <p class="m-0 text-[11px] text-slate-500">{{ t('VARIABLES') }}</p>
    <div v-if="isWhatsapp" class="grid grid-cols-1 gap-2 sm:grid-cols-2">
      <label class="block">
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
      </label>
      <label v-if="anyPending" class="block">
        <span class="field-label">{{ t('PENDING_TEMPLATE') }}</span>
        <select
          :value="reminders.pending_template"
          class="!mb-0"
          @change="set('pending_template', $event.target.value)"
        >
          <option value="">{{ t('SAME_TEMPLATE') }}</option>
          <option v-for="name in templates" :key="name" :value="name">
            {{ name }}
          </option>
        </select>
      </label>
      <span class="text-xs text-slate-500 sm:col-span-2">
        {{ t('TEMPLATE_HINT') }}
        <template v-if="anyPending">{{ t('COST_HINT') }}</template>
      </span>
    </div>
  </section>
</template>
