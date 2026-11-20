<!--
  «Seguimiento» de los tres agentes listos (Motor2::FollowUp): si deja de contestar, cuántos recordatorios dentro de
  las 24 h de WhatsApp y qué plantillas después, con la línea de tiempo de lo que va a pasar, para que la empresa
  vea exactamente qué seguimiento hará el agente.
  v-model: { nudges: 0-2, templates: [], template_days }
-->
<script>
const NUDGE_HOURS = [2, 20];

export default {
  name: 'FollowUpPlan',
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Object, required: true },
    // Plantillas aprobadas de su bandeja de WhatsApp (para después de 24 h).
    templates: { type: Array, default: () => [] },
    // prospects | customers | campaign_seller: qué retoma cada recordatorio.
    kind: { type: String, default: 'prospects' },
    // Lo de la pestaña Cotizaciones ({ mode, follow, follow_days, template }): su seguimiento va aparte.
    quote: { type: Object, default: null },
  },
  emits: ['input'],
  computed: {
    quoteLine() {
      const q = this.quote;
      if (!q || !q.mode || q.mode === 'off' || q.follow === false) return '';
      const how = q.template
        ? this.t('QUOTE_TEMPLATE', { name: q.template })
        : this.t('QUOTE_NO_TEMPLATE');
      return this.t('QUOTE', { n: q.follow_days || 3, how });
    },
    timeline() {
      const rows = NUDGE_HOURS.slice(0, this.value.nudges).map((h, i) => ({
        when: this.t('AT_HOURS', { n: h }),
        what:
          i === this.value.nudges - 1 && !this.value.templates.length
            ? this.t(`NUDGE.${this.kind}`) + this.t('LAST_IN_WINDOW')
            : this.t(`NUDGE.${this.kind}`),
      }));
      this.value.templates.forEach((name, i) => {
        rows.push({
          when: this.t('AT_DAY', { n: 1 + this.value.template_days * (i + 1) }),
          what: this.t('TEMPLATE', { name }),
        });
      });
      rows.push({ when: this.t('AFTER'), what: this.t(`END.${this.kind}`) });
      return rows;
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`READY_AGENTS.FOLLOW_PLAN.${key}`, params);
    },
    set(field, value) {
      this.$emit('input', { ...this.value, [field]: value });
    },
    toggle(name) {
      const list = this.value.templates;
      this.set(
        'templates',
        list.includes(name) ? list.filter(n => n !== name) : [...list, name]
      );
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
      {{ t('INTRO') }}
    </p>
    <fieldset class="flex flex-col gap-1">
      <legend class="field-label">{{ t('NUDGES') }}</legend>
      <label
        v-for="n in [2, 1, 0]"
        :key="n"
        class="flex items-start gap-2 text-sm cursor-pointer"
      >
        <input
          type="radio"
          class="!m-0 mt-1 shrink-0"
          :checked="value.nudges === n"
          @change="set('nudges', n)"
        />
        <span>
          {{ t(`NUDGES_${n}`) }}
          <span v-if="n === 2" class="text-xs text-woot-600">{{
            t('RECOMMENDED')
          }}</span>
        </span>
      </label>
    </fieldset>
    <fieldset v-if="templates.length" class="flex flex-col gap-1">
      <legend class="field-label">{{ t('TEMPLATES') }}</legend>
      <label
        v-for="name in templates"
        :key="name"
        class="flex items-center gap-2 text-sm"
      >
        <input
          type="checkbox"
          class="!m-0"
          :checked="value.templates.includes(name)"
          @change="toggle(name)"
        />
        {{ name }}
      </label>
      <label
        v-if="value.templates.length"
        class="flex items-center gap-2 text-sm"
      >
        {{ t('EVERY') }}
        <select
          class="!mb-0 !w-20"
          :value="value.template_days"
          @change="set('template_days', Number($event.target.value))"
        >
          <option v-for="d in [1, 2, 3, 5, 7]" :key="d" :value="d">
            {{ d }}
          </option>
        </select>
        {{ t('DAYS') }}
      </label>
    </fieldset>
    <p v-else class="m-0 text-xs text-slate-500">{{ t('NO_TEMPLATES') }}</p>
    <div
      class="p-3 rounded-md bg-slate-50 dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
    >
      <p
        class="m-0 mb-2 text-xs font-medium text-slate-600 dark:text-slate-300"
      >
        {{ t('TIMELINE') }}
      </p>
      <ol class="m-0 text-sm list-none">
        <li
          v-for="(row, i) in timeline"
          :key="i"
          class="flex gap-3 py-0.5 pl-3 border-l-2 border-woot-200"
        >
          <span class="w-24 shrink-0 text-woot-600">{{ row.when }}</span>
          <span class="text-slate-700 dark:text-slate-200">{{ row.what }}</span>
        </li>
      </ol>
      <p
        v-if="quoteLine"
        class="m-0 mt-2 pl-3 text-sm border-l-2 border-amber-200 text-slate-700 dark:text-slate-200"
      >
        {{ quoteLine }}
      </p>
      <p class="m-0 mt-2 text-xs text-slate-500">
        {{ t(`EXAMPLE.${kind}`) }}
      </p>
    </div>
    <p class="m-0 text-xs text-slate-500">{{ t('HINT') }}</p>
  </div>
</template>
