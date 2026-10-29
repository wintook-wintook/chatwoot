<script>
// proyecto@diagrama_agente_ia — F2/F3: EL PANEL «PRUEBAS»
// ============================================================================
// Plan: docs/diagrama_agente_ia_plan.md §4.1, §6 y §9.1. Columna izquierda, junto a
// Chat y Estructura (uno a la vez). Al elegir una prueba su camino se ilumina en la
// pestaña Diagrama (`select`); la pila entera alimenta el mapa de calor (`cases`).
//
// CON EL AGENTE GUARDADO (F3) la pila es la SUYA, en la base (TrackingTestCase):
//   Generar         las de ruta y regla que falten (no duplica)
//   Agregar         la escrita arriba, a la pila
//   En seco (todo)  toda la pila contra el BORRADOR, en segundo plano
//   En vivo (todo)  toda la pila con el agente guardado, en el canal de pruebas
//   📌              fijada: se ofrece en vivo en cada publicación (D5)
//
// AL PUBLICAR (D5) el backend corre la pila en seco solo; al volver aquí se ve el
// aviso: «sigue igual», o «N cambiaron de camino» con el botón para probar en vivo
// solo esas (más las rojas y las fijadas) y su costo estimado en tokens.
//
// SIN GUARDAR solo hay pruebas en seco sueltas contra el borrador, que viven
// mientras la pantalla esté abierta (`looseTests`). Cada una avisa a la pantalla
// (`dryRun`) para que cuente en la tira de avance («Probado»).
// ============================================================================
import AssistantAPI from 'dashboard/api/assistant';
import testBatteryRunner from './testBatteryRunner';

const DRY_POLL_MS = 3000;
const SEEN_PREFIX = 'assistant/tests/publish-seen/';

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
  emits: ['select', 'cases', 'dryRun'],
  data() {
    return {
      question: '',
      cases: [],
      dryRun: null,
      liveOffer: null,
      looseTests: [],
      busy: '',
      panelError: '',
      selectedKey: null,
      selectedMode: null,
      dryTimer: null,
      publishSeen: false,
    };
  },
  computed: {
    batteryTemplateId() {
      return this.templateId;
    },
    batteryBriefId() {
      return this.briefId;
    },
    saved() {
      return Boolean(this.templateId);
    },
    dryRunning() {
      return Boolean(
        this.dryRun && ['queued', 'running'].includes(this.dryRun.status)
      );
    },
    statusLine() {
      if (this.running) return this.progress;
      if (this.dryRunning)
        return this.t('DRY_PROGRESS', {
          done: this.dryRun.done || 0,
          total: this.dryRun.total || this.cases.length,
        });
      return this.liveSummary;
    },
    rows() {
      const guardadas = this.cases.map(c => ({
        key: `case:${c.id}`,
        id: c.id,
        message: c.message,
        kind: c.kind,
        pinned: c.pinned,
        changed: c.dry_changed === true,
        live: c.last_live && c.last_live.at ? c.last_live : null,
        dry: c.last_dry && c.last_dry.at ? c.last_dry.informe : null,
      }));
      const sueltas = this.looseTests.map(p => ({
        key: p.key,
        message: p.message,
        kind: 'suelta',
        live: null,
        dry: p.result,
      }));
      return [...guardadas, ...sueltas];
    },
    selected() {
      return this.rows.find(r => r.key === this.selectedKey) || null;
    },
    liveSummary() {
      const corridas = this.rows.filter(r => r.live);
      if (!corridas.length) return '';
      return this.$t('TRACKING_ASSISTANT_VIEW.BATTERY_SUMMARY', {
        passed: corridas.filter(r => r.live.cumple).length,
        total: corridas.length,
      });
    },
    // El aviso de después de publicar (D5).
    publishNotice() {
      if (this.publishSeen || !this.dryRun) return null;
      if (this.dryRun.trigger !== 'publish' || this.dryRun.status !== 'done')
        return null;
      const ofrecidas = (this.liveOffer && this.liveOffer.case_ids) || [];
      const cambiaron = (this.dryRun.changed || []).length;
      return {
        same: cambiaron === 0,
        changed: cambiaron,
        offer: ofrecidas,
        tokens: this.liveOffer && this.liveOffer.tokens,
        total: this.dryRun.total,
      };
    },
    publishClass() {
      return this.publishNotice &&
        this.publishNotice.same &&
        !this.publishNotice.offer.length
        ? 'bg-green-50 dark:bg-green-900/20 text-green-800 dark:text-green-200'
        : 'bg-amber-50 dark:bg-amber-900/20 text-amber-900 dark:text-amber-200';
    },
    publishRunLabel() {
      const aviso = this.publishNotice;
      if (!aviso) return '';
      return aviso.tokens
        ? this.t('PUBLISH_RUN_LIVE_COST', {
            count: aviso.offer.length,
            tokens: aviso.tokens,
          })
        : this.t('PUBLISH_RUN_LIVE', { count: aviso.offer.length });
    },
  },
  watch: {
    templateId: {
      immediate: true,
      handler() {
        this.stop();
        this.state = null;
        this.batteryId = null;
        this.cases = [];
        this.dryRun = null;
        this.liveOffer = null;
        this.fetchPile();
      },
    },
    cases(lista) {
      this.$emit('cases', lista);
    },
    // Al terminar una corrida en vivo, sus resultados ya están en cada prueba.
    stateStatus(estado) {
      if (estado === 'done') this.fetchPile();
    },
  },
  beforeDestroy() {
    clearTimeout(this.dryTimer);
  },
  methods: {
    t(key, args) {
      return this.$t(`TRACKING_ASSISTANT_VIEW.TESTS.${key}`, args);
    },
    async fetchPile() {
      clearTimeout(this.dryTimer);
      if (!this.saved) return;
      try {
        const { data } = await AssistantAPI.testCases(this.templateId);
        this.cases = data.cases || [];
        this.dryRun = data.dry_run || null;
        this.liveOffer = data.live_offer || null;
        this.publishSeen = this.seenPublish();
        if (this.dryRunning)
          this.dryTimer = setTimeout(this.fetchPile, DRY_POLL_MS);
      } catch (error) {
        this.panelError = this.t('LOAD_FAILED');
      }
    },
    seenKey() {
      return `${SEEN_PREFIX}${this.templateId}`;
    },
    seenPublish() {
      if (!this.dryRun) return false;
      try {
        return (
          window.localStorage.getItem(this.seenKey()) === this.dryRun.started_at
        );
      } catch (error) {
        return false;
      }
    },
    dismissPublish() {
      this.publishSeen = true;
      try {
        window.localStorage.setItem(this.seenKey(), this.dryRun.started_at);
      } catch (error) {
        // Sin almacenamiento el aviso vuelve a salir al regresar.
      }
    },
    async act(nombre, accion) {
      if (this.busy) return;
      this.busy = nombre;
      this.panelError = '';
      try {
        await accion();
      } catch (error) {
        const code =
          error.response && error.response.data && error.response.data.error;
        this.panelError =
          code === 'no_sandbox'
            ? this.$t('TRACKING_ASSISTANT_VIEW.BATTERY_NO_SANDBOX')
            : this.t('ACTION_FAILED');
      } finally {
        this.busy = '';
      }
    },
    generate() {
      return this.act('generate', async () => {
        await AssistantAPI.generateTestCases(this.templateId, {
          briefId: this.briefId,
        });
        await this.fetchPile();
      });
    },
    addCase() {
      const texto = this.question.trim();
      if (!texto) return null;
      return this.act('add', async () => {
        await AssistantAPI.addTestCase(this.templateId, texto);
        this.question = '';
        await this.fetchPile();
      });
    },
    runAllDry() {
      return this.act('dry', async () => {
        await AssistantAPI.runTestCasesDry(
          this.templateId,
          this.draft,
          this.inboxId
        );
        await this.fetchPile();
      });
    },
    runLive(ids) {
      if (!ids.length || this.running) return null;
      return this.act('live', async () => {
        const { data } = await AssistantAPI.runTestCasesLive(
          this.templateId,
          ids
        );
        this.resume(data.id);
      });
    },
    runAllLive() {
      return this.runLive(this.cases.map(c => c.id));
    },
    runOffer() {
      const ids = this.publishNotice ? this.publishNotice.offer : [];
      this.dismissPublish();
      return this.runLive(ids);
    },
    togglePin(fila) {
      return this.act('pin', async () => {
        await AssistantAPI.pinTestCase(fila.id, !fila.pinned);
        await this.fetchPile();
      });
    },
    remove(fila) {
      return this.act('remove', async () => {
        await AssistantAPI.deleteTestCase(fila.id);
        if (this.selectedKey === fila.key) this.selectedKey = null;
        await this.fetchPile();
      });
    },
    // El informe .md de la última corrida en vivo (la «evidencia»; antes estaba en el modal).
    async download() {
      const { data } = await AssistantAPI.downloadTestBatteryReport(
        this.batteryId
      );
      const enlace = document.createElement('a');
      enlace.href = URL.createObjectURL(data);
      enlace.download = `pila_${this.templateId}.md`;
      enlace.click();
      URL.revokeObjectURL(enlace.href);
    },
    onEnter() {
      return this.saved ? this.addCase() : this.runLooseDry();
    },
    // Una en seco suelta, contra el borrador (también sin guardar).
    runLooseDry() {
      const pregunta = this.question.trim();
      if (!pregunta) return null;
      return this.act('loose', async () => {
        const { data } = await AssistantAPI.dryRun(
          this.draft,
          pregunta,
          this.inboxId
        );
        const key = `loose:${Date.now()}`;
        this.looseTests.unshift({ key, message: pregunta, result: data });
        this.question = '';
        this.$emit('dryRun', { question: pregunta, result: data });
        this.choose(
          this.rows.find(r => r.key === key),
          'dry'
        );
      });
    },
    // En vivo si corrió en vivo; si no, en seco.
    choose(fila, modo = null) {
      if (!fila) return;
      const elegido = modo || (fila.live ? 'live' : 'dry');
      this.selectedKey = fila.key;
      this.selectedMode = elegido;
      if (elegido === 'live' && fila.live) {
        this.$emit('select', {
          mode: 'live',
          traza: fila.live.traza || null,
          reply: fila.live.reply,
        });
      } else if (fila.dry) {
        this.$emit('select', { mode: 'dry', result: fila.dry });
      }
    },
    mark(fila) {
      if (fila.live && fila.live.cumple === true) return '✅';
      if (fila.live && fila.live.cumple === false) return '❌';
      if (fila.dry) return '·';
      return '○';
    },
    routeOf(fila) {
      const traza = fila.live && fila.live.traza;
      if (traza && traza.ruta && traza.ruta.nombre) return traza.ruta.nombre;
      if (fila.dry && fila.dry.routes) return fila.dry.routes.chosen || '—';
      return '—';
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 gap-3">
    <p class="m-0 text-xs shrink-0 text-slate-500 dark:text-slate-400">
      {{ saved ? t('HINT') : t('HINT_UNSAVED') }}
    </p>

    <div
      v-if="publishNotice"
      class="flex flex-col gap-2 p-3 text-xs rounded-lg shrink-0"
      :class="publishClass"
    >
      <span v-if="publishNotice.same">
        {{ t('PUBLISH_SAME', { total: publishNotice.total }) }}
      </span>
      <span v-else>
        {{ t('PUBLISH_CHANGED', { count: publishNotice.changed }) }}
      </span>
      <div class="flex flex-wrap items-center gap-2">
        <woot-button
          v-if="publishNotice.offer.length"
          size="tiny"
          icon="play-circle"
          :is-disabled="running"
          @click="runOffer"
        >
          {{ publishRunLabel }}
        </woot-button>
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          @click="dismissPublish"
        >
          {{ t('PUBLISH_DISMISS') }}
        </woot-button>
      </div>
    </div>

    <div class="flex flex-col gap-2 shrink-0">
      <textarea
        v-model="question"
        rows="2"
        class="text-sm resize-none !mb-0"
        :placeholder="t('PLACEHOLDER')"
        @keydown.enter.exact.prevent="onEnter"
      />
      <div class="flex flex-wrap items-center gap-2">
        <woot-button
          v-if="saved"
          size="small"
          variant="smooth"
          icon="add"
          :is-loading="busy === 'add'"
          :is-disabled="!question.trim() || Boolean(busy)"
          @click="addCase"
        >
          {{ t('ADD') }}
        </woot-button>
        <woot-button
          size="small"
          variant="smooth"
          color-scheme="secondary"
          icon="flash-on"
          :is-loading="busy === 'loose'"
          :is-disabled="!question.trim() || Boolean(busy)"
          :title="t('DRY_HINT')"
          @click="runLooseDry"
        >
          {{ t('RUN_DRY') }}
        </woot-button>
      </div>
    </div>

    <div
      v-if="saved"
      class="flex flex-wrap items-center gap-2 pt-2 border-t shrink-0 border-slate-100 dark:border-slate-700"
    >
      <woot-button
        size="small"
        variant="clear"
        icon="add"
        :is-loading="busy === 'generate'"
        :is-disabled="Boolean(busy)"
        :title="t('GENERATE_HINT')"
        @click="generate"
      >
        {{ t('GENERATE') }}
      </woot-button>
      <woot-button
        size="small"
        variant="clear"
        color-scheme="secondary"
        icon="flash-on"
        :is-loading="dryRunning || busy === 'dry'"
        :is-disabled="!cases.length || dryRunning || Boolean(busy)"
        :title="t('RUN_ALL_DRY_HINT')"
        @click="runAllDry"
      >
        {{ t('RUN_ALL_DRY') }}
      </woot-button>
      <woot-button
        size="small"
        variant="clear"
        color-scheme="secondary"
        icon="play-circle"
        :is-loading="running || busy === 'live'"
        :is-disabled="!cases.length || running || Boolean(busy)"
        :title="t('RUN_ALL_LIVE_HINT')"
        @click="runAllLive"
      >
        {{ t('RUN_ALL_LIVE') }}
      </woot-button>
    </div>
    <div
      v-if="statusLine || (batteryId && stateStatus === 'done')"
      class="flex flex-wrap items-center gap-2 shrink-0"
    >
      <span class="text-xs text-slate-600 dark:text-slate-300">
        {{ statusLine }}
      </span>
      <woot-button
        v-if="batteryId && stateStatus === 'done'"
        size="tiny"
        variant="clear"
        color-scheme="secondary"
        icon="arrow-download"
        @click="download"
      >
        {{ $t('TRACKING_ASSISTANT_VIEW.BATTERY_DOWNLOAD') }}
      </woot-button>
    </div>
    <p
      v-if="panelError || error"
      class="p-2 m-0 text-xs rounded-lg shrink-0 bg-amber-50 dark:bg-amber-900/20 text-amber-900 dark:text-amber-200"
    >
      {{ panelError || error }}
    </p>

    <div class="flex-1 min-h-0 overflow-y-auto">
      <p
        v-if="!rows.length"
        class="m-0 text-xs text-center text-slate-400 dark:text-slate-500"
      >
        {{ saved ? t('EMPTY') : t('EMPTY_UNSAVED') }}
      </p>
      <ul v-else class="flex flex-col gap-1 p-0 m-0 list-none">
        <li
          v-for="fila in rows"
          :key="fila.key"
          class="flex items-center gap-1 rounded-md"
          :class="
            selectedKey === fila.key
              ? 'bg-woot-50 dark:bg-slate-700 ring-1 ring-woot-500'
              : 'hover:bg-slate-50 dark:hover:bg-slate-700'
          "
        >
          <button
            type="button"
            class="flex items-center flex-1 min-w-0 gap-2 px-2 py-1.5 text-xs text-left"
            @click="choose(fila)"
          >
            <span class="shrink-0">{{ mark(fila) }}</span>
            <span
              class="flex-1 min-w-0 truncate text-slate-800 dark:text-slate-100"
            >
              {{ fila.message }}
            </span>
            <span
              v-if="fila.changed"
              class="shrink-0 px-1 rounded text-[10px] bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-200"
            >
              {{ t('CHANGED') }}
            </span>
            <span class="shrink-0 text-slate-500 dark:text-slate-400">
              {{ routeOf(fila) }}
            </span>
          </button>
          <woot-button
            v-if="fila.id"
            size="tiny"
            variant="clear"
            :color-scheme="fila.pinned ? 'primary' : 'secondary'"
            icon="pin"
            :title="fila.pinned ? t('UNPIN') : t('PIN')"
            @click="togglePin(fila)"
          />
          <woot-button
            v-if="fila.id"
            size="tiny"
            variant="clear"
            color-scheme="secondary"
            icon="dismiss"
            :title="t('REMOVE')"
            @click="remove(fila)"
          />
        </li>
      </ul>
    </div>

    <div
      v-if="selected"
      class="flex flex-col gap-1 pt-3 text-xs border-t shrink-0 border-slate-100 dark:border-slate-700 max-h-[40%] overflow-y-auto"
    >
      <div v-if="selected.live && selected.dry" class="flex items-center gap-1">
        <woot-button
          size="tiny"
          :variant="selectedMode === 'live' ? 'smooth' : 'clear'"
          color-scheme="secondary"
          @click="choose(selected, 'live')"
        >
          {{ t('VIEW_LIVE') }}
        </woot-button>
        <woot-button
          size="tiny"
          :variant="selectedMode === 'dry' ? 'smooth' : 'clear'"
          color-scheme="secondary"
          @click="choose(selected, 'dry')"
        >
          {{ t('VIEW_DRY') }}
        </woot-button>
      </div>
      <p class="m-0 text-slate-800 dark:text-slate-100">
        <strong>{{ t('CUSTOMER') }}</strong> {{ selected.message }}
      </p>
      <template v-if="selectedMode === 'live' && selected.live">
        <p class="m-0 whitespace-pre-line text-slate-800 dark:text-slate-100">
          <strong>{{ t('AGENT') }}</strong>
          {{ selected.live.reply || t('NO_REPLY') }}
        </p>
        <p
          v-if="selected.live.motivo"
          class="m-0 text-slate-600 dark:text-slate-300"
        >
          <strong>{{ t('VERDICT') }}</strong> {{ mark(selected) }}
          {{ selected.live.motivo }}
        </p>
        <p v-if="selected.live.conversation" class="m-0 text-slate-500">
          {{ t('CONVERSATION', { id: selected.live.conversation }) }}
        </p>
        <p
          v-if="!selected.live.traza"
          class="m-0 text-amber-700 dark:text-amber-400"
        >
          {{ t('NO_TRACE') }}
        </p>
      </template>
      <p v-else-if="selected.dry" class="m-0 text-slate-500">
        {{ t('DRY_NOTE') }}
      </p>
      <p v-else class="m-0 text-slate-500">{{ t('NEVER_RUN') }}</p>
    </div>
  </div>
</template>
