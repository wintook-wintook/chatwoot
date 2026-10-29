<script>
// proyecto@diagrama_agente_ia — F2/F3: EL PANEL «PRUEBAS»
// ============================================================================
// Plan: docs/diagrama_agente_ia_plan.md §4.1, §6 y §9.1. La columna izquierda de la
// pestaña «Pruebas y diagrama» del espacio del agente; a la derecha, el diagrama. Al
// elegir una prueba su camino se ilumina ahí (`select`); la pila entera alimenta el
// mapa de calor (`cases`).
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
// F4 — LA PRUEBA COMO EVIDENCIA (§4.4 y §5):
//   💬 Llevar al chat   la prueba elegida (o todas las rojas) va al chat de creación
//                       con su camino y su veredicto (`evidence`); el Asistente
//                       propone el cambio
//   Antes / ahora       la corrida anterior contra la última, y «Ver antes» la
//                       ilumina en el diagrama
//   Sugerir con IA      las pruebas sugeridas (antes en el modal «Probar sin enviar
//                       nada»), cada una con su ruta esperada, para agregarlas
//
// F5:
//   Diálogo            un mensaje por línea (2–4): en vivo el agente contesta cada uno;
//                      en seco el último se clasifica con los anteriores de contexto
//   Comparar           toda la pila en seco contra una versión guardada y contra el
//                      borrador: qué pruebas toman otro camino («Ver en la v7»)
//
// SIN GUARDAR solo hay pruebas en seco sueltas contra el borrador, que viven
// mientras la pantalla esté abierta (`looseTests`). Cada una avisa a la pantalla
// (`dryRun`) para que cuente en la tira de avance («Probado»).
// ============================================================================
import AssistantAPI from 'dashboard/api/assistant';
import TrackingTemplatesAPI from 'dashboard/api/trackingTemplates';
import testBatteryRunner from './testBatteryRunner';
import { evidenceMessage, pathSummary, compareRuns } from './testEvidence';

const DRY_POLL_MS = 3000;
const MAX_TURNS = 4;
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
    // F4: hay Entrenamiento en pantalla, así que el chat puede corregirlo.
    canSendToChat: { type: Boolean, default: false },
  },
  emits: ['select', 'cases', 'dryRun', 'evidence'],
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
      suggestions: null,
      dialogMode: false,
      compare: null,
      versions: null,
      versionId: null,
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
    // F5: con «Diálogo», un mensaje del cliente por línea.
    turns() {
      if (!this.dialogMode) return [this.question.trim()].filter(Boolean);
      return this.question
        .split('\n')
        .map(l => l.trim())
        .filter(Boolean)
        .slice(0, MAX_TURNS);
    },
    canAdd() {
      return this.dialogMode ? this.turns.length >= 2 : this.turns.length === 1;
    },
    compareRunning() {
      return Boolean(
        this.compare && ['queued', 'running'].includes(this.compare.status)
      );
    },
    compareDone() {
      return Boolean(this.compare && this.compare.status === 'done');
    },
    compareDiffers() {
      if (!this.compareDone) return [];
      const resultados = this.compare.results || {};
      return Object.keys(resultados).filter(id => !resultados[id].same);
    },
    compareLine() {
      if (this.compareRunning)
        return this.t('COMPARE_PROGRESS', {
          done: this.compare.done || 0,
          total: this.compare.total || 0,
        });
      return this.t('COMPARE_RESULT', {
        version: this.compare.version,
        count: this.compareDiffers.length,
        total: this.compare.total,
      });
    },
    compareClass() {
      return this.compareDiffers.length
        ? 'text-amber-700 dark:text-amber-400'
        : 'text-slate-600 dark:text-slate-300';
    },
    viewComparedLabel() {
      const resultado = this.selectedCompare;
      return this.t('VIEW_IN_VERSION', {
        version: this.compare ? this.compare.version : '',
        route:
          (resultado && resultado.version && resultado.version.route) || '—',
      });
    },
    // La comparación de la prueba elegida, si la hay.
    selectedCompare() {
      if (!this.compareDone || !this.selected || !this.selected.id) return null;
      return (this.compare.results || {})[String(this.selected.id)] || null;
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
        prevLive:
          c.previous_live && c.previous_live.at ? c.previous_live : null,
        prevDry:
          c.previous_dry && c.previous_dry.at ? c.previous_dry.informe : null,
        turns: c.turns || [],
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
    failingRows() {
      return this.rows.filter(r => r.live && r.live.cumple === false);
    },
    comparison() {
      return compareRuns(this.cases);
    },
    // Antes / ahora de la prueba elegida, en el modo que se está viendo.
    history() {
      const fila = this.selected;
      if (!fila) return null;
      const vivo = this.selectedMode === 'live';
      const antes = vivo ? fila.prevLive : fila.prevDry;
      const ahora = vivo ? fila.live : fila.dry;
      if (!antes || !ahora) return null;
      const modo = vivo ? 'live' : 'dry';
      const tt = (k, a) => this.t(k, a);
      return {
        before: pathSummary(modo, antes, tt),
        now: pathSummary(modo, ahora, tt),
        beforeMark: vivo ? this.mark({ live: antes }) : '·',
        nowMark: vivo ? this.mark({ live: ahora }) : '·',
      };
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
        this.compare = data.compare || null;
        this.publishSeen = this.seenPublish();
        if (this.dryRunning || this.compareRunning)
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
      if (!this.canAdd) return null;
      const mensajes = this.turns;
      return this.act('add', async () => {
        await AssistantAPI.addTestCase(
          this.templateId,
          mensajes[0],
          null,
          mensajes.length > 1 ? mensajes : null
        );
        this.question = '';
        await this.fetchPile();
      });
    },
    // F5: comparar contra una versión guardada.
    loadVersions() {
      return this.act('versions', async () => {
        const { data } = await TrackingTemplatesAPI.getVersions(
          this.templateId
        );
        this.versions = data.versions || [];
        this.versionId = this.versions.length ? this.versions[0].id : null;
      });
    },
    runCompare() {
      if (!this.versionId) return null;
      return this.act('compare', async () => {
        await AssistantAPI.compareTestCases(
          this.templateId,
          this.versionId,
          this.draft,
          this.inboxId
        );
        this.versions = null;
        await this.fetchPile();
      });
    },
    viewCompared() {
      const resultado = this.selectedCompare;
      if (resultado && resultado.version && resultado.version.informe)
        this.$emit('select', {
          mode: 'dry',
          result: resultado.version.informe,
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
    // F4: al chat de creación, con su camino y su veredicto.
    sendEvidence(filas) {
      const texto = evidenceMessage(filas, (k, a) => this.t(k, a));
      if (texto) this.$emit('evidence', texto);
    },
    viewBefore() {
      const fila = this.selected;
      if (!fila) return;
      if (this.selectedMode === 'live' && fila.prevLive) {
        this.$emit('select', {
          mode: 'live',
          traza: fila.prevLive.traza || null,
          reply: fila.prevLive.reply,
        });
      } else if (fila.prevDry) {
        this.$emit('select', { mode: 'dry', result: fila.prevDry });
      }
    },
    // Las pruebas sugeridas por IA (Fase E), contra el borrador.
    suggest() {
      return this.act('suggest', async () => {
        const { data } = await AssistantAPI.suggestedTests(
          this.draft,
          null,
          this.inboxId
        );
        this.suggestions = data.cases || [];
      });
    },
    addSuggestion(sugerida) {
      if (!this.saved) {
        // Sin guardar queda como prueba suelta: se sabe a qué ruta cayó, no más.
        this.looseTests.unshift({
          key: `loose:${Date.now()}:${this.looseTests.length}`,
          message: sugerida.message,
          result: {
            routes: { chosen: sugerida.chosen },
            tag: sugerida.tag,
          },
        });
        this.suggestions = this.suggestions.filter(s => s !== sugerida);
        return null;
      }
      return this.act('add', async () => {
        await AssistantAPI.addTestCase(
          this.templateId,
          sugerida.message,
          sugerida.expected || null
        );
        this.suggestions = this.suggestions.filter(s => s !== sugerida);
        await this.fetchPile();
      });
    },
    suggestionMark(sugerida) {
      if (sugerida.pass === true) return '✅';
      if (sugerida.pass === false) return '❌';
      return '·';
    },
    // Enter agrega (o prueba en seco); en un diálogo, Enter es otra línea.
    onEnterKey(evento) {
      if (this.dialogMode) return null;
      evento.preventDefault();
      return this.saved ? this.addCase() : this.runLooseDry();
    },
    // Una en seco suelta, contra el borrador (también sin guardar). En un diálogo,
    // el último mensaje con los anteriores de contexto.
    runLooseDry() {
      const mensajes = this.turns;
      if (!mensajes.length) return null;
      const pregunta = mensajes[mensajes.length - 1];
      const contexto = mensajes
        .slice(0, -1)
        .map(m => `Cliente: ${m}`)
        .join('\n');
      return this.act('loose', async () => {
        const { data } = await AssistantAPI.dryRun(
          this.draft,
          pregunta,
          this.inboxId,
          contexto || null
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
        :rows="dialogMode ? 4 : 2"
        class="text-sm resize-none !mb-0"
        :placeholder="dialogMode ? t('PLACEHOLDER_DIALOG') : t('PLACEHOLDER')"
        @keydown.enter.exact="onEnterKey"
      />
      <label
        class="flex items-center gap-2 text-xs text-slate-600 dark:text-slate-300"
      >
        <input v-model="dialogMode" type="checkbox" class="!m-0" />
        {{ t('DIALOG_MODE') }}
        <span v-if="dialogMode" class="text-slate-400">
          {{ t('DIALOG_COUNT', { count: turns.length, max: 4 }) }}
        </span>
      </label>
      <div class="flex flex-wrap items-center gap-2">
        <woot-button
          v-if="saved"
          size="small"
          variant="smooth"
          icon="add"
          :is-loading="busy === 'add'"
          :is-disabled="!canAdd || Boolean(busy)"
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
      class="flex flex-wrap items-center gap-2 pt-2 border-t shrink-0 border-slate-100 dark:border-slate-700"
    >
      <woot-button
        size="small"
        variant="clear"
        icon="wand"
        :is-loading="busy === 'suggest'"
        :is-disabled="!draft.trim() || Boolean(busy)"
        :title="t('SUGGEST_HINT')"
        @click="suggest"
      >
        {{ t('SUGGEST') }}
      </woot-button>
      <template v-if="saved">
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
        <woot-button
          size="small"
          variant="clear"
          color-scheme="secondary"
          icon="arrow-swap"
          :is-loading="compareRunning || busy === 'versions'"
          :is-disabled="!cases.length || compareRunning || Boolean(busy)"
          :title="t('COMPARE_VERSION_HINT')"
          @click="loadVersions"
        >
          {{ t('COMPARE_VERSION') }}
        </woot-button>
      </template>
    </div>

    <div
      v-if="versions"
      class="flex flex-wrap items-center gap-2 text-xs shrink-0"
    >
      <span v-if="!versions.length" class="text-slate-500">
        {{ t('NO_VERSIONS') }}
      </span>
      <template v-else>
        <select v-model="versionId" class="!mb-0 !w-auto text-xs">
          <option v-for="v in versions" :key="v.id" :value="v.id">
            {{ t('VERSION_OPTION', { number: v.version, note: v.note || '' }) }}
          </option>
        </select>
        <woot-button
          size="tiny"
          :is-disabled="Boolean(busy)"
          @click="runCompare"
        >
          {{ t('COMPARE_RUN') }}
        </woot-button>
      </template>
      <woot-button
        size="tiny"
        variant="clear"
        color-scheme="secondary"
        icon="dismiss"
        @click="versions = null"
      />
    </div>
    <p
      v-if="compareRunning || compareDone"
      class="m-0 text-xs shrink-0"
      :class="compareClass"
    >
      {{ compareLine }}
    </p>

    <div
      v-if="suggestions"
      class="flex flex-col gap-1 p-2 rounded-lg shrink-0 bg-slate-50 dark:bg-slate-900 max-h-48 overflow-y-auto"
    >
      <div class="flex items-center justify-between">
        <span class="text-xs font-medium text-slate-700 dark:text-slate-200">
          {{ t('SUGGESTIONS', { count: suggestions.length }) }}
        </span>
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          icon="dismiss"
          @click="suggestions = null"
        />
      </div>
      <div
        v-for="(sugerida, i) in suggestions"
        :key="`sug-${i}`"
        class="flex items-center gap-2 text-xs"
      >
        <span class="shrink-0">{{ suggestionMark(sugerida) }}</span>
        <span
          class="flex-1 min-w-0 truncate text-slate-800 dark:text-slate-100"
        >
          {{ sugerida.message }}
        </span>
        <span class="shrink-0 text-slate-500 dark:text-slate-400">
          {{ sugerida.chosen || '—' }}
        </span>
        <woot-button
          size="tiny"
          variant="smooth"
          :is-disabled="Boolean(busy)"
          @click="addSuggestion(sugerida)"
        >
          {{ t('ADD_SHORT') }}
        </woot-button>
      </div>
    </div>

    <div
      v-if="comparison.compared || (canSendToChat && failingRows.length)"
      class="flex flex-col gap-1 text-xs shrink-0"
    >
      <span
        v-if="comparison.compared"
        class="text-slate-600 dark:text-slate-300"
      >
        {{
          t('COMPARE', {
            before: comparison.before,
            after: comparison.after,
            total: comparison.compared,
          })
        }}
      </span>
      <span
        v-for="roto in comparison.broken"
        :key="`roto-${roto.id}`"
        class="text-amber-700 dark:text-amber-400"
      >
        {{ t('COMPARE_BROKEN', { message: roto.message }) }}
      </span>
      <woot-button
        v-if="canSendToChat && failingRows.length"
        size="tiny"
        variant="smooth"
        color-scheme="secondary"
        icon="chat"
        class="self-start"
        @click="sendEvidence(failingRows)"
      >
        {{ t('SEND_FAILING', { count: failingRows.length }) }}
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
              v-if="fila.turns && fila.turns.length > 1"
              class="shrink-0 text-[10px] text-slate-500 dark:text-slate-400"
              :title="fila.turns.join(' / ')"
            >
              {{ t('DIALOG_BADGE', { count: fila.turns.length }) }}
            </span>
            <span
              v-if="fila.changed"
              class="shrink-0 px-1 rounded text-[10px] bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-200"
            >
              {{ t('CHANGED') }}
            </span>
            <span
              v-if="fila.id && compareDiffers.includes(String(fila.id))"
              class="shrink-0 px-1 rounded text-[10px] bg-slate-200 text-slate-700 dark:bg-slate-600 dark:text-slate-100"
            >
              {{ t('DIFFERS_IN', { version: compare.version }) }}
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
            icon="star-emphasis"
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
        <template v-if="selected.live.dialog && selected.live.dialog.length">
          <p
            v-for="(turno, i) in selected.live.dialog"
            :key="`turno-${i}`"
            class="m-0 whitespace-pre-line text-slate-800 dark:text-slate-100"
          >
            <strong>{{ t('CUSTOMER') }}</strong> {{ turno.customer }}
            <br />
            <strong>{{ t('AGENT') }}</strong>
            {{ turno.reply || t('NO_REPLY') }}
          </p>
        </template>
        <p
          v-else
          class="m-0 whitespace-pre-line text-slate-800 dark:text-slate-100"
        >
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
      <div
        v-if="history"
        class="flex flex-col gap-0.5 p-2 rounded-md bg-slate-50 dark:bg-slate-900"
      >
        <span class="text-slate-500 dark:text-slate-400">
          {{ t('BEFORE') }} {{ history.beforeMark }} {{ history.before }}
        </span>
        <span class="text-slate-800 dark:text-slate-100">
          {{ t('NOW') }} {{ history.nowMark }} {{ history.now }}
        </span>
      </div>
      <div class="flex flex-wrap items-center gap-2 pt-1">
        <woot-button
          v-if="canSendToChat && (selected.live || selected.dry)"
          size="tiny"
          variant="smooth"
          icon="chat"
          @click="sendEvidence([selected])"
        >
          {{ t('SEND_TO_CHAT') }}
        </woot-button>
        <woot-button
          v-if="history"
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          @click="viewBefore"
        >
          {{ t('VIEW_BEFORE') }}
        </woot-button>
        <woot-button
          v-if="selectedCompare && !selectedCompare.same"
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          @click="viewCompared"
        >
          {{ viewComparedLabel }}
        </woot-button>
      </div>
    </div>
  </div>
</template>
