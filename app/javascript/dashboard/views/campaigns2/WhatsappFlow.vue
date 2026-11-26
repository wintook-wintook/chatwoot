<!--
  Campaña con Vendedor IA por WhatsApp — paso «Mensajes», en dos partes (prop part):
    touches  La apertura (no es toque) y los toques 1…n a quien no contesta. Cada uno: su plantilla (y de dónde sale
             cada variable) para cuando no ha escrito en 24 h y, opcional, su texto fijo para cuando sí (vacío: la IA).
    info     La información completa, a lo ancho y con cómo le llega: sale TAL CUAL, una sola vez, si le interesa
             (con las imágenes «cuando muestre interés» y, al final, las ligas «con la información»); en Encuesta, las preguntas.
  .sync: touches (templates, template_vars) y brief (opener, touch_texts, content).
-->
<script>
import DaliWriter from './DaliWriter.vue';
import MessageChoice from './MessageChoice.vue';
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
  components: { DaliWriter, MessageChoice },
  props: {
    touches: { type: Object, required: true },
    brief: { type: Object, required: true },
    templates: { type: Array, default: () => [] },
    attempts: { type: Number, default: 1 },
    kind: { type: String, default: 'offer' },
    event: { type: Object, default: null },
    // Las ligas de la ficha, para meterlas en la información completa.
    links: { type: Array, default: () => [] },
    // Qué parte se ve: «touches» (apertura y toques) o «info» (la información completa).
    part: { type: String, default: 'touches' },
    // «Redactar con Dali»: la campaña y cómo guardarla antes (para que lea lo último).
    campaignId: { type: Number, default: null },
    save: { type: Function, required: true },
  },
  emits: ['update:touches', 'update:brief'],
  data() {
    // fixedOpen: los toques donde eligió «Mensaje fijo» (aún sin texto).
    return { maxContent: MAX_CONTENT, sources: VAR_SOURCES, fixedOpen: [] };
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
    // Toques a quien no contesta (después de la apertura): mensaje 2, 3…
    followUps() {
      return this.numbers.slice(1);
    },
    // Las ligas que se agregan solas al final de la información.
    packageLinks() {
      return this.links
        .filter(l => l.use === 'package' && (l.url || '').trim())
        .map(l => l.name || l.url);
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
    // Texto fijo del mensaje n (1 = apertura → brief.opener; 2.. = toque → brief.touch_texts).
    fixedOf(n) {
      if (n === 1) return this.brief.opener || '';
      return (this.brief.touch_texts || [])[n - 2] || '';
    },
    // Toque: ¿mensaje fijo? (con texto, o recién elegido). Al volver a «la IA al momento» se borra el fijo.
    fixedMode(n) {
      return !!this.fixedOf(n) || this.fixedOpen.includes(n);
    },
    setFixedMode(n, fixed) {
      this.fixedOpen = fixed
        ? [...this.fixedOpen, n]
        : this.fixedOpen.filter(x => x !== n);
    },
    setFixed(n, value) {
      if (n === 1) {
        this.setBrief('opener', value);
        return;
      }
      const texts = [...(this.brief.touch_texts || [])];
      while (texts.length < n - 1) texts.push('');
      texts[n - 2] = value;
      this.setBrief('touch_texts', texts);
    },
    setBrief(field, value) {
      this.$emit('update:brief', { ...this.brief, [field]: value });
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <template v-if="part === 'touches'">
      <p v-if="!templates.length" class="m-0 text-xs text-amber-700">
        {{ $t('CAMPAIGNS2.MESSAGES.NO_TEMPLATES') }}
      </p>
      <!-- La apertura y cada toque: su plantilla (sin ventana) y su texto fijo (con ventana abierta) -->
      <section
        v-for="n in numbers"
        :key="n"
        class="flex flex-col gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
      >
        <p class="m-0 text-sm font-semibold">
          {{ n === 1 ? t('OPENER_TITLE') : t('TOUCH_TITLE', { n: n - 1 }) }}
        </p>
        <p class="m-0 text-xs text-slate-500">
          {{ n === 1 ? t('OPENER_HINT') : t('TOUCH_HINT') }}
        </p>
        <label class="block">
          <span class="field-label">{{ t('TEMPLATE') }}</span>
          <select
            class="!mb-0"
            :value="touches.templates[n - 1] || ''"
            @change="setTemplate(n, $event.target.value)"
          >
            <option value="">{{ t('TEMPLATE_PICK') }}</option>
            <option v-for="tpl in templates" :key="tpl.name" :value="tpl.name">
              {{ tpl.name }}
            </option>
          </select>
        </label>
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
        <!-- Con la ventana abierta: la apertura con su texto fijo; cada toque, la IA al momento o un fijo -->
        <MessageChoice
          :value="fixedOf(n)"
          :ai="!fixedMode(n)"
          :choose-mode="n > 1"
          :legend="n === 1 ? t('OPEN_WINDOW') : ''"
          :placeholder="
            n === 1
              ? t(`OPEN_WINDOW_PLACEHOLDER.${kind}`)
              : t(`TOUCH_PLACEHOLDER.${kind}`)
          "
          :fixed-hint="n === 1 ? t('OPEN_WINDOW_HINT') : ''"
          :dali="{
            target: n === 1 ? 'opener' : 'touch',
            number: Math.max(n - 1, 1),
          }"
          :campaign-id="campaignId"
          :save="save"
          @update:value="setFixed(n, $event)"
          @update:ai="setFixedMode(n, !$event)"
        />
      </section>
      <p v-if="followUps.length" class="m-0 text-[11px] text-slate-500">
        {{ t('TOUCHES_NOTE') }}
      </p>
    </template>

    <!-- La información completa: a lo ancho, con cómo le llega -->
    <template v-else>
      <template v-if="isSurvey">
        <p class="m-0 text-sm font-semibold">{{ t('INFO_TITLE.survey') }}</p>
        <p class="m-0 text-xs text-slate-500">{{ t('SURVEY_HINT') }}</p>
        <ol class="m-0 text-sm ltr:pl-5 rtl:pr-5">
          <li v-for="q in questions" :key="q">{{ q }}</li>
        </ol>
        <p v-if="!questions.length" class="m-0 text-xs text-amber-700">
          {{ t('SURVEY_EMPTY') }}
        </p>
      </template>
      <template v-else>
        <p class="m-0 text-sm font-semibold">
          {{ t(`INFO_TITLE.${kind}`) }}
        </p>
        <p class="m-0 text-xs text-slate-500">
          {{ t(`INFO_HINT.${kind}`) }}
        </p>
        <DaliWriter
          target="info"
          :current="brief.content || ''"
          :campaign-id="campaignId"
          :save="save"
          @use="setBrief('content', $event.text)"
        />
        <!-- Las ligas «con la información» se agregan solas al final (Skills::CampaignNotes#with_package_links) -->
        <p v-if="packageLinks.length" class="m-0 text-[11px] text-slate-600">
          {{ t('LINKS_AUTO', { names: packageLinks.join(', ') }) }}
        </p>
        <textarea
          class="!mb-0 !h-auto min-h-[26rem] text-sm leading-relaxed"
          rows="18"
          :maxlength="maxContent"
          :value="brief.content"
          :placeholder="t(`INFO_PLACEHOLDER.${kind}`)"
          @input="setBrief('content', $event.target.value)"
        />
        <span class="text-[11px] text-slate-500">
          {{ t('INFO_COUNT', { n: contentLength, max: maxContent }) }} ·
          {{ t('INFO_PREVIEW') }}
        </span>
        <p class="m-0 text-[11px] text-slate-500">{{ t('INFO_FILES') }}</p>
      </template>
      <p class="m-0 text-xs text-slate-600 dark:text-slate-300">
        {{ t(`AFTER.${kind}`) }}
      </p>
    </template>
  </div>
</template>
