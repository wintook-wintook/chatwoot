<!--
  Campaña con IA · Encuesta — paso «Las preguntas»: hasta 5, cada una con su tipo (0–10, 1–5, sí/no o abierta) y,
  en las de calificación, desde cuánto es baja (menor a…). Backend: TrackingCampaigns::SurveyItems (arma el texto que
  se pregunta con su rango). Debajo, lo que sabe la IA (para qué es, cuánto tarda…).
  .sync: brief (survey_items [{ text, type, low }], facts)
-->
<script>
import CampaignKnowledge from './CampaignKnowledge.vue';

const MAX = 5;
const TYPES = ['scale10', 'scale5', 'yesno', 'open'];
const DEFAULT_LOW = { scale10: 7, scale5: 3 };

export default {
  name: 'SurveyQuestions',
  components: { CampaignKnowledge },
  props: {
    brief: { type: Object, required: true },
    kit: { type: Object, default: null },
    campaignId: { type: Number, default: null },
    save: { type: Function, required: true },
  },
  emits: ['update:brief'],
  data() {
    return { types: TYPES, max: MAX };
  },
  computed: {
    items() {
      return this.brief.survey_items || [];
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.SURVEY_FLOW.${key}`, params);
    },
    setItems(items) {
      this.$emit('update:brief', { ...this.brief, survey_items: items });
    },
    setItem(index, change) {
      this.setItems(
        this.items.map((item, i) => {
          if (i !== index) return item;
          const next = { ...item, ...change };
          if (change.type) next.low = DEFAULT_LOW[change.type] || null;
          return next;
        })
      );
    },
    add() {
      if (this.items.length >= MAX) return;
      const first = !this.items.length;
      this.setItems([
        ...this.items,
        {
          text: '',
          type: first ? 'scale10' : 'open',
          low: first ? DEFAULT_LOW.scale10 : null,
        },
      ]);
    },
    remove(index) {
      this.setItems(this.items.filter((_item, i) => i !== index));
    },
    move(index, step) {
      const list = [...this.items];
      const to = index + step;
      if (to < 0 || to >= list.length) return;
      [list[index], list[to]] = [list[to], list[index]];
      this.setItems(list);
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <section
      class="flex flex-col gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
    >
      <p class="m-0 text-sm font-semibold">{{ t('QUESTIONS_TITLE') }}</p>
      <p class="m-0 text-xs text-slate-500">{{ t('QUESTIONS_HINT') }}</p>
      <div
        v-for="(item, index) in items"
        :key="index"
        class="grid items-center grid-cols-1 gap-2 p-2 rounded-md sm:grid-cols-[1.5rem_1fr_9rem_7rem_auto] bg-slate-25 dark:bg-slate-800"
      >
        <span class="text-sm font-semibold text-slate-500">{{
          index + 1
        }}</span>
        <input
          :value="item.text"
          type="text"
          maxlength="300"
          class="!mb-0"
          :placeholder="t(`PLACEHOLDERS.${item.type}`)"
          @input="setItem(index, { text: $event.target.value })"
        />
        <select
          :value="item.type"
          class="!mb-0"
          @change="setItem(index, { type: $event.target.value })"
        >
          <option v-for="type in types" :key="type" :value="type">
            {{ t(`TYPES.${type}`) }}
          </option>
        </select>
        <label
          v-if="item.type === 'scale10' || item.type === 'scale5'"
          class="flex items-center gap-1 mb-0 text-xs text-slate-500"
        >
          {{ t('LOW_BELOW') }}
          <input
            :value="item.low"
            type="number"
            min="1"
            :max="item.type === 'scale5' ? 5 : 10"
            class="!mb-0 !h-8 !py-0 !w-14 text-sm"
            @input="
              setItem(index, { low: Number($event.target.value) || null })
            "
          />
        </label>
        <span v-else />
        <div class="flex items-center">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            size="small"
            icon="chevron-up"
            :disabled="index === 0"
            @click="move(index, -1)"
          />
          <woot-button
            v-tooltip="t('REMOVE')"
            variant="clear"
            color-scheme="alert"
            size="small"
            icon="delete"
            @click="remove(index)"
          />
        </div>
      </div>
      <button
        v-if="items.length < max"
        type="button"
        class="self-start text-sm text-woot-600 hover:underline"
        @click="add"
      >
        {{ t('ADD') }}
      </button>
    </section>

    <p class="m-0 text-sm font-semibold">{{ t('KNOWLEDGE_TITLE') }}</p>
    <CampaignKnowledge
      :brief="brief"
      kind="survey"
      :kit="kit"
      :campaign-id="campaignId"
      :save="save"
      no-survey
      @update:brief="$emit('update:brief', $event)"
    />
  </div>
</template>
