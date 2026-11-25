<!--
  Campaña con IA · Encuesta — paso «Si califica bajo»: a quién le llega el caso (persona o equipo), de qué tipo, con
  qué prioridad, y qué le contesta al cliente (replies.low). Backend: brief.low_case (TrackingCampaigns::SurveyItems)
  y CampaignSellerOutcomes#low_score_case.
  .sync: brief (low_case { user_id, team_id, case_type_id, priority }, replies.low)
-->
<script>
const PRIORITIES = ['low', 'medium', 'high', 'urgent'];

export default {
  name: 'SurveyLow',
  props: {
    brief: { type: Object, required: true },
    kit: { type: Object, default: null },
    users: { type: Array, default: () => [] },
    teams: { type: Array, default: () => [] },
    caseTypes: { type: Array, default: () => [] },
  },
  emits: ['update:brief'],
  data() {
    return { priorities: PRIORITIES };
  },
  computed: {
    lowCase() {
      return { priority: 'high', ...(this.brief.low_case || {}) };
    },
    reply() {
      return (this.brief.replies || {}).low || '';
    },
    fallback() {
      return ((this.kit && this.kit.replies) || {}).low || '';
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.SURVEY_FLOW.LOW.${key}`, params);
    },
    setCase(field, value) {
      this.$emit('update:brief', {
        ...this.brief,
        low_case: { ...this.lowCase, [field]: value },
      });
    },
    setReply(value) {
      this.$emit('update:brief', {
        ...this.brief,
        replies: { ...(this.brief.replies || {}), low: value },
      });
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <section
      class="grid grid-cols-1 gap-2 p-3 border rounded-md sm:grid-cols-2 border-slate-100 dark:border-slate-700"
    >
      <p class="m-0 text-sm font-semibold sm:col-span-2">
        {{ t('CASE_TITLE') }}
      </p>
      <p class="m-0 text-xs text-slate-500 sm:col-span-2">
        {{ t('CASE_HINT') }}
      </p>
      <label class="block">
        <span class="field-label">{{ t('USER') }}</span>
        <select
          :value="lowCase.user_id || ''"
          class="!mb-0"
          @change="setCase('user_id', $event.target.value)"
        >
          <option value="">{{ t('NOBODY') }}</option>
          <option v-for="u in users" :key="u.id" :value="u.id">
            {{ u.name }}
          </option>
        </select>
      </label>
      <label class="block">
        <span class="field-label">{{ t('TEAM') }}</span>
        <select
          :value="lowCase.team_id || ''"
          class="!mb-0"
          @change="setCase('team_id', $event.target.value)"
        >
          <option value="">{{ t('NO_TEAM') }}</option>
          <option v-for="team in teams" :key="team.id" :value="team.id">
            {{ team.name }}
          </option>
        </select>
      </label>
      <label class="block">
        <span class="field-label">{{ t('CASE_TYPE') }}</span>
        <select
          :value="lowCase.case_type_id || ''"
          class="!mb-0"
          @change="setCase('case_type_id', $event.target.value)"
        >
          <option value="">{{ t('FIRST_SUPPORT') }}</option>
          <option v-for="type in caseTypes" :key="type.id" :value="type.id">
            {{ type.name }}
          </option>
        </select>
      </label>
      <label class="block">
        <span class="field-label">{{ t('PRIORITY') }}</span>
        <select
          :value="lowCase.priority"
          class="!mb-0"
          @change="setCase('priority', $event.target.value)"
        >
          <option v-for="p in priorities" :key="p" :value="p">
            {{ t(`PRIORITIES.${p}`) }}
          </option>
        </select>
      </label>
    </section>
    <section
      class="flex flex-col gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
    >
      <p class="m-0 text-sm font-semibold">{{ t('REPLY_TITLE') }}</p>
      <textarea
        :value="reply"
        rows="3"
        maxlength="600"
        class="!mb-0"
        :placeholder="fallback"
        @input="setReply($event.target.value)"
      />
      <p class="m-0 text-xs text-slate-500">{{ t('REPLY_HINT') }}</p>
    </section>
  </div>
</template>
