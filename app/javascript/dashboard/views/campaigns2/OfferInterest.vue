<!--
  Campaña con IA · Ofrecer — paso «Cuando le interesa»: el objetivo y lo que hace la IA, en un solo lugar. Una
  opción y debajo solo su configuración:
    relay        lo paso a alguien (agente de la bandeja o persona/equipo) · en cuánto tiempo le deben escribir
    quote        le armo la cotización (borrador o se la mando; con el precio de promoción) y luego lo paso
    appointment  le agendo una cita (con quién) · recordatorio de la cita
    external     compra en línea: la liga de compra y la palabra clave, juntas
  Por dentro: quote = offer_goal 'relay' + attend.settings.quote.mode draft|send.
  .sync: brief (offer_goal, goal_keyword, links, relay, relay_user_id, relay_team_id) · attend (settings)
-->
<script>
import QuoteMode from 'dashboard/views/readyAgents/QuoteMode.vue';
import AfterHandoff from 'dashboard/views/readyAgents/AfterHandoff.vue';

const CHOICES = ['relay', 'quote', 'appointment', 'external'];

export default {
  name: 'OfferInterest',
  components: { QuoteMode, AfterHandoff },
  props: {
    brief: { type: Object, required: true },
    attend: { type: Object, default: null },
    kit: { type: Object, default: null },
    users: { type: Array, default: () => [] },
    teams: { type: Array, default: () => [] },
    calendarUsers: { type: Array, default: () => [] },
    sources: { type: Array, default: () => [] },
    templates: { type: Array, default: () => [] },
  },
  emits: ['update:brief', 'update:attend'],
  data() {
    return { choices: CHOICES };
  },
  computed: {
    settings() {
      return (this.attend && this.attend.settings) || {};
    },
    quote() {
      return this.settings.quote || { mode: 'off' };
    },
    choice() {
      const goal = this.brief.offer_goal;
      if (goal === 'external' || goal === 'appointment') return goal;
      return ['draft', 'send'].includes(this.quote.mode) ? 'quote' : 'relay';
    },
    hasCatalog() {
      return this.sources.some(s => s.kind === 'catalog');
    },
    purchase() {
      return (this.brief.links || []).find(l => l.use === 'package') || null;
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.OFFER_FLOW.INTEREST.${key}`, params);
    },
    setBrief(changes) {
      this.$emit('update:brief', { ...this.brief, ...changes });
    },
    setSettings(settings) {
      this.$emit('update:attend', { ...this.attend, settings });
    },
    setSetting(key, value) {
      this.setSettings({ ...this.settings, [key]: value });
    },
    pick(choice) {
      const goal = choice === 'quote' ? 'relay' : choice;
      this.setBrief({ offer_goal: goal, relay: this.brief.relay || 'agent' });
      if (choice === 'quote' && !['draft', 'send'].includes(this.quote.mode)) {
        this.setSetting('quote', { ...this.quote, mode: 'draft' });
      }
      if (choice === 'relay' && this.quote.mode !== 'off') {
        this.setSetting('quote', { ...this.quote, mode: 'off' });
      }
    },
    calendarOn(id) {
      return (this.settings.appointment_user_ids || [])
        .map(String)
        .includes(String(id));
    },
    toggleCalendar(id) {
      const ids = (this.settings.appointment_user_ids || []).map(String);
      this.setSetting(
        'appointment_user_ids',
        ids.includes(String(id))
          ? ids.filter(i => i !== String(id))
          : [...ids, String(id)]
      );
    },
    setPurchase(url) {
      const links = [...(this.brief.links || [])];
      const index = links.findIndex(l => l.use === 'package');
      if (index >= 0) links[index] = { ...links[index], url };
      else
        links.unshift({ name: this.t('PURCHASE_NAME'), use: 'package', url });
      this.setBrief({ links });
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <section
      v-for="c in choices"
      :key="c"
      class="flex flex-col gap-2 p-3 border rounded-md"
      :class="
        choice === c
          ? 'border-woot-400 bg-woot-25/40 dark:bg-woot-900/10'
          : 'border-slate-100 dark:border-slate-700'
      "
    >
      <label class="flex items-start gap-2 mb-0 text-sm cursor-pointer">
        <input
          type="radio"
          class="!m-0 mt-1"
          :checked="choice === c"
          @change="pick(c)"
        />
        <span>
          <span class="font-semibold">{{ t(`CHOICES.${c}`) }}</span>
          <span class="block text-xs text-slate-500">
            {{ t(`ABOUT.${c}`) }}
          </span>
        </span>
      </label>

      <template v-if="choice === c">
        <!-- Cotizar: borrador o mandarla (con el precio de promoción) -->
        <QuoteMode
          v-if="c === 'quote'"
          :value="quote"
          :has-catalog="hasCatalog"
          :templates="templates"
          :modes="['draft', 'send']"
          :labels="{
            draft: t('QUOTE_MODES.draft'),
            send: t('QUOTE_MODES.send'),
          }"
          @input="setSetting('quote', $event)"
        />
        <p v-if="c === 'quote'" class="m-0 text-xs text-slate-500">
          {{ t('QUOTE_PROMO') }}
        </p>

        <!-- A quién lo pasa (relevo, y después de cotizar) -->
        <div v-if="c === 'relay' || c === 'quote'" class="flex flex-col gap-1">
          <span class="field-label">{{ t('RELAY_TO') }}</span>
          <label
            v-for="value in ['agent', 'person']"
            :key="value"
            class="flex items-center gap-2 mb-0 text-sm"
          >
            <input
              type="radio"
              class="!m-0"
              :checked="(brief.relay || 'agent') === value"
              @change="setBrief({ relay: value })"
            />
            {{ $t(`CAMPAIGNS2.OFFER.RELAY_CHOICES.${value}`) }}
          </label>
          <div
            v-if="brief.relay === 'person'"
            class="grid grid-cols-1 gap-2 sm:grid-cols-2"
          >
            <select
              :value="brief.relay_user_id"
              class="!mb-0"
              @change="setBrief({ relay_user_id: $event.target.value })"
            >
              <option value="">{{ $t('CAMPAIGNS2.OFFER.NOBODY') }}</option>
              <option v-for="u in users" :key="u.id" :value="u.id">
                {{ u.name }}
              </option>
            </select>
            <select
              :value="brief.relay_team_id"
              class="!mb-0"
              @change="setBrief({ relay_team_id: $event.target.value })"
            >
              <option value="">{{ $t('CAMPAIGNS2.OFFER.NO_TEAM') }}</option>
              <option v-for="team in teams" :key="team.id" :value="team.id">
                {{ team.name }}
              </option>
            </select>
          </div>
        </div>

        <!-- Agendar: con quién -->
        <div v-if="c === 'appointment'" class="flex flex-col gap-1">
          <span class="field-label">{{ t('CALENDARS') }}</span>
          <p v-if="!calendarUsers.length" class="m-0 text-xs text-amber-700">
            {{ t('NO_CALENDARS') }}
          </p>
          <label
            v-for="u in calendarUsers"
            :key="u.id"
            class="flex items-center gap-2 mb-0 text-sm"
          >
            <input
              type="checkbox"
              class="!m-0"
              :checked="calendarOn(u.id)"
              @change="toggleCalendar(u.id)"
            />
            {{ u.name }}
          </label>
        </div>

        <!-- En cuánto tiempo le deben escribir y el recordatorio de la cita -->
        <AfterHandoff
          v-if="c !== 'external' && attend"
          :value="settings"
          :templates="templates"
          :appointments="c === 'appointment'"
          @input="setSettings"
        />

        <!-- Compra en línea: la liga y la palabra clave, juntas -->
        <div
          v-if="c === 'external'"
          class="grid grid-cols-1 gap-2 sm:grid-cols-[1fr_10rem]"
        >
          <label class="block">
            <span class="field-label">{{ t('PURCHASE_URL') }}</span>
            <input
              :value="purchase ? purchase.url : ''"
              type="url"
              class="!mb-0"
              maxlength="2000"
              :placeholder="t('PURCHASE_PLACEHOLDER')"
              @input="setPurchase($event.target.value.trim())"
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
              @input="setBrief({ goal_keyword: $event.target.value })"
            />
          </label>
          <p class="m-0 text-xs text-slate-500 sm:col-span-2">
            {{ t('KEYWORD_HINT') }}
          </p>
        </div>
      </template>
    </section>
  </div>
</template>
