<!--
  Campaña con Vendedor IA por WhatsApp — paso «Mensajes», en el orden en que pasa:
    Mensaje 1 · Apertura   la plantilla del toque 1 (y de dónde sale cada variable) o, si escribió en las últimas 24 h,
                           el texto de apertura (vacío: lo escribe la IA). Toques 2…n si no contesta.
    Mensaje 2              si pide información: el copy que sale TAL CUAL (con las imágenes «con la información»);
                           en Encuesta, las preguntas.
    Después                la IA resuelve dudas con eso y lleva al cierre del tipo.
  .sync: touches (templates, template_vars) y brief (opener, content).
-->
<script>
import {
  VAR_SOURCES,
  templateVariables,
  sampleValues,
  guessSource,
  fillTemplate,
} from './campaignFlow';

const MAX_CONTENT = 4000;

export default {
  name: 'WhatsappFlow',
  props: {
    touches: { type: Object, required: true },
    brief: { type: Object, required: true },
    templates: { type: Array, default: () => [] },
    attempts: { type: Number, default: 1 },
    kind: { type: String, default: 'offer' },
    event: { type: Object, default: null },
  },
  emits: ['update:touches', 'update:brief'],
  data() {
    return { maxContent: MAX_CONTENT, sources: VAR_SOURCES };
  },
  computed: {
    numbers() {
      return Array.from({ length: this.attempts }, (_, i) => i + 1);
    },
    samples() {
      return sampleValues(this.brief, this.event);
    },
    isSurvey() {
      return this.kind === 'survey';
    },
    contentLength() {
      return (this.brief.content || '').length;
    },
    questions() {
      return (this.brief.survey_questions || []).filter(q => (q || '').trim());
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.FLOW.${key}`, params);
    },
    varLabel(variable) {
      return `{{${variable}}}`;
    },
    templateOf(n) {
      const name = (this.touches.templates || [])[n - 1];
      return this.templates.find(tpl => tpl.name === name) || null;
    },
    variablesOf(n) {
      const tpl = this.templateOf(n);
      return tpl ? templateVariables(tpl.body) : [];
    },
    rulesOf(n) {
      const tpl = this.templateOf(n);
      return (tpl && (this.touches.template_vars || {})[tpl.name]) || {};
    },
    preview(n) {
      const tpl = this.templateOf(n);
      return tpl ? fillTemplate(tpl.body, this.rulesOf(n), this.samples) : '';
    },
    setTemplate(n, name) {
      const templates = [...(this.touches.templates || [])];
      templates[n - 1] = name;
      const vars = { ...(this.touches.template_vars || {}) };
      const tpl = this.templates.find(x => x.name === name);
      // Al elegir una plantilla nueva, cada variable arranca con una idea razonable (luego se cambia).
      if (tpl && !vars[name]) {
        vars[name] = Object.fromEntries(
          templateVariables(tpl.body).map((v, i) => [
            v,
            { source: guessSource(v, i), text: '' },
          ])
        );
      }
      this.$emit('update:touches', {
        ...this.touches,
        templates,
        template_vars: vars,
      });
    },
    setRule(n, variable, change) {
      const tpl = this.templateOf(n);
      if (!tpl) return;
      const vars = { ...(this.touches.template_vars || {}) };
      const rules = { ...(vars[tpl.name] || {}) };
      rules[variable] = {
        source: 'text',
        text: '',
        ...rules[variable],
        ...change,
      };
      vars[tpl.name] = rules;
      this.$emit('update:touches', { ...this.touches, template_vars: vars });
    },
    setBrief(field, value) {
      this.$emit('update:brief', { ...this.brief, [field]: value });
    },
    // Invitar: el «Mensaje 2» de inicio con los datos del evento (para completarlo).
    fillFromEvent() {
      if (!this.event) return;
      const s = this.samples;
      const lines = [
        this.t('EVENT_DRAFT.TITLE', { name: s.event_name }),
        s.event_date && this.t('EVENT_DRAFT.WHEN', { when: s.event_date }),
        s.event_place && this.t('EVENT_DRAFT.WHERE', { where: s.event_place }),
        this.event.description,
      ].filter(Boolean);
      this.setBrief(
        'content',
        `${lines.join('\n')}\n\n${this.t('EVENT_DRAFT.CLOSE')}`
      );
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <!-- Mensaje 1 · Apertura -->
    <section
      class="flex flex-col gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
    >
      <p class="m-0 text-sm font-semibold">{{ t('OPENER_TITLE') }}</p>
      <p class="m-0 text-xs text-slate-500">{{ t('OPENER_HINT') }}</p>

      <div v-for="n in numbers" :key="n" class="flex flex-col gap-1">
        <span class="field-label">
          {{ n === 1 ? t('TEMPLATE_OPENER') : t('TEMPLATE_TOUCH', { n }) }}
        </span>
        <select
          :value="touches.templates[n - 1] || ''"
          @change="setTemplate(n, $event.target.value)"
        >
          <option value="">{{ t('TEMPLATE_PICK') }}</option>
          <option v-for="tpl in templates" :key="tpl.name" :value="tpl.name">
            {{ tpl.name }}
          </option>
        </select>
        <template v-if="templateOf(n)">
          <p
            class="m-0 text-xs whitespace-pre-line rounded-md p-2 bg-slate-25 dark:bg-slate-800 text-slate-700 dark:text-slate-200"
          >
            {{ preview(n) }}
          </p>
          <div
            v-for="variable in variablesOf(n)"
            :key="variable"
            class="grid grid-cols-1 gap-1 sm:grid-cols-[auto_1fr_1fr] sm:items-center"
          >
            <code class="text-xs">{{ varLabel(variable) }}</code>
            <select
              class="!mb-0"
              :value="(rulesOf(n)[variable] || {}).source || 'text'"
              @change="setRule(n, variable, { source: $event.target.value })"
            >
              <option v-for="src in sources" :key="src" :value="src">
                {{ t(`SOURCES.${src}`) }}
              </option>
            </select>
            <input
              v-if="((rulesOf(n)[variable] || {}).source || 'text') === 'text'"
              type="text"
              class="!mb-0"
              maxlength="200"
              :value="(rulesOf(n)[variable] || {}).text"
              :placeholder="t('FIXED_TEXT')"
              @input="setRule(n, variable, { text: $event.target.value })"
            />
          </div>
        </template>
        <p v-if="n === 2" class="m-0 text-[11px] text-slate-500">
          {{ t('TOUCHES_NOTE') }}
        </p>
      </div>
      <p v-if="!templates.length" class="m-0 text-xs text-amber-700">
        {{ $t('CAMPAIGNS2.MESSAGES.NO_TEMPLATES') }}
      </p>

      <label class="block">
        <span class="field-label">{{ t('OPEN_WINDOW') }}</span>
        <textarea
          rows="3"
          maxlength="1500"
          :value="brief.opener"
          :placeholder="t('OPEN_WINDOW_PLACEHOLDER')"
          @input="setBrief('opener', $event.target.value)"
        />
        <span class="block text-[11px] text-slate-500">
          {{ t('OPEN_WINDOW_HINT') }}
        </span>
      </label>
    </section>

    <!-- Mensaje 2 -->
    <section
      class="flex flex-col gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
    >
      <p class="m-0 text-sm font-semibold">
        {{ t(`INFO_TITLE.${isSurvey ? 'survey' : kind}`) }}
      </p>
      <template v-if="isSurvey">
        <p class="m-0 text-xs text-slate-500">{{ t('SURVEY_HINT') }}</p>
        <ol class="m-0 text-sm ltr:pl-5 rtl:pr-5">
          <li v-for="q in questions" :key="q">{{ q }}</li>
        </ol>
        <p v-if="!questions.length" class="m-0 text-xs text-amber-700">
          {{ t('SURVEY_EMPTY') }}
        </p>
      </template>
      <template v-else>
        <p class="m-0 text-xs text-slate-500">
          {{ t(`INFO_HINT.${kind}`) }}
        </p>
        <textarea
          rows="8"
          :maxlength="maxContent"
          :value="brief.content"
          :placeholder="t(`INFO_PLACEHOLDER.${kind}`)"
          @input="setBrief('content', $event.target.value)"
        />
        <div class="flex flex-wrap items-center justify-between gap-2">
          <span class="text-[11px] text-slate-500">
            {{ t('INFO_COUNT', { n: contentLength, max: maxContent }) }}
          </span>
          <button
            v-if="kind === 'invite' && event"
            type="button"
            class="text-xs text-woot-600 hover:underline"
            @click="fillFromEvent"
          >
            {{ t('FROM_EVENT') }}
          </button>
        </div>
        <p class="m-0 text-[11px] text-slate-500">{{ t('INFO_FILES') }}</p>
      </template>
    </section>

    <!-- Después -->
    <p class="m-0 text-xs text-slate-600 dark:text-slate-300">
      {{ t(`AFTER.${kind}`) }}
    </p>
  </div>
</template>
