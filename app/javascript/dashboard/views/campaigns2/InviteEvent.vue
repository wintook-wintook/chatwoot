<!--
  Campaña con IA · Invitar — paso «El evento»: el evento con sus datos (fecha, lugar, liga, cupo: no se vuelven a
  escribir; cuándo y dónde de la ficha salen de aquí), cómo confirma (aquí en la plática, o se registra en Zoom /
  formulario: entonces la liga de registro y la palabra clave van juntas) y lo que solo sabe la empresa (para quién
  es, costo, preguntas, otras ligas, archivos: CampaignKnowledge sin cuándo/dónde).
  .sync: brief (event_id, offer_goal, goal_keyword, links, facts, offer_what…)
-->
<script>
import CampaignKnowledge from './CampaignKnowledge.vue';

export default {
  name: 'InviteEvent',
  components: { CampaignKnowledge },
  props: {
    brief: { type: Object, required: true },
    events: { type: Array, default: () => [] },
    event: { type: Object, default: null },
    kit: { type: Object, default: null },
    goals: { type: Array, default: () => [] },
    campaignId: { type: Number, default: null },
    save: { type: Function, required: true },
    attempts: { type: Number, default: 1 },
  },
  emits: ['update:brief'],
  computed: {
    external() {
      return this.brief.offer_goal === 'external';
    },
    // La liga de registro: la primera que va «con la información».
    registration() {
      return (this.brief.links || []).find(l => l.use === 'package') || null;
    },
    eventsUrl() {
      return `/app/accounts/${this.$route.params.accountId}/events`;
    },
    when() {
      if (!this.event || !this.event.starts_at) return '';
      return new Date(this.event.starts_at).toLocaleString('es-MX', {
        weekday: 'long',
        day: 'numeric',
        month: 'long',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.INVITE.${key}`, params);
    },
    set(field, value) {
      this.$emit('update:brief', { ...this.brief, [field]: value });
    },
    setRegistration(url) {
      const links = [...(this.brief.links || [])];
      const index = links.findIndex(l => l.use === 'package');
      const row = { name: this.t('REGISTRATION_NAME'), use: 'package', url };
      if (index >= 0) links[index] = { ...links[index], url };
      else links.unshift(row);
      this.set('links', links);
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <!-- El evento -->
    <section
      class="flex flex-col gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
    >
      <div class="flex flex-wrap items-center justify-between gap-2">
        <p class="m-0 text-sm font-semibold">{{ t('EVENT_TITLE') }}</p>
        <a
          :href="eventsUrl"
          target="_blank"
          rel="noopener noreferrer"
          class="text-xs text-woot-600 hover:underline"
        >
          {{ t('CREATE_EVENT') }}
        </a>
      </div>
      <select
        :value="brief.event_id"
        class="!mb-0"
        @change="set('event_id', $event.target.value)"
      >
        <option value="">{{ t('PICK_EVENT') }}</option>
        <option v-for="e in events" :key="e.id" :value="e.id">
          {{ e.name }}
        </option>
      </select>
      <p v-if="!events.length" class="m-0 text-xs text-amber-700">
        {{ t('NO_EVENTS') }}
      </p>
      <dl
        v-if="event"
        class="grid grid-cols-[7rem_1fr] gap-x-2 gap-y-1 m-0 p-2 text-sm rounded-md bg-slate-25 dark:bg-slate-800"
      >
        <dt class="text-slate-500">{{ t('WHEN') }}</dt>
        <dd class="m-0">{{ when || '—' }}</dd>
        <dt class="text-slate-500">{{ t('WHERE') }}</dt>
        <dd class="m-0">{{ event.location || '—' }}</dd>
        <template v-if="event.meeting_url">
          <dt class="text-slate-500">{{ t('LINK') }}</dt>
          <dd class="m-0 truncate">{{ event.meeting_url }}</dd>
        </template>
        <template v-if="event.capacity">
          <dt class="text-slate-500">{{ t('CAPACITY') }}</dt>
          <dd class="m-0">{{ event.capacity }}</dd>
        </template>
      </dl>
      <p v-if="event" class="m-0 text-xs text-slate-500">
        {{ t('FROM_EVENT_HINT') }}
      </p>
    </section>

    <!-- Cómo confirma -->
    <section
      class="flex flex-col gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
    >
      <p class="m-0 text-sm font-semibold">{{ t('CONFIRM_TITLE') }}</p>
      <label v-for="g in goals" :key="g" class="flex items-start gap-2 text-sm">
        <input
          :checked="brief.offer_goal === g"
          type="radio"
          class="!m-0 mt-1"
          :value="g"
          @change="set('offer_goal', g)"
        />
        <span>
          {{ t(`GOALS.${g}`) }}
          <span class="block text-xs text-slate-500">
            {{ t(`GOALS_ABOUT.${g}`) }}
          </span>
        </span>
      </label>
      <div
        v-if="external"
        class="grid grid-cols-1 gap-2 p-2 rounded-md sm:grid-cols-[1fr_10rem] bg-slate-25 dark:bg-slate-800"
      >
        <label class="block">
          <span class="field-label">{{ t('REGISTRATION_URL') }}</span>
          <input
            :value="registration ? registration.url : ''"
            type="url"
            class="!mb-0"
            maxlength="2000"
            :placeholder="t('REGISTRATION_PLACEHOLDER')"
            @input="setRegistration($event.target.value.trim())"
          />
        </label>
        <label class="block">
          <span class="field-label">{{ t('KEYWORD') }}</span>
          <input
            :value="brief.goal_keyword"
            type="text"
            maxlength="40"
            class="!mb-0 uppercase"
            :placeholder="kit ? kit.keyword : ''"
            @input="set('goal_keyword', $event.target.value)"
          />
        </label>
        <p class="m-0 text-xs text-slate-500 sm:col-span-2">
          {{ t('KEYWORD_HINT') }}
        </p>
      </div>
    </section>

    <!-- Lo que solo sabe la empresa -->
    <p class="m-0 text-sm font-semibold">{{ t('KNOWLEDGE_TITLE') }}</p>
    <CampaignKnowledge
      :brief="brief"
      kind="invite"
      :kit="kit"
      :event="event"
      :campaign-id="campaignId"
      :save="save"
      :attempts="attempts"
      :hidden-facts="['when', 'place']"
      @update:brief="$emit('update:brief', $event)"
    />
  </div>
</template>
