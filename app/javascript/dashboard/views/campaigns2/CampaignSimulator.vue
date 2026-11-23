<!--
  Campaña con Vendedor IA — «Simular»: la campaña completa para un contacto (o para ti), sin mandar nada.
  Cada toque con su espera y su texto ya personalizado; «Contesta aquí» abre el chat con el vendedor desde ese
  toque, y bajo cada decisión dice qué pasaría en la campaña (relevo, cita, sale de la campaña…).
  POST motor2_campaigns/:id/simulate (TrackingCampaigns::Motor2Simulation).
-->
<script>
import Motor2CampaignsAPI from 'dashboard/api/motor2Campaigns';
import ContactAPI from 'dashboard/api/contacts';
import CampaignChat from './CampaignChat.vue';

export default {
  name: 'CampaignSimulator',
  components: { CampaignChat },
  props: {
    campaignId: { type: [Number, String], default: null },
    // Guarda la campaña antes de simular (lo que está en pantalla); true si quedó guardada.
    save: { type: Function, required: true },
    payload: { type: Function, required: true },
    disabled: { type: Boolean, default: false },
  },
  data() {
    return {
      query: '',
      found: [],
      contact: null,
      sim: null,
      loading: false,
      error: '',
      replyTo: null,
    };
  },
  computed: {
    opener() {
      const touch = this.sim?.touches.find(t => t.n === this.replyTo);
      return touch?.text || '';
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.SIM.${key}`, params);
    },
    async search() {
      const q = this.query.trim();
      if (q.length < 2) {
        this.found = [];
        return;
      }
      try {
        const { data } = await ContactAPI.search(q);
        this.found = (data.payload || []).slice(0, 6);
      } catch (e) {
        this.found = [];
      }
    },
    pick(contact) {
      this.contact = contact;
      this.found = [];
      this.query = '';
      this.run();
    },
    asMe() {
      this.contact = null;
      this.run();
    },
    async run() {
      if (this.disabled) return;
      this.loading = true;
      this.error = '';
      this.replyTo = null;
      try {
        if (!(await this.save())) throw new Error('save');
        const { data } = await Motor2CampaignsAPI.simulate(
          this.campaignId,
          this.contact?.id
        );
        this.sim = data;
      } catch (e) {
        this.error = e.response?.data?.error || this.t('ERROR');
      } finally {
        this.loading = false;
      }
    },
    waitText(touch) {
      if (!touch.wait) return this.t('FIRST');
      return this.t('AFTER', {
        n: touch.wait.value,
        unit: this.t(`UNITS.${touch.wait.unit}`),
      });
    },
    sourceText(touch) {
      if (touch.source === 'template')
        return this.t('FROM_TEMPLATE', { name: touch.template });
      if (touch.source === 'campaign') return this.t('FROM_CAMPAIGN');
      return touch.channel === 'whatsapp'
        ? this.t('FROM_AI_WHATSAPP')
        : this.t('FROM_AI');
    },
    outcomeText(o) {
      return this.t(`OUTCOMES.${o.kind}`, {
        to: o.to || this.t('NOBODY'),
        n: o.attempts,
      });
    },
    warningText(w) {
      return this.t(`WARNINGS.${w.kind}`, {
        touches: (w.touches || []).join(', '),
      });
    },
    // La decisión del vendedor en el chat → lo que pasaría en la campaña.
    explain(kind) {
      const outcomes = this.sim?.outcomes || [];
      const map = {
        relay: ['appointment', 'relay_agent', 'relay_person'],
        discarded: ['discarded'],
        handoff: ['handoff'],
        later: ['later'],
        done: ['done'],
      };
      const o = outcomes.find(x => (map[kind] || []).includes(x.kind));
      return o ? this.outcomeText(o) : '';
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <div class="flex flex-col gap-1">
      <p class="m-0 text-xs text-slate-600 dark:text-slate-300">
        {{ t('INTRO') }}
      </p>
      <div class="flex gap-2">
        <input
          v-model="query"
          type="text"
          class="flex-1 !mb-0"
          :placeholder="t('SEARCH')"
          :disabled="disabled"
          @input="search"
        />
        <woot-button
          size="small"
          variant="smooth"
          :is-loading="loading && !contact"
          :disabled="disabled"
          @click="asMe"
        >
          {{ t('AS_ME') }}
        </woot-button>
      </div>
      <ul
        v-if="found.length"
        class="m-0 overflow-hidden list-none border rounded-md border-slate-100 dark:border-slate-700"
      >
        <li v-for="c in found" :key="c.id">
          <button
            type="button"
            class="w-full px-2 py-1 text-sm text-left hover:bg-slate-50 dark:hover:bg-slate-700"
            @click="pick(c)"
          >
            {{ c.name }}
            <span class="text-xs text-slate-500">
              {{ c.email || c.phone_number }}
            </span>
          </button>
        </li>
      </ul>
      <p v-if="disabled" class="m-0 text-xs text-amber-700">
        {{ t('NEEDS_SETUP') }}
      </p>
      <p v-if="error" class="m-0 text-xs text-red-600">{{ error }}</p>
    </div>

    <p v-if="loading" class="m-0 text-xs text-slate-500">{{ t('LOADING') }}</p>

    <template v-if="sim && !loading">
      <p class="m-0 text-sm font-medium">
        {{
          t('FOR', {
            name: sim.contact.name || '—',
            address: sim.contact.address || t('NO_ADDRESS'),
          })
        }}
      </p>
      <ul v-if="sim.warnings.length" class="flex flex-col gap-1 m-0 list-none">
        <li
          v-for="w in sim.warnings"
          :key="w.kind"
          class="flex items-start gap-1 text-xs text-amber-700 dark:text-amber-400"
        >
          <fluent-icon icon="warning" size="14" class="mt-0.5" />
          <span>{{ warningText(w) }}</span>
        </li>
      </ul>

      <ol class="flex flex-col gap-2 m-0 list-none">
        <li
          v-for="touch in sim.touches"
          :key="touch.n"
          class="p-2 border rounded-md border-slate-100 dark:border-slate-700"
        >
          <div class="flex items-center justify-between gap-2">
            <span class="text-xs font-medium text-woot-700 dark:text-woot-300">
              {{ t('TOUCH', { n: touch.n }) }} · {{ waitText(touch) }}
            </span>
            <button
              v-if="touch.text"
              type="button"
              class="text-xs text-woot-600 hover:underline"
              @click="replyTo = touch.n"
            >
              {{ t('REPLY_HERE') }}
            </button>
          </div>
          <p class="m-0 text-[11px] text-slate-500">{{ sourceText(touch) }}</p>
          <p v-if="touch.subject" class="m-0 mt-1 text-xs font-medium">
            {{ t('SUBJECT', { subject: touch.subject }) }}
          </p>
          <p
            v-if="touch.text"
            class="m-0 mt-1 text-sm whitespace-pre-line text-slate-800 dark:text-slate-100"
          >
            {{ touch.text }}
          </p>
          <p v-else class="m-0 mt-1 text-xs italic text-slate-500">
            {{ t('AI_WRITES') }}
          </p>
        </li>
      </ol>
      <p class="m-0 text-xs text-slate-500">{{ t('STOPS_ON_REPLY') }}</p>

      <div class="flex flex-col gap-1">
        <p class="m-0 text-xs font-medium text-slate-600 dark:text-slate-300">
          {{ t('OUTCOMES_TITLE') }}
        </p>
        <ul class="flex flex-col gap-1 m-0 text-xs list-disc ltr:pl-4 rtl:pr-4">
          <li v-for="o in sim.outcomes" :key="o.kind">
            {{ outcomeText(o) }}
          </li>
        </ul>
      </div>

      <CampaignChat
        v-if="replyTo"
        :payload="payload"
        :opener="opener"
        :explain="explain"
      />
    </template>
  </div>
</template>
