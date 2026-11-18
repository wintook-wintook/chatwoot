<script>
// proyecto@auditoria_predefinidas — LA PESTAÑA «AUDITORÍA»
// ============================================================================
//   Última auditoría: 17/11/2026 20:10 · 60 revisadas · 30 pares     [Auditar ahora]
//   [Exceden 11] [Duplicadas 0] [Contradicciones 1] [Se solapan 1] [Redacción 5]
//   Pendientes | Descartados (2)
//   ── Exceden el tope: nombre · 2,107 / 2,000 · bloques con su tamaño · [Editar]
//   ── Hallazgos: las dos respuestas lado a lado con las frases marcadas
//      [Editar] [Conservar esta] [Descartar]
//
// El tamaño se calcula en vivo; lo demás lo encuentra la auditoría con IA
// (CannedResponses::Audit::Runner): toda la cuenta con «Auditar ahora», y cada
// respuesta sola al guardarla. Editar una respuesta quita sus hallazgos y la vuelve a
// revisar en cuanto tiene su vector, por eso al cerrar el editor se recarga dos veces.
// ============================================================================
import CannedResponseAuditAPI from 'dashboard/api/cannedResponseAudit';
// proyecto@arreglar_predefinidas F2: historial y «Deshacer».
import CannedResponseFixAPI from 'dashboard/api/cannedResponseFix';
import { useAlert } from 'dashboard/composables';
import { messageStamp } from 'shared/helpers/timeHelper';
import { MAX_CHARS, sizeLevel, LEVEL_TEXT, LEVEL_BAR } from './cannedSize';

const POLL_MS = 4000;
const RECHECK_MS = 10000;
const KINDS = ['duplicate', 'contradiction', 'overlap', 'writing'];
// proyecto@arreglar_predefinidas F2: el arreglo con IA de cada sección.
const FINDING_ACTIONS = {
  duplicate: ['merge'],
  overlap: ['merge', 'separate'],
  contradiction: ['resolve'],
  writing: ['writing'],
};
const BULK_TYPES = ['ortografia', 'numeracion'];
const SEVERITY_CLASS = {
  high: 'bg-red-50 text-red-700 dark:bg-red-900/40 dark:text-red-300',
  medium: 'bg-amber-50 text-amber-800 dark:bg-amber-900/40 dark:text-amber-200',
  low: 'bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-200',
};

const escapeHtml = text =>
  (text || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');

const escapeRegExp = text => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

export default {
  // fix: { kind, response } (pasa del tope) o { kind, finding } (los demás);
  // bulk: «Corregir todas» de redacción.
  emits: ['edit', 'show-table', 'fix', 'bulk', 'applied'],
  data() {
    return {
      report: null,
      status: 'open',
      filter: '',
      isLoading: false,
      isStarting: false,
      busy: {},
      confirmKeep: null,
      confirmUndo: null,
      history: [],
      kinds: KINDS,
      max: MAX_CHARS,
    };
  },
  computed: {
    summary() {
      return (this.report && this.report.summary) || {};
    },
    audit() {
      return this.report && this.report.audit;
    },
    isRunning() {
      return Boolean(this.audit && this.audit.status === 'running');
    },
    auditError() {
      if (!this.audit) return '';
      const codigo =
        this.audit.error || (this.audit.stats && this.audit.stats.error);
      return codigo || '';
    },
    failedCalls() {
      return (
        (this.audit && this.audit.stats && this.audit.stats.failed_calls) || 0
      );
    },
    oversize() {
      if (this.status !== 'open') return [];
      if (this.filter && this.filter !== 'oversize') return [];
      return (this.report && this.report.oversize) || [];
    },
    findings() {
      if (this.filter === 'oversize' || this.status === 'history') return [];
      const todos = (this.report && this.report.findings) || [];
      return this.filter ? todos.filter(f => f.kind === this.filter) : todos;
    },
    cards() {
      return [
        { key: 'oversize', count: this.summary.oversize || 0 },
        ...KINDS.map(k => ({ key: k, count: this.summary[k] || 0 })),
      ];
    },
    isEmpty() {
      if (this.status === 'history') return !this.history.length;
      return !this.oversize.length && !this.findings.length;
    },
    tabIndex() {
      return ['open', 'dismissed', 'history'].indexOf(this.status);
    },
    // «Corregir todas»: redacción solo de ortografía o numeración.
    bulkCount() {
      return ((this.report && this.report.findings) || []).filter(
        f =>
          f.kind === 'writing' &&
          f.status === 'open' &&
          (f.details.issues || []).every(i => BULK_TYPES.includes(i.type))
      ).length;
    },
  },
  watch: {
    status() {
      this.load();
    },
  },
  mounted() {
    this.load();
  },
  beforeDestroy() {
    clearTimeout(this.pollTimer);
    clearTimeout(this.recheckTimer);
  },
  methods: {
    async load({ silent = false } = {}) {
      if (!silent) this.isLoading = true;
      try {
        const pedido = this.status === 'history' ? 'open' : this.status;
        const { data } = await CannedResponseAuditAPI.show(pedido);
        this.report = data;
        if (this.status === 'history') {
          this.history = (await CannedResponseFixAPI.history()).data || [];
        }
        if (this.isRunning) this.poll();
      } catch (error) {
        if (!silent) useAlert(this.$t('CANNED_MGMT.AUDIT.LOAD_ERROR'));
      } finally {
        this.isLoading = false;
      }
    },
    poll() {
      clearTimeout(this.pollTimer);
      this.pollTimer = setTimeout(() => this.load({ silent: true }), POLL_MS);
    },
    // Público: Index.vue lo llama al cerrar el editor. La respuesta editada se vuelve a
    // revisar sola cuando tiene su vector: una recarga ahora y otra en unos segundos.
    refreshAfterEdit() {
      this.load({ silent: true });
      clearTimeout(this.recheckTimer);
      this.recheckTimer = setTimeout(
        () => this.load({ silent: true }),
        RECHECK_MS
      );
    },
    async run() {
      this.isStarting = true;
      try {
        await CannedResponseAuditAPI.run();
        await this.load({ silent: true });
      } catch (error) {
        const codigo = error?.response?.data?.error;
        useAlert(
          codigo === 'no_key'
            ? this.$t('CANNED_MGMT.AUDIT.ERRORS.no_key')
            : this.$t('CANNED_MGMT.AUDIT.RUN_ERROR')
        );
      } finally {
        this.isStarting = false;
      }
    },
    async setStatus(finding, status) {
      this.busy = { ...this.busy, [finding.id]: true };
      try {
        await CannedResponseAuditAPI.setStatus(finding.id, status);
        await this.load({ silent: true });
      } catch (error) {
        useAlert(this.$t('CANNED_MGMT.AUDIT.SAVE_ERROR'));
      } finally {
        this.busy = { ...this.busy, [finding.id]: false };
      }
    },
    askKeep(finding, response) {
      const otra = finding.responses.find(r => r.id !== response.id);
      this.confirmKeep = { finding, keep: response, drop: otra };
    },
    async keep() {
      const { finding, keep } = this.confirmKeep;
      this.confirmKeep = null;
      this.busy = { ...this.busy, [finding.id]: true };
      try {
        await CannedResponseAuditAPI.keep(finding.id, keep.id);
        useAlert(this.$t('CANNED_MGMT.AUDIT.KEEP_DONE'));
        await this.load({ silent: true });
      } catch (error) {
        useAlert(this.$t('CANNED_MGMT.AUDIT.SAVE_ERROR'));
      } finally {
        this.busy = { ...this.busy, [finding.id]: false };
      }
    },
    closeKeep() {
      this.confirmKeep = null;
    },
    setTab(index) {
      this.status = ['open', 'dismissed', 'history'][index];
    },
    // Los arreglos con IA que tiene cada tipo de hallazgo.
    actionsFor(finding) {
      return FINDING_ACTIONS[finding.kind] || [];
    },
    openFix(kind, finding) {
      this.$emit('fix', { kind, finding });
    },
    askUndo(fix) {
      this.confirmUndo = { fix, force: false, names: [] };
    },
    closeUndo() {
      this.confirmUndo = null;
    },
    async undo() {
      const { fix, force } = this.confirmUndo;
      try {
        await CannedResponseFixAPI.undo(fix.id, force);
        this.confirmUndo = null;
        useAlert(this.$t('CANNED_MGMT.AUDIT.HISTORY.UNDONE'));
        this.$emit('applied');
        await this.load({ silent: true });
      } catch (error) {
        const data = error?.response?.data || {};
        if (data.error === 'edited_since') {
          this.confirmUndo = { fix, force: true, names: data.names || [] };
          return;
        }
        this.confirmUndo = null;
        useAlert(
          data.message || this.$t('CANNED_MGMT.AUDIT.HISTORY.UNDO_ERROR')
        );
      }
    },
    historyNames(fix) {
      return (fix.snapshot_names || []).join(' + ');
    },
    historyResult(fix) {
      const r = fix.result || {};
      return this.$t('CANNED_MGMT.AUDIT.HISTORY.RESULT', {
        created: (r.created_ids || []).length,
        updated: (r.updated_ids || []).length,
        deleted: (r.deleted_ids || []).length,
      });
    },
    toggleFilter(key) {
      this.filter = this.filter === key ? '' : key;
    },
    number(n) {
      return (n || 0).toLocaleString();
    },
    stamp(fecha) {
      return fecha
        ? messageStamp(new Date(fecha).getTime() / 1000, 'dd/MM/yyyy HH:mm')
        : '';
    },
    sizeText(chars) {
      return LEVEL_TEXT[sizeLevel(chars)];
    },
    sizeBar(chars) {
      return LEVEL_BAR[sizeLevel(chars)];
    },
    percent(chars) {
      return Math.min(100, Math.round((chars / MAX_CHARS) * 100));
    },
    severityClass(severity) {
      return SEVERITY_CLASS[severity] || SEVERITY_CLASS.low;
    },
    // Las frases que señaló la auditoría en ESTA respuesta (índice 0 = A, 1 = B).
    quotesFor(finding, index) {
      const d = finding.details || {};
      if (finding.kind === 'contradiction') {
        return (d.contradictions || []).map(c =>
          index === 0 ? c.quote_a : c.quote_b
        );
      }
      if (finding.kind === 'writing') return (d.issues || []).map(i => i.quote);
      return [];
    },
    // El contenido con las frases marcadas. Se escapa antes: v-html solo pone <mark>.
    highlighted(text, quotes) {
      let html = escapeHtml(text);
      quotes
        .filter(q => q && q.trim().length >= 3)
        .forEach(q => {
          const patron = escapeRegExp(escapeHtml(q.trim())).replace(
            /\s+/g,
            '\\s+'
          );
          html = html.replace(
            new RegExp(patron, 'i'),
            m =>
              `<mark class="px-0.5 rounded bg-amber-200 dark:bg-amber-700 text-inherit">${m}</mark>`
          );
        });
      return html;
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-4 pb-8">
    <!-- La corrida -->
    <div
      class="flex flex-wrap items-center gap-3 p-3 border border-solid rounded-lg bg-white dark:bg-slate-800 border-slate-100 dark:border-slate-700"
    >
      <div class="flex flex-col flex-1 min-w-[16rem] gap-0.5 text-sm">
        <span class="text-slate-800 dark:text-slate-100">
          <template v-if="isRunning">
            {{ $t('CANNED_MGMT.AUDIT.RUNNING') }}
          </template>
          <template v-else-if="audit">
            {{
              $t('CANNED_MGMT.AUDIT.LAST_RUN', {
                date: stamp(audit.finished_at || audit.started_at),
                responses: number(audit.stats && audit.stats.responses),
                pairs: number(audit.stats && audit.stats.pairs),
              })
            }}
          </template>
          <template v-else>{{ $t('CANNED_MGMT.AUDIT.NEVER_RUN') }}</template>
        </span>
        <span class="text-xs text-slate-500 dark:text-slate-400">
          {{ $t('CANNED_MGMT.AUDIT.HOW_IT_WORKS', { max: number(max) }) }}
        </span>
      </div>
      <woot-button
        icon="arrow-clockwise"
        :is-loading="isStarting || isRunning"
        :is-disabled="isRunning"
        @click="run"
      >
        {{ $t('CANNED_MGMT.AUDIT.RUN') }}
      </woot-button>
    </div>

    <div
      v-if="!isRunning && (auditError || failedCalls)"
      class="px-4 py-3 text-sm border rounded-md border-amber-200 bg-amber-50 dark:border-amber-700 dark:bg-amber-900/30 text-amber-800 dark:text-amber-200"
    >
      <span v-if="auditError">
        {{
          $te(`CANNED_MGMT.AUDIT.ERRORS.${auditError}`)
            ? $t(`CANNED_MGMT.AUDIT.ERRORS.${auditError}`)
            : $t('CANNED_MGMT.AUDIT.ERRORS.other', { error: auditError })
        }}
      </span>
      <span v-if="failedCalls">
        {{ $t('CANNED_MGMT.AUDIT.FAILED_CALLS', { count: failedCalls }) }}
      </span>
    </div>

    <!-- Resumen: cada tarjeta filtra -->
    <div class="grid grid-cols-2 gap-2 sm:grid-cols-3 lg:grid-cols-5">
      <button
        v-for="card in cards"
        :key="card.key"
        type="button"
        class="flex flex-col items-start gap-0.5 p-3 text-left border border-solid rounded-lg bg-white dark:bg-slate-800"
        :class="
          filter === card.key
            ? 'border-woot-500 dark:border-woot-400'
            : 'border-slate-100 dark:border-slate-700'
        "
        :aria-pressed="filter === card.key"
        @click="toggleFilter(card.key)"
      >
        <span
          class="text-2xl font-semibold tabular-nums"
          :class="
            card.count
              ? 'text-slate-900 dark:text-slate-50'
              : 'text-slate-400 dark:text-slate-500'
          "
        >
          {{ number(card.count) }}
        </span>
        <span class="text-xs text-slate-600 dark:text-slate-300">
          {{ $t(`CANNED_MGMT.AUDIT.CARDS.${card.key}`) }}
        </span>
      </button>
    </div>

    <div class="flex items-center gap-2">
      <woot-tabs :index="tabIndex" @change="setTab">
        <woot-tabs-item
          :index="0"
          :name="$t('CANNED_MGMT.AUDIT.PENDING')"
          :show-badge="false"
        />
        <woot-tabs-item
          :index="1"
          :name="
            $t('CANNED_MGMT.AUDIT.DISMISSED', {
              count: summary.dismissed || 0,
            })
          "
          :show-badge="false"
        />
        <woot-tabs-item
          :index="2"
          :name="$t('CANNED_MGMT.AUDIT.HISTORY.TAB')"
          :show-badge="false"
        />
      </woot-tabs>
      <span class="flex-1" />
      <woot-button
        v-if="status === 'open' && bulkCount"
        size="small"
        variant="smooth"
        icon="wand"
        @click="$emit('bulk')"
      >
        {{ $t('CANNED_MGMT.AUDIT.BULK_WRITING', { count: bulkCount }) }}
      </woot-button>
    </div>

    <woot-loading-state
      v-if="isLoading && !report"
      :message="$t('CANNED_MGMT.AUDIT.LOADING')"
    />
    <p
      v-else-if="isEmpty"
      class="py-8 text-base text-center text-slate-600 dark:text-slate-300"
    >
      {{ $t(`CANNED_MGMT.AUDIT.EMPTY_BY_TAB.${status}`) }}
    </p>

    <!-- Historial: lo aplicado en los últimos 30 días, con «Deshacer» -->
    <section
      v-if="status === 'history' && history.length"
      class="flex flex-col gap-2"
    >
      <article
        v-for="fix in history"
        :key="`h-${fix.id}`"
        class="flex flex-wrap items-center gap-3 p-3 text-sm border border-solid rounded-lg bg-white dark:bg-slate-800 border-slate-100 dark:border-slate-700"
      >
        <span
          class="px-2 py-0.5 text-xs font-medium rounded bg-slate-100 dark:bg-slate-700"
        >
          {{ $t(`CANNED_MGMT.FIX.TITLES.${fix.kind}`) }}
        </span>
        <span class="flex-1 min-w-0 truncate" :title="historyNames(fix)">
          {{ historyNames(fix) }}
        </span>
        <span class="text-xs text-slate-500">{{ historyResult(fix) }}</span>
        <span class="text-xs tabular-nums text-slate-500">
          {{ stamp(fix.updated_at) }}
        </span>
        <span v-if="fix.status === 'undone'" class="text-xs text-slate-500">
          {{ $t('CANNED_MGMT.AUDIT.HISTORY.WAS_UNDONE') }}
        </span>
        <woot-button
          v-else-if="fix.undoable"
          size="tiny"
          variant="smooth"
          color-scheme="secondary"
          icon="arrow-rotate-counter-clockwise"
          @click="askUndo(fix)"
        >
          {{ $t('CANNED_MGMT.AUDIT.HISTORY.UNDO') }}
        </woot-button>
      </article>
    </section>

    <!-- Exceden el tope de caracteres -->
    <section v-if="oversize.length" class="flex flex-col gap-2">
      <div class="flex items-center gap-2">
        <h3
          class="!m-0 text-base font-medium text-slate-800 dark:text-slate-100"
        >
          {{ $t('CANNED_MGMT.AUDIT.OVERSIZE_TITLE', { max: number(max) }) }}
        </h3>
        <woot-button
          size="tiny"
          variant="link"
          @click="$emit('show-table', 'over')"
        >
          {{ $t('CANNED_MGMT.AUDIT.SEE_IN_TABLE') }}
        </woot-button>
      </div>
      <p class="!m-0 text-xs text-slate-500 dark:text-slate-400">
        {{ $t('CANNED_MGMT.AUDIT.OVERSIZE_HELP') }}
      </p>
      <article
        v-for="item in oversize"
        :key="`size-${item.id}`"
        class="flex flex-col gap-2 p-3 border border-solid rounded-lg bg-white dark:bg-slate-800 border-slate-100 dark:border-slate-700"
      >
        <div class="flex flex-wrap items-center gap-3">
          <span
            class="flex-1 min-w-0 font-medium truncate text-slate-800 dark:text-slate-100"
          >
            {{ item.short_code }}
          </span>
          <span
            class="text-sm font-medium tabular-nums"
            :class="sizeText(item.agent_chars)"
          >
            {{ number(item.agent_chars) }} / {{ number(max) }}
          </span>
          <woot-button
            size="tiny"
            variant="smooth"
            icon="wand"
            @click="$emit('fix', { kind: 'oversize', response: item })"
          >
            {{ $t('CANNED_MGMT.FIX.OPEN') }}
          </woot-button>
          <woot-button
            size="tiny"
            variant="smooth"
            color-scheme="secondary"
            icon="edit"
            @click="$emit('edit', item)"
          >
            {{ $t('CANNED_MGMT.EDIT.BUTTON_TEXT') }}
          </woot-button>
        </div>
        <div
          class="h-1.5 overflow-hidden rounded-full bg-slate-100 dark:bg-slate-700"
        >
          <div
            class="h-full"
            :class="sizeBar(item.agent_chars)"
            :style="{ width: `${percent(item.agent_chars)}%` }"
          />
        </div>
        <ol class="!m-0 !pl-0 list-none flex flex-col gap-0.5 text-xs">
          <li
            v-for="(block, i) in item.blocks"
            :key="i"
            class="flex gap-2 text-slate-600 dark:text-slate-300"
          >
            <span class="w-12 text-right tabular-nums shrink-0">
              {{ number(block.chars) }}
            </span>
            <span class="truncate">{{ block.preview }}</span>
          </li>
        </ol>
      </article>
    </section>

    <!-- Hallazgos -->
    <section v-if="findings.length" class="flex flex-col gap-3">
      <article
        v-for="finding in findings"
        :key="finding.id"
        class="flex flex-col gap-3 p-3 border border-solid rounded-lg bg-white dark:bg-slate-800 border-slate-100 dark:border-slate-700"
      >
        <header class="flex flex-wrap items-center gap-2">
          <span
            class="px-2 py-0.5 text-xs font-medium rounded"
            :class="severityClass(finding.severity)"
          >
            {{ $t(`CANNED_MGMT.AUDIT.KINDS.${finding.kind}`) }}
          </span>
          <span
            v-if="finding.similarity"
            class="text-xs tabular-nums text-slate-500 dark:text-slate-400"
          >
            {{
              $t('CANNED_MGMT.AUDIT.SIMILARITY', {
                value: finding.similarity.toFixed(2),
              })
            }}
          </span>
          <span class="flex-1" />
          <template v-if="finding.status === 'open'">
            <woot-button
              v-for="accion in actionsFor(finding)"
              :key="accion"
              size="tiny"
              variant="smooth"
              icon="wand"
              @click="openFix(accion, finding)"
            >
              {{ $t(`CANNED_MGMT.AUDIT.ACTIONS.${accion}`) }}
            </woot-button>
          </template>
          <woot-button
            v-if="finding.status === 'open'"
            size="tiny"
            variant="smooth"
            color-scheme="secondary"
            icon="dismiss"
            :is-loading="!!busy[finding.id]"
            @click="setStatus(finding, 'dismissed')"
          >
            {{
              finding.kind === 'contradiction'
                ? $t('CANNED_MGMT.AUDIT.NOT_CONTRADICTION')
                : $t('CANNED_MGMT.AUDIT.DISMISS')
            }}
          </woot-button>
          <woot-button
            v-else
            size="tiny"
            variant="smooth"
            color-scheme="secondary"
            icon="arrow-rotate-counter-clockwise"
            :is-loading="!!busy[finding.id]"
            @click="setStatus(finding, 'open')"
          >
            {{ $t('CANNED_MGMT.AUDIT.REOPEN') }}
          </woot-button>
        </header>

        <!-- Qué encontró -->
        <div
          v-if="finding.details.reason || finding.details.suggestion"
          class="flex flex-col gap-0.5 text-sm text-slate-700 dark:text-slate-200"
        >
          <span v-if="finding.details.reason">
            {{ finding.details.reason }}
          </span>
          <span
            v-if="finding.details.suggestion"
            class="text-slate-500 dark:text-slate-400"
          >
            {{
              $t('CANNED_MGMT.AUDIT.SUGGESTION', {
                text: finding.details.suggestion,
              })
            }}
          </span>
        </div>
        <ul
          v-if="finding.kind === 'contradiction'"
          class="!m-0 !pl-4 flex flex-col gap-1 text-sm text-slate-700 dark:text-slate-200"
        >
          <li v-for="(c, i) in finding.details.contradictions" :key="i">
            <strong>{{ c.topic }}:</strong>
            A «{{ c.quote_a }}» · B «{{ c.quote_b }}»
            <span v-if="c.why" class="text-slate-500 dark:text-slate-400">
              — {{ c.why }}
            </span>
          </li>
        </ul>
        <ul
          v-if="finding.kind === 'writing'"
          class="!m-0 !pl-4 flex flex-col gap-1 text-sm text-slate-700 dark:text-slate-200"
        >
          <li v-for="(issue, i) in finding.details.issues" :key="i">
            <strong>
              {{ $t(`CANNED_MGMT.AUDIT.ISSUES.${issue.type}`) }}:
            </strong>
            «{{ issue.quote }}»
            <span
              v-if="issue.suggestion"
              class="text-slate-500 dark:text-slate-400"
            >
              → {{ issue.suggestion }}
            </span>
          </li>
        </ul>

        <!-- Las respuestas, lado a lado -->
        <div
          class="grid gap-3"
          :class="finding.responses.length > 1 ? 'md:grid-cols-2' : ''"
        >
          <div
            v-for="(response, index) in finding.responses"
            :key="response.id"
            class="flex flex-col min-w-0 gap-2 p-2 rounded-md bg-slate-25 dark:bg-slate-900"
          >
            <div class="flex items-center gap-2">
              <span
                v-if="finding.responses.length > 1"
                class="text-xs font-semibold text-slate-500"
              >
                {{ index === 0 ? 'A' : 'B' }}
              </span>
              <span
                class="flex-1 min-w-0 text-sm font-medium truncate text-slate-800 dark:text-slate-100"
                :title="response.short_code"
              >
                {{ response.short_code }}
              </span>
              <span
                class="text-xs tabular-nums"
                :class="sizeText(response.agent_chars)"
              >
                {{ number(response.agent_chars) }}
              </span>
            </div>
            <!-- eslint-disable vue/no-v-html -->
            <div
              class="overflow-y-auto text-xs whitespace-pre-wrap break-words max-h-48 text-slate-700 dark:text-slate-300"
              v-html="highlighted(response.content, quotesFor(finding, index))"
            />
            <!-- eslint-enable vue/no-v-html -->
            <div class="flex flex-wrap gap-1">
              <woot-button
                size="tiny"
                variant="smooth"
                color-scheme="secondary"
                icon="edit"
                @click="$emit('edit', response)"
              >
                {{ $t('CANNED_MGMT.EDIT.BUTTON_TEXT') }}
              </woot-button>
              <woot-button
                v-if="finding.kind === 'duplicate' && finding.status === 'open'"
                size="tiny"
                variant="smooth"
                icon="checkmark"
                :is-disabled="!!busy[finding.id]"
                @click="askKeep(finding, response)"
              >
                {{ $t('CANNED_MGMT.AUDIT.KEEP_THIS') }}
              </woot-button>
            </div>
          </div>
        </div>
      </article>
    </section>

    <woot-delete-modal
      v-if="confirmUndo"
      :show="!!confirmUndo"
      :on-close="closeUndo"
      :on-confirm="undo"
      :title="$t('CANNED_MGMT.AUDIT.HISTORY.CONFIRM_TITLE')"
      :message="
        confirmUndo.force
          ? $t('CANNED_MGMT.AUDIT.HISTORY.CONFIRM_EDITED', {
              names: confirmUndo.names.join(', '),
            })
          : $t('CANNED_MGMT.AUDIT.HISTORY.CONFIRM_MESSAGE', {
              names: historyNames(confirmUndo.fix),
            })
      "
      :confirm-text="$t('CANNED_MGMT.AUDIT.HISTORY.UNDO')"
      :reject-text="$t('CANNED_MGMT.DELETE.CONFIRM.NO')"
    />

    <woot-delete-modal
      v-if="confirmKeep"
      :show="!!confirmKeep"
      :on-close="closeKeep"
      :on-confirm="keep"
      :title="$t('CANNED_MGMT.AUDIT.KEEP_CONFIRM_TITLE')"
      :message="
        $t('CANNED_MGMT.AUDIT.KEEP_CONFIRM_MESSAGE', {
          keep: confirmKeep.keep.short_code,
          drop: confirmKeep.drop.short_code,
        })
      "
      :confirm-text="$t('CANNED_MGMT.AUDIT.KEEP_CONFIRM_YES')"
      :reject-text="$t('CANNED_MGMT.DELETE.CONFIRM.NO')"
    />
  </div>
</template>
