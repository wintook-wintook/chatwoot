<!--
  Campaña con IA · Recordar — paso «Cómo se paga»: qué cuenta como logrado (dice que ya pagó → queda una tarea al
  responsable del contrato para verificarlo; lo paso a alguien; paga en línea y avisa con la palabra clave, con la liga
  de pago junto) y lo que sabe la IA (cómo hacerlo, dónde pagar, qué pasa si no…). Lo que le vence a cada uno sale de
  su contrato: no se escribe aquí.
  .sync: brief (offer_goal, goal_keyword, links, relay, relay_user_id, relay_team_id, facts…)
-->
<script>
import CampaignKnowledge from './CampaignKnowledge.vue';

export default {
  name: 'RenewPay',
  components: { CampaignKnowledge },
  props: {
    brief: { type: Object, required: true },
    kit: { type: Object, default: null },
    users: { type: Array, default: () => [] },
    teams: { type: Array, default: () => [] },
    campaignId: { type: Number, default: null },
    save: { type: Function, required: true },
    attempts: { type: Number, default: 1 },
  },
  emits: ['update:brief'],
  computed: {
    goals() {
      return (this.kit && this.kit.goals) || ['done', 'relay', 'external'];
    },
    payment() {
      return (this.brief.links || []).find(l => l.use === 'package') || null;
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.RENEW_FLOW.PAY.${key}`, params);
    },
    set(changes) {
      this.$emit('update:brief', { ...this.brief, ...changes });
    },
    setPayment(url) {
      const links = [...(this.brief.links || [])];
      const index = links.findIndex(l => l.use === 'package');
      if (index >= 0) links[index] = { ...links[index], url };
      else links.unshift({ name: this.t('PAYMENT_NAME'), use: 'package', url });
      this.set({ links });
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <section
      class="flex flex-col gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
    >
      <p class="m-0 text-sm font-semibold">{{ t('GOAL_TITLE') }}</p>
      <label
        v-for="g in goals"
        :key="g"
        class="flex items-start gap-2 mb-0 text-sm"
      >
        <input
          type="radio"
          class="!m-0 mt-1"
          :checked="brief.offer_goal === g"
          @change="
            set({
              offer_goal: g,
              relay: g === 'relay' ? 'person' : brief.relay,
            })
          "
        />
        <span>
          {{ t(`GOALS.${g}`) }}
          <span class="block text-xs text-slate-500">{{
            t(`ABOUT.${g}`)
          }}</span>
        </span>
      </label>
      <div
        v-if="brief.offer_goal === 'relay'"
        class="grid grid-cols-1 gap-2 sm:grid-cols-2"
      >
        <select
          :value="brief.relay_user_id"
          class="!mb-0"
          @change="set({ relay_user_id: $event.target.value })"
        >
          <option value="">{{ $t('CAMPAIGNS2.OFFER.NOBODY') }}</option>
          <option v-for="u in users" :key="u.id" :value="u.id">
            {{ u.name }}
          </option>
        </select>
        <select
          :value="brief.relay_team_id"
          class="!mb-0"
          @change="set({ relay_team_id: $event.target.value })"
        >
          <option value="">{{ $t('CAMPAIGNS2.OFFER.NO_TEAM') }}</option>
          <option v-for="team in teams" :key="team.id" :value="team.id">
            {{ team.name }}
          </option>
        </select>
      </div>
      <div
        v-if="brief.offer_goal === 'external'"
        class="grid grid-cols-1 gap-2 sm:grid-cols-[1fr_10rem]"
      >
        <input
          :value="payment ? payment.url : ''"
          type="url"
          class="!mb-0"
          maxlength="2000"
          :placeholder="t('PAYMENT_PLACEHOLDER')"
          @input="setPayment($event.target.value.trim())"
        />
        <input
          :value="brief.goal_keyword"
          type="text"
          maxlength="40"
          class="!mb-0 uppercase"
          :placeholder="kit ? kit.keyword : ''"
          @input="set({ goal_keyword: $event.target.value })"
        />
      </div>
    </section>
    <p class="m-0 text-sm font-semibold">{{ t('KNOWLEDGE_TITLE') }}</p>
    <CampaignKnowledge
      :brief="brief"
      kind="renew"
      :kit="kit"
      :campaign-id="campaignId"
      :save="save"
      :attempts="attempts"
      :hidden-facts="['what_due']"
      @update:brief="$emit('update:brief', $event)"
    />
  </div>
</template>
