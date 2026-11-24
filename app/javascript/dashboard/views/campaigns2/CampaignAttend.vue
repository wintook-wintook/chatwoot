<!--
  Campaña con Vendedor IA — «Cómo atiende»: lo que antes estaba en el «Vendedor de campaña», ahora de la campaña
  (la campaña arma su propio agente: TrackingCampaigns::CampaignAgent). Viene lleno con lo de la última campaña o,
  la primera vez, con la voz de tu empresa y todas tus fuentes.
  v-model: { display_name, sources [], email_signature, settings { tone, voice, voice_mode, business_*, price_source,
  quote, follow_up, attend_hours, appointment_notice, appointment_user_ids, appointment_minutes, instructions } }
  Reusa las piezas de Agentes listos (AgentBusiness, AgentVoice, SourceOrder, QuoteMode, FollowUpPlan, AfterHandoff).
-->
<script>
import SubTabs from 'dashboard/views/readyAgents/SubTabs.vue';
import AgentVoice from 'dashboard/views/readyAgents/AgentVoice.vue';
import AgentBusiness from 'dashboard/views/readyAgents/AgentBusiness.vue';
import SourceOrder, {
  addSource,
} from 'dashboard/views/readyAgents/SourceOrder.vue';
import QuoteMode from 'dashboard/views/readyAgents/QuoteMode.vue';
import FollowUpPlan from 'dashboard/views/readyAgents/FollowUpPlan.vue';
import AfterHandoff from 'dashboard/views/readyAgents/AfterHandoff.vue';

const TABS = ['who', 'knows', 'quote', 'follow', 'notes'];

export default {
  name: 'CampaignAttend',
  components: {
    SubTabs,
    AgentVoice,
    AgentBusiness,
    SourceOrder,
    QuoteMode,
    FollowUpPlan,
    AfterHandoff,
  },
  props: {
    value: { type: Object, required: true },
    sources: { type: Array, default: () => [] },
    calendarUsers: { type: Array, default: () => [] },
    // Plantillas aprobadas de la bandeja de la campaña (seguimiento pasadas las 24 h, aviso de la cita).
    templates: { type: Array, default: () => [] },
    isEmail: { type: Boolean, default: false },
    appointments: { type: Boolean, default: false },
  },
  emits: ['input'],
  data() {
    return { tab: 'who' };
  },
  computed: {
    tabs() {
      return TABS.map(key => ({ key, label: this.t(`TABS.${key}`) }));
    },
    settings() {
      return this.value.settings || {};
    },
    hasCatalog() {
      return this.sources.some(s => s.kind === 'catalog');
    },
    priceOptions() {
      const options = this.sources
        .filter(s => s.kind === 'catalog' || s.kind === 'google_sheet')
        .map(s => ({ value: s.key, label: s.name, about: s.about }));
      return [
        ...options,
        { value: 'canned', label: this.$t('READY_AGENTS.KNOWS.PRICES.canned') },
        { value: 'none', label: this.$t('READY_AGENTS.KNOWS.PRICES.none') },
      ];
    },
    otherSources() {
      return this.sources.filter(
        s => s.key !== 'canned_response' && s.kind !== 'catalog'
      );
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.ATTEND.${key}`, params);
    },
    set(field, val) {
      this.$emit('input', { ...this.value, [field]: val });
    },
    setSettings(settings) {
      this.$emit('input', { ...this.value, settings });
    },
    setSetting(key, val) {
      this.setSettings({ ...this.settings, [key]: val });
    },
    toggleSource(key) {
      const list = this.value.sources || [];
      this.set(
        'sources',
        list.includes(key) ? list.filter(k => k !== key) : addSource(list, key)
      );
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
  },
};
</script>

<template>
  <div class="flex flex-col gap-2.5">
    <p class="m-0 text-xs text-slate-500">{{ t('HINT') }}</p>
    <SubTabs v-model="tab" :tabs="tabs" />

    <template v-if="tab === 'who'">
      <label class="block">
        <span class="field-label">{{ t('DISPLAY_NAME') }}</span>
        <input
          type="text"
          maxlength="30"
          :value="value.display_name"
          :placeholder="t('DISPLAY_NAME_PLACEHOLDER')"
          @input="set('display_name', $event.target.value)"
        />
      </label>
      <AgentVoice :value="settings" @input="setSettings" />
      <AgentBusiness :value="settings" @input="setSettings" />
      <label v-if="isEmail" class="block">
        <span class="field-label">{{ t('SIGNATURE') }}</span>
        <textarea
          rows="3"
          maxlength="1000"
          :value="value.email_signature"
          :placeholder="t('SIGNATURE_PLACEHOLDER')"
          @input="set('email_signature', $event.target.value)"
        />
      </label>
    </template>

    <template v-if="tab === 'knows'">
      <span class="field-label">
        {{ $t('READY_AGENTS.KNOWS.PRICES.QUESTION') }}
      </span>
      <label
        v-for="option in priceOptions"
        :key="option.value"
        class="flex items-start gap-2 text-sm"
      >
        <input
          type="radio"
          class="!m-0 mt-1"
          :checked="settings.price_source === option.value"
          @change="setSetting('price_source', option.value)"
        />
        <span>
          {{ option.label }}
          <span v-if="option.about" class="block text-xs text-slate-500">
            {{ option.about }}
          </span>
        </span>
      </label>
      <label
        v-for="src in otherSources"
        :key="src.key"
        class="flex items-start gap-2 p-2 border rounded-md cursor-pointer border-slate-100 dark:border-slate-700"
      >
        <input
          type="checkbox"
          class="!m-0 mt-0.5 shrink-0"
          :checked="(value.sources || []).includes(src.key)"
          @change="toggleSource(src.key)"
        />
        <span class="text-sm">
          <span class="block font-medium">{{ src.name }}</span>
          <span class="block text-xs text-slate-500">{{ src.about }}</span>
        </span>
      </label>
      <SourceOrder
        :value="value.sources || []"
        :sources="sources"
        @input="set('sources', $event)"
      />
    </template>

    <template v-if="tab === 'quote'">
      <QuoteMode
        :value="settings.quote || { mode: 'off' }"
        :has-catalog="hasCatalog"
        :templates="templates"
        @input="setSetting('quote', $event)"
      />
      <span class="field-label">{{ t('CALENDARS') }}</span>
      <p class="m-0 text-xs text-slate-500">{{ t('CALENDARS_HINT') }}</p>
      <p v-if="!calendarUsers.length" class="m-0 text-xs text-amber-700">
        {{ t('NO_CALENDARS') }}
      </p>
      <label
        v-for="u in calendarUsers"
        :key="u.id"
        class="flex items-center gap-2 text-sm"
      >
        <input
          type="checkbox"
          class="!m-0"
          :checked="calendarOn(u.id)"
          @change="toggleCalendar(u.id)"
        />
        {{ u.name }}
      </label>
    </template>

    <template v-if="tab === 'follow'">
      <FollowUpPlan
        :value="settings.follow_up || { nudges: 2, templates: [] }"
        :templates="templates"
        :quote="settings.quote"
        kind="campaign_seller"
        @input="setSetting('follow_up', $event)"
      />
      <AfterHandoff
        :value="settings"
        :templates="templates"
        :appointments="appointments"
        @input="setSettings"
      />
    </template>

    <template v-if="tab === 'notes'">
      <label class="block">
        <span class="field-label">{{ t('INSTRUCTIONS') }}</span>
        <textarea
          rows="6"
          :value="settings.instructions"
          :placeholder="t('INSTRUCTIONS_PLACEHOLDER')"
          @input="setSetting('instructions', $event.target.value)"
        />
      </label>
    </template>
  </div>
</template>
