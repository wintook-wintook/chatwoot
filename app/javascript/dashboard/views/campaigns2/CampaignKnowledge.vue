<!--
  Campaña con IA — paso «La ficha»: lo que SABE la IA (no lo que se manda; eso está en «Mensajes»).
    Datos        los campos del tipo (TrackingCampaigns::CampaignKit: Invitar → cuándo, dónde, costo, para quién…)
    Preguntas    preguntas y objeciones con su respuesta autorizada
    Ligas        cada liga con cuándo se manda: con la información · solo si la pide · solo si tiene un problema
    Encuesta     las preguntas, tal cual y en orden (en lugar de los datos)
    Archivos     imágenes y archivos de la campaña (CampaignFiles)
  .sync: brief (facts, objections, links, survey_questions, low_score)
-->
<script>
import CampaignFiles from './CampaignFiles.vue';

const MAX_LINKS = 6;
const MAX_QUESTIONS = 15;
const LINK_USES = ['package', 'request', 'problem'];

export default {
  name: 'CampaignKnowledge',
  components: { CampaignFiles },
  props: {
    brief: { type: Object, required: true },
    kind: { type: String, default: 'offer' },
    kit: { type: Object, default: null },
    event: { type: Object, default: null },
    campaignId: { type: Number, default: null },
    save: { type: Function, required: true },
    attempts: { type: Number, default: 1 },
    // Invitar: cuándo y dónde salen del evento (InviteEvent), no se piden aquí.
    hiddenFacts: { type: Array, default: () => [] },
    // Encuesta con su propio paso de preguntas (SurveyQuestions): aquí no se piden.
    noSurvey: { type: Boolean, default: false },
  },
  emits: ['update:brief'],
  data() {
    return { linkUses: LINK_USES, maxLinks: MAX_LINKS };
  },
  computed: {
    isSurvey() {
      return this.kind === 'survey';
    },
    fields() {
      return ((this.kit && this.kit.facts) || ['more']).filter(
        key => !this.hiddenFacts.includes(key)
      );
    },
    facts() {
      return this.brief.facts || {};
    },
    links() {
      return this.brief.links || [];
    },
    objections() {
      return this.brief.objections || [];
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.KNOWLEDGE.${key}`, params);
    },
    set(field, value) {
      this.$emit('update:brief', { ...this.brief, [field]: value });
    },
    setFact(key, value) {
      this.set('facts', { ...this.facts, [key]: value });
    },
    placeholder(key) {
      const kindKey = `CAMPAIGNS2.KNOWLEDGE.PLACEHOLDERS.${this.kind}.${key}`;
      return this.$te(kindKey) ? this.$t(kindKey) : '';
    },
    // Invitar: cuándo y dónde con los datos del evento (para completarlos).
    fillFromEvent() {
      if (!this.event) return;
      const when = this.event.starts_at
        ? new Date(this.event.starts_at).toLocaleString([], {
            weekday: 'long',
            day: 'numeric',
            month: 'long',
            hour: '2-digit',
            minute: '2-digit',
          })
        : '';
      const place = [this.event.location, this.event.meeting_url]
        .filter(Boolean)
        .join(' · ');
      this.set('facts', {
        ...this.facts,
        when: this.facts.when || when,
        place: this.facts.place || place,
        agenda: this.facts.agenda || this.event.description || '',
      });
    },
    setRow(list, field, index, change) {
      const rows = list.map((row, i) =>
        i === index ? { ...row, ...change } : row
      );
      this.set(field, rows);
    },
    addLink() {
      this.set('links', [
        ...this.links,
        {
          name: this.links.length ? '' : this.t('LINKS.FIRST_NAME'),
          url: '',
          use: this.links.length ? 'request' : 'package',
        },
      ]);
    },
    removeAt(field, index) {
      this.set(
        field,
        (this.brief[field] || []).filter((_r, i) => i !== index)
      );
    },
    addObjection() {
      if (this.objections.length >= MAX_QUESTIONS) return;
      this.set('objections', [
        ...this.objections,
        { objection: '', answer: '' },
      ]);
    },
    setQuestion(index, value) {
      const list = [...(this.brief.survey_questions || ['', '', ''])];
      list[index] = value;
      this.set('survey_questions', list);
    },
    validUrl(url) {
      return !url || /^https?:\/\/\S+$/.test(url);
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <p class="m-0 text-xs text-slate-500">{{ t('HINT') }}</p>

    <!-- Encuesta: las preguntas -->
    <section
      v-if="isSurvey && !noSurvey"
      class="flex flex-col gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
    >
      <p class="m-0 text-sm font-semibold">{{ t('SURVEY_TITLE') }}</p>
      <label
        v-for="(q, i) in brief.survey_questions || []"
        :key="i"
        class="block"
      >
        <span class="field-label">
          {{ $t('CAMPAIGNS2.OFFER.QUESTION', { n: i + 1 }) }}
        </span>
        <input
          :value="q"
          type="text"
          class="!mb-0"
          maxlength="300"
          :placeholder="$t(`CAMPAIGNS2.OFFER.QUESTION_PLACEHOLDER_${i + 1}`)"
          @input="setQuestion(i, $event.target.value)"
        />
      </label>
      <label class="flex items-center gap-2 text-sm">
        {{ $t('CAMPAIGNS2.OFFER.LOW_SCORE') }}
        <input
          :value="brief.low_score"
          type="number"
          min="1"
          max="10"
          class="!mb-0 !w-20"
          @input="set('low_score', Number($event.target.value) || 7)"
        />
      </label>
    </section>

    <!-- Los datos (lo que sabe) -->
    <section
      class="flex flex-col gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
    >
      <div class="flex flex-wrap items-center justify-between gap-2">
        <p class="m-0 text-sm font-semibold">{{ t('FACTS_TITLE') }}</p>
        <button
          v-if="kind === 'invite' && event && !hiddenFacts.length"
          type="button"
          class="text-xs text-woot-600 hover:underline"
          @click="fillFromEvent"
        >
          {{ t('FROM_EVENT') }}
        </button>
      </div>
      <p class="m-0 text-xs text-slate-500">{{ t('FACTS_HINT') }}</p>
      <label
        v-for="key in fields"
        :key="key"
        class="grid grid-cols-1 gap-1 sm:grid-cols-[11rem_1fr] sm:items-start"
      >
        <span
          class="pt-1 text-xs font-medium text-slate-700 dark:text-slate-200"
        >
          {{ t(`FACTS.${key}`) }}
        </span>
        <textarea
          :value="facts[key]"
          :rows="key === 'more' ? 3 : 1"
          class="!mb-0 text-sm"
          :maxlength="key === 'more' ? 1500 : 800"
          :placeholder="placeholder(key)"
          @input="setFact(key, $event.target.value)"
        />
      </label>
    </section>

    <!-- Preguntas y objeciones -->
    <section
      v-if="!isSurvey"
      class="flex flex-col gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
    >
      <p class="m-0 text-sm font-semibold">{{ t('FAQ_TITLE') }}</p>
      <p class="m-0 text-xs text-slate-500">{{ t('FAQ_HINT') }}</p>
      <div
        v-for="(o, i) in objections"
        :key="i"
        class="grid grid-cols-1 sm:grid-cols-[1fr_1fr_auto] gap-1"
      >
        <input
          :value="o.objection"
          type="text"
          class="!mb-0"
          maxlength="300"
          :placeholder="t('FAQ_QUESTION')"
          @input="
            setRow(objections, 'objections', i, {
              objection: $event.target.value,
            })
          "
        />
        <input
          :value="o.answer"
          type="text"
          class="!mb-0"
          maxlength="800"
          :placeholder="t('FAQ_ANSWER')"
          @input="
            setRow(objections, 'objections', i, { answer: $event.target.value })
          "
        />
        <button
          type="button"
          class="px-1 text-slate-400 hover:text-red-600"
          :aria-label="t('REMOVE')"
          @click="removeAt('objections', i)"
        >
          <fluent-icon icon="dismiss" size="14" />
        </button>
      </div>
      <button
        v-if="objections.length < 15"
        type="button"
        class="self-start text-xs text-woot-600 hover:underline"
        @click="addObjection"
      >
        {{ t('FAQ_ADD') }}
      </button>
    </section>

    <!-- Ligas -->
    <section
      v-if="!isSurvey"
      class="flex flex-col gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
    >
      <p class="m-0 text-sm font-semibold">{{ t('LINKS.TITLE') }}</p>
      <p class="m-0 text-xs text-slate-500">{{ t('LINKS.HINT') }}</p>
      <div
        v-for="(l, i) in links"
        :key="i"
        class="grid grid-cols-1 sm:grid-cols-[9rem_1fr_12rem_auto] gap-1 sm:items-center"
      >
        <input
          :value="l.name"
          type="text"
          class="!mb-0"
          maxlength="60"
          :placeholder="t('LINKS.NAME')"
          @input="setRow(links, 'links', i, { name: $event.target.value })"
        />
        <input
          :value="l.url"
          type="url"
          class="!mb-0"
          :class="{ '!border-red-400': !validUrl(l.url) }"
          maxlength="2000"
          :placeholder="t('LINKS.URL')"
          @input="
            setRow(links, 'links', i, { url: $event.target.value.trim() })
          "
        />
        <select
          :value="l.use"
          class="!mb-0"
          @change="setRow(links, 'links', i, { use: $event.target.value })"
        >
          <option v-for="use in linkUses" :key="use" :value="use">
            {{ t(`LINKS.USES.${use}`) }}
          </option>
        </select>
        <button
          type="button"
          class="px-1 text-slate-400 hover:text-red-600"
          :aria-label="t('REMOVE')"
          @click="removeAt('links', i)"
        >
          <fluent-icon icon="dismiss" size="14" />
        </button>
      </div>
      <button
        v-if="links.length < maxLinks"
        type="button"
        class="self-start text-xs text-woot-600 hover:underline"
        @click="addLink"
      >
        {{ t('LINKS.ADD') }}
      </button>
    </section>

    <CampaignFiles
      :campaign-id="campaignId"
      :save="save"
      :attempts="attempts"
      :kind="kind"
    />
  </div>
</template>
