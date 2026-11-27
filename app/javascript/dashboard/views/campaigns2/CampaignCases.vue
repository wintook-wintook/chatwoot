<!--
  Campaña con IA — «Casos»: las pruebas que se arman solas con lo que tiene la campaña en pantalla
  (TrackingCampaigns::Motor2Cases): «sí me interesa», una duda, la palabra clave, «no puedo esta vez», «no me manden
  nada», algo de otro tema, un «gracias», la liga que no le llegó… Se corren cuando lo pides («Correr todos» o uno),
  una por una con la IA (sin mandar ni guardar nada), y cada una dice si salió bien, qué contestó y qué hizo.
  stored (.sync): los resultados y la huella de la campaña con la que corrieron; la pantalla los guarda, así que al
  regresar se siguen viendo, y si la campaña cambió avisa que hay que volver a correrlos.
-->
<script>
import Motor2CampaignsAPI from 'dashboard/api/motor2Campaigns';
import { signatureOf } from './campaignFlow';

export default {
  name: 'CampaignCases',
  props: {
    payload: { type: Function, required: true },
    disabled: { type: Boolean, default: false },
    stored: { type: Object, default: null },
  },
  emits: ['update:stored'],
  data() {
    return {
      cases: [],
      results: {},
      loading: false,
      running: false,
      error: false,
    };
  },
  computed: {
    done() {
      return Object.keys(this.results).length;
    },
    passed() {
      return Object.values(this.results).filter(r => r.ok).length;
    },
    // Corrieron con otra versión de la campaña.
    stale() {
      return (
        this.done > 0 &&
        !!this.stored &&
        this.stored.signature !== signatureOf(this.payload())
      );
    },
  },
  async mounted() {
    await this.load();
    if (this.stored?.results) this.results = { ...this.stored.results };
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.CASES.${key}`, params);
    },
    async load() {
      this.loading = true;
      this.error = false;
      try {
        const { data } = await Motor2CampaignsAPI.cases(this.payload());
        this.cases = data.cases || [];
      } catch (e) {
        this.error = true;
      } finally {
        this.loading = false;
      }
    },
    async runOne(key) {
      this.$set(this.results, key, { running: true });
      try {
        const { data } = await Motor2CampaignsAPI.runCase({
          ...this.payload(),
          key,
        });
        this.$set(this.results, key, data);
      } catch (e) {
        this.$set(this.results, key, { ok: false, reason: this.t('ERROR') });
      }
      this.remember();
    },
    async rebuild() {
      await this.load();
      this.results = {};
      this.remember();
    },
    remember() {
      this.$emit('update:stored', {
        signature: signatureOf(this.payload()),
        results: { ...this.results },
        total: this.cases.length,
      });
    },
    async runAll() {
      this.running = true;
      this.results = {};
      // Uno por uno: cada caso es una plática con la IA.
      // eslint-disable-next-line no-restricted-syntax
      for (const c of this.cases) {
        // eslint-disable-next-line no-await-in-loop
        await this.runOne(c.key);
      }
      this.running = false;
    },
    icon(result) {
      if (!result || result.running) return 'clock';
      return result.ok ? 'checkmark-circle' : 'dismiss-circle';
    },
    iconClass(result) {
      if (!result || result.running) return 'text-slate-400';
      return result.ok ? 'text-green-600' : 'text-red-600';
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <p class="m-0 text-xs text-slate-500">{{ t('HINT') }}</p>
    <div class="flex flex-wrap items-center gap-2">
      <woot-button
        size="small"
        icon="play-circle"
        :is-loading="running"
        :disabled="disabled || loading || !cases.length"
        @click="runAll"
      >
        {{ t('RUN_ALL') }}
      </woot-button>
      <woot-button
        size="small"
        variant="clear"
        :disabled="running"
        @click="rebuild"
      >
        {{ t('RELOAD') }}
      </woot-button>
      <span v-if="done" class="text-xs text-slate-600 dark:text-slate-300">
        {{ t('SCORE', { ok: passed, n: cases.length }) }}
      </span>
    </div>
    <p v-if="stale" class="m-0 text-xs text-amber-700">{{ t('STALE') }}</p>
    <p v-if="disabled" class="m-0 text-xs text-slate-500">
      {{ $t('CAMPAIGNS2.PREVIEW.PICK_CHANNEL') }}
    </p>
    <p v-if="loading" class="m-0 text-xs text-slate-500">{{ t('LOADING') }}</p>
    <p v-if="error" class="m-0 text-xs text-red-600">{{ t('ERROR') }}</p>
    <ul class="flex flex-col gap-1 m-0 list-none">
      <li
        v-for="c in cases"
        :key="c.key"
        class="flex flex-col gap-0.5 p-2 border rounded-md border-slate-100 dark:border-slate-700"
      >
        <div class="flex items-start gap-2">
          <fluent-icon
            :icon="icon(results[c.key])"
            size="16"
            class="mt-0.5 shrink-0"
            :class="iconClass(results[c.key])"
          />
          <div class="flex-1 min-w-0">
            <p class="m-0 text-sm font-medium">{{ c.title }}</p>
            <p class="m-0 text-xs text-slate-500">
              {{ t('SAYS', { message: c.message }) }}
            </p>
          </div>
          <button
            type="button"
            class="text-xs text-woot-600 hover:underline shrink-0"
            :disabled="running || disabled"
            @click="runOne(c.key)"
          >
            {{ t('RUN') }}
          </button>
        </div>
        <template v-if="results[c.key] && !results[c.key].running">
          <p
            v-if="results[c.key].reply"
            class="m-0 ml-6 text-xs whitespace-pre-line text-slate-700 dark:text-slate-200"
          >
            {{ results[c.key].reply }}
          </p>
          <p
            class="m-0 ml-6 text-[11px]"
            :class="results[c.key].ok ? 'text-slate-500' : 'text-red-600'"
          >
            {{ results[c.key].reason }}
            <span v-if="(results[c.key].tools || []).length">
              · {{ t('TOOLS', { names: results[c.key].tools.join(', ') }) }}
            </span>
          </p>
        </template>
      </li>
    </ul>
  </div>
</template>
