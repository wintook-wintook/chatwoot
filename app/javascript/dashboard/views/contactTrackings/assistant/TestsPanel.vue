<script>
// proyecto@diagrama_agente_ia — F2: EL PANEL «PRUEBAS»
// ============================================================================
// Plan: docs/diagrama_agente_ia_plan.md §4.1. Columna izquierda, junto a Chat y
// Estructura (uno a la vez). Aquí se escriben y se corren las pruebas, y al elegir
// una su camino se ilumina en la pestaña Diagrama (`select`).
//
//   EN SECO   contra el BORRADOR, sin redactar ni enviar nada (DryRunService):
//             ruta, fuente, fragmentos. Barato, se puede antes de guardar.
//   EN VIVO   el agente GUARDADO contesta de verdad en el canal de pruebas
//             (TestBatteryJob): respuesta, veredicto del juez y la traza de F0.
//
// «Correr la pila» son las pruebas que genera el backend (una por ruta y una por
// regla); «Probar en vivo» corre solo la escrita aquí. La última pila del agente se
// retoma al volver (vive dos días en la caché del backend; aquí solo se recuerda
// su id, por agente, en localStorage).
//
// Las pruebas en seco viven mientras la pantalla esté abierta: guardarlas es F3.
// ============================================================================
import AssistantAPI from 'dashboard/api/assistant';
import testBatteryRunner from './testBatteryRunner';

const STORAGE_PREFIX = 'assistant/tests/battery/';

export default {
  name: 'TestsPanel',
  mixins: [testBatteryRunner],
  props: {
    // null mientras el agente no está guardado: entonces solo en seco.
    templateId: { type: Number, default: null },
    draft: { type: String, default: '' },
    inboxId: { type: Number, default: null },
    briefId: { type: Number, default: null },
  },
  emits: ['select'],
  data() {
    return {
      question: '',
      dryTests: [],
      dryRunning: false,
      dryError: '',
      selectedKey: null,
    };
  },
  computed: {
    batteryTemplateId() {
      return this.templateId;
    },
    batteryBriefId() {
      return this.briefId;
    },
    canLive() {
      return Boolean(this.templateId);
    },
    liveTests() {
      return this.results.map((r, i) => ({
        key: `live:${this.batteryId}:${i}`,
        mode: 'live',
        message: r.message,
        reply: r.reply,
        ok: typeof r.cumple === 'boolean' ? r.cumple : null,
        routeOk: r.ruta_ok,
        route: r.traza && r.traza.ruta ? r.traza.ruta.nombre : '',
        motivo: r.motivo,
        fallas: r.fallas || [],
        conversation: r.conversation,
        traza: r.traza || null,
      }));
    },
    tests() {
      return [...this.liveTests, ...this.dryTests];
    },
    selected() {
      return this.tests.find(t => t.key === this.selectedKey) || null;
    },
    summary() {
      if (!this.liveTests.length) return '';
      return this.$t('TRACKING_ASSISTANT_VIEW.BATTERY_SUMMARY', {
        passed: this.passed,
        total: this.liveTests.length,
      });
    },
  },
  watch: {
    templateId: {
      immediate: true,
      handler(id) {
        this.stop();
        this.state = null;
        this.batteryId = null;
        this.resume(this.rememberedBattery(id));
      },
    },
    batteryId(id) {
      this.rememberBattery(id);
    },
  },
  methods: {
    t(key, args) {
      return this.$t(`TRACKING_ASSISTANT_VIEW.TESTS.${key}`, args);
    },
    storageKey(id) {
      return `${STORAGE_PREFIX}${id}`;
    },
    rememberedBattery(id) {
      if (!id) return null;
      try {
        return window.localStorage.getItem(this.storageKey(id));
      } catch (error) {
        return null;
      }
    },
    rememberBattery(battery) {
      if (!this.templateId) return;
      try {
        if (battery)
          window.localStorage.setItem(
            this.storageKey(this.templateId),
            battery
          );
      } catch (error) {
        // Sin almacenamiento solo se pierde retomarla al volver.
      }
    },
    async runDry() {
      const pregunta = this.question.trim();
      if (!pregunta || this.dryRunning) return;
      this.dryRunning = true;
      this.dryError = '';
      try {
        const { data } = await AssistantAPI.dryRun(
          this.draft,
          pregunta,
          this.inboxId
        );
        const prueba = {
          key: `dry:${Date.now()}`,
          mode: 'dry',
          message: pregunta,
          reply: '',
          ok: null,
          route: data.routes ? data.routes.chosen : '',
          result: data,
        };
        this.dryTests.unshift(prueba);
        this.question = '';
        this.choose(prueba);
      } catch (error) {
        this.dryError = this.t('DRY_FAILED');
      } finally {
        this.dryRunning = false;
      }
    },
    async runLiveOne() {
      const pregunta = this.question.trim();
      if (!pregunta || !this.canLive) return;
      if (await this.start([pregunta])) this.question = '';
    },
    runBattery() {
      this.start();
    },
    choose(prueba) {
      this.selectedKey = prueba.key;
      this.$emit(
        'select',
        prueba.mode === 'dry'
          ? { mode: 'dry', result: prueba.result }
          : { mode: 'live', traza: prueba.traza, reply: prueba.reply }
      );
    },
    mark(prueba) {
      if (prueba.mode === 'dry') return '·';
      if (prueba.ok === true) return '✅';
      if (prueba.ok === false) return '❌';
      return '…';
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 gap-3">
    <p class="m-0 text-xs shrink-0 text-slate-500 dark:text-slate-400">
      {{ t('HINT') }}
    </p>

    <div class="flex flex-col gap-2 shrink-0">
      <textarea
        v-model="question"
        rows="2"
        class="text-sm resize-none !mb-0"
        :placeholder="t('PLACEHOLDER')"
        @keydown.enter.exact.prevent="runDry"
      />
      <div class="flex flex-wrap items-center gap-2">
        <woot-button
          size="small"
          variant="smooth"
          icon="flash-on"
          :is-loading="dryRunning"
          :is-disabled="!question.trim() || dryRunning"
          :title="t('DRY_HINT')"
          @click="runDry"
        >
          {{ t('RUN_DRY') }}
        </woot-button>
        <woot-button
          size="small"
          variant="smooth"
          color-scheme="secondary"
          icon="play-circle"
          :is-disabled="!question.trim() || !canLive || running"
          :title="canLive ? t('LIVE_HINT') : t('SAVE_FIRST')"
          @click="runLiveOne"
        >
          {{ t('RUN_LIVE') }}
        </woot-button>
        <woot-button
          size="small"
          variant="clear"
          color-scheme="secondary"
          icon="play-circle"
          :is-loading="running"
          :is-disabled="!canLive || running"
          :title="canLive ? t('BATTERY_HINT') : t('SAVE_FIRST')"
          @click="runBattery"
        >
          {{ t('RUN_BATTERY') }}
        </woot-button>
      </div>
      <p v-if="!canLive" class="m-0 text-xs text-slate-500 dark:text-slate-400">
        {{ t('SAVE_FIRST') }}
      </p>
      <p
        v-if="running || summary"
        class="m-0 text-xs text-slate-600 dark:text-slate-300"
      >
        {{ running ? progress : summary }}
      </p>
      <p
        v-if="error || dryError"
        class="p-2 m-0 text-xs rounded-lg bg-amber-50 dark:bg-amber-900/20 text-amber-900 dark:text-amber-200"
      >
        {{ error || dryError }}
      </p>
    </div>

    <div class="flex-1 min-h-0 overflow-y-auto">
      <p
        v-if="!tests.length"
        class="m-0 text-xs text-center text-slate-400 dark:text-slate-500"
      >
        {{ t('EMPTY') }}
      </p>
      <ul v-else class="flex flex-col gap-1 p-0 m-0 list-none">
        <li v-for="prueba in tests" :key="prueba.key">
          <button
            type="button"
            class="flex items-start w-full gap-2 px-2 py-1.5 text-xs text-left rounded-md hover:bg-slate-50 dark:hover:bg-slate-700"
            :class="
              selectedKey === prueba.key
                ? 'bg-woot-50 dark:bg-slate-700 ring-1 ring-woot-500'
                : ''
            "
            @click="choose(prueba)"
          >
            <span class="shrink-0">{{ mark(prueba) }}</span>
            <span
              class="flex-1 min-w-0 truncate text-slate-800 dark:text-slate-100"
            >
              {{ prueba.message }}
            </span>
            <span class="shrink-0 text-slate-500 dark:text-slate-400">
              {{ prueba.route || '—' }}
            </span>
            <span
              class="shrink-0 px-1 rounded text-[10px] uppercase"
              :class="
                prueba.mode === 'dry'
                  ? 'bg-slate-100 text-slate-600 dark:bg-slate-600 dark:text-slate-200'
                  : 'bg-woot-50 text-woot-700 dark:bg-woot-800 dark:text-woot-100'
              "
            >
              {{ prueba.mode === 'dry' ? t('MODE_DRY') : t('MODE_LIVE') }}
            </span>
          </button>
        </li>
      </ul>
    </div>

    <div
      v-if="selected"
      class="flex flex-col gap-1 pt-3 text-xs border-t shrink-0 border-slate-100 dark:border-slate-700 max-h-[40%] overflow-y-auto"
    >
      <p class="m-0 text-slate-800 dark:text-slate-100">
        <strong>{{ t('CUSTOMER') }}</strong> {{ selected.message }}
      </p>
      <p
        v-if="selected.mode === 'live'"
        class="m-0 whitespace-pre-line text-slate-800 dark:text-slate-100"
      >
        <strong>{{ t('AGENT') }}</strong> {{ selected.reply || t('NO_REPLY') }}
      </p>
      <p
        v-if="selected.mode === 'live' && selected.motivo"
        class="m-0 text-slate-600 dark:text-slate-300"
      >
        <strong>{{ t('VERDICT') }}</strong> {{ mark(selected) }}
        {{ selected.motivo }}
        <span v-if="selected.fallas.length">
          · {{ selected.fallas.join(' · ') }}
        </span>
      </p>
      <p v-if="selected.mode === 'dry'" class="m-0 text-slate-500">
        {{ t('DRY_NOTE') }}
      </p>
      <p v-if="selected.conversation" class="m-0 text-slate-500">
        {{ t('CONVERSATION', { id: selected.conversation }) }}
      </p>
      <p
        v-if="selected.mode === 'live' && !selected.traza"
        class="m-0 text-amber-700 dark:text-amber-400"
      >
        {{ t('NO_TRACE') }}
      </p>
    </div>
  </div>
</template>
