<script>
// proyecto@arreglar_predefinidas — «ARREGLAR CON IA», PARA CADA SECCIÓN DE LA AUDITORÍA
// ============================================================================
//   Original(es)                 │  Propuesta
//   ………                          │  ┌ Nombre [……………]  ▓▓▓▓░ 1,696 / 2,000
//                                │  │ [Cambios | Editar]
//   Comprobaciones: ✓ tamaño ✓ datos ✓ … · cobertura · búsqueda
//   [Proponer de nuevo] [Descartar]          [Volver a comprobar] [Aceptar y aplicar]
//
// kind (target.kind):
//   oversize  pasa del tope (target.response)
//   writing   mejorar redacción (target.finding)
//   merge     unir duplicadas / que se solapan en una
//   separate  separar temas de dos que se solapan
//   resolve   contradicción: primero se elige el dato correcto (y, si se quiere, otras
//             respuestas que también tienen el equivocado); luego la IA corrige.
//
// La propuesta la arma el servidor en segundo plano (CannedResponseFix). Nada se guarda
// hasta «Aceptar»; lo aplicado se puede deshacer en Auditoría → Historial.
// Bloquean: tamaño, nombres, grupos y —se pueden aceptar marcando que ya no aplican—
// datos, dato equivocado y (al separar) frases perdidas. Avisan: cambios de más,
// parecido entre las dos, duplicados y búsqueda.
// ============================================================================
import CannedResponseFixAPI from 'dashboard/api/cannedResponseFix';
import { useAlert } from 'dashboard/composables';
import CharMeter from './CharMeter.vue';
import { MAX_CHARS, sizeLevel, LEVEL_TEXT } from './cannedSize';
import { diffHtml } from './wordDiff';

const POLL_MS = 3000;
const FORCEABLE = ['data', 'resolved', 'coverage'];
const FIXED_NAMES = ['separate', 'resolve'];
const WITH_DIFF = ['writing', 'resolve', 'separate'];

export default {
  components: { CharMeter },
  props: {
    show: { type: Boolean, default: false },
    // { kind, response } para oversize; { kind, finding } para los demás.
    target: { type: Object, default: () => ({}) },
  },
  emits: ['close', 'applied'],
  data() {
    return {
      kind: this.target.kind || 'oversize',
      fix: null,
      parts: [],
      checks: {},
      dirty: false,
      force: false,
      isLoading: false,
      isChecking: false,
      isApplying: false,
      view: 'diff',
      choices: [],
      preview: null,
      extraIds: [],
      max: MAX_CHARS,
    };
  },
  computed: {
    finding() {
      return this.target.finding || null;
    },
    proposal() {
      return (this.fix && this.fix.proposal) || {};
    },
    isRunning() {
      return Boolean(this.fix && this.fix.status === 'running');
    },
    isProposed() {
      return Boolean(this.fix && this.fix.status === 'proposed');
    },
    failed() {
      return this.fix && this.fix.status === 'failed' ? this.fix.error : '';
    },
    blocking() {
      return this.checks.blocking || [];
    },
    forceable() {
      return (
        this.blocking.length > 0 &&
        this.blocking.every(k => FORCEABLE.includes(k))
      );
    },
    notAdvised() {
      return Boolean(this.proposal.not_advised);
    },
    cannotApply() {
      if (!this.isProposed || this.fix.stale || !this.parts.length) return true;
      if (this.notAdvised) return true;
      return this.blocking.some(k => !(FORCEABLE.includes(k) && this.force));
    },
    originals() {
      if (this.fix && this.fix.originals && this.fix.originals.length) {
        return this.fix.originals;
      }
      if (this.target.response) return [this.target.response];
      return (this.finding && this.finding.responses) || [];
    },
    fixedNames() {
      return FIXED_NAMES.includes(this.kind);
    },
    withDiff() {
      return WITH_DIFF.includes(this.kind);
    },
    contradictions() {
      return (this.finding && this.finding.details.contradictions) || [];
    },
    choicesComplete() {
      return (
        this.choices.length === this.contradictions.length &&
        this.choices.every(
          c => c.choice && (c.choice !== 'custom' || (c.value || '').trim())
        )
      );
    },
    removedChars() {
      const cleanup = this.proposal.cleanup || {};
      return (cleanup.chars_before || 0) - (cleanup.chars_after || 0);
    },
    missingData() {
      return (this.checks.data && this.checks.data.missing) || [];
    },
    failedQuestions() {
      const search = this.checks.search || {};
      return (search.questions || []).filter(q => !q.found);
    },
    presentBlockingChecks() {
      return ['size', 'data', 'groups', 'names'].filter(k => this.checks[k]);
    },
    tooMuchChange() {
      const cambios = this.checks.changes;
      return Boolean(cambios && cambios.ok === false);
    },
    subtitle() {
      const nombres = this.originals.map(r => `«${r.short_code}»`).join(' + ');
      return this.$t(`CANNED_MGMT.FIX.SUBTITLES.${this.kind}`, {
        names: nombres,
        chars: this.number((this.originals[0] || {}).agent_chars),
        max: this.number(this.max),
      });
    },
  },
  watch: {
    show: {
      immediate: true,
      handler(visible) {
        if (visible) this.load();
        else this.stopPolling();
      },
    },
  },
  beforeDestroy() {
    this.stopPolling();
  },
  methods: {
    async load() {
      this.reset();
      this.isLoading = true;
      try {
        const { data } =
          this.kind === 'oversize'
            ? await CannedResponseFixAPI.latest(this.target.response.id)
            : await CannedResponseFixAPI.forFinding(this.finding.id, this.kind);
        if (data) this.setFix(data);
      } catch (error) {
        useAlert(this.$t('CANNED_MGMT.FIX.LOAD_ERROR'));
      } finally {
        this.isLoading = false;
      }
    },
    reset() {
      this.stopPolling();
      this.fix = null;
      this.parts = [];
      this.checks = {};
      this.dirty = false;
      this.force = false;
      this.view = 'diff';
      this.preview = null;
      this.extraIds = [];
      this.choices = this.contradictions.map(() => ({
        choice: '',
        value: '',
      }));
    },
    setFix(fix) {
      this.fix = fix;
      if (fix.status === 'proposed') {
        this.parts = (fix.proposal.parts || []).map(p => ({ ...p }));
        this.checks = fix.checks || {};
        this.dirty = false;
      }
      if (fix.status === 'running') this.poll();
    },
    // Unir en vez de separar (cuando la IA desaconseja separar).
    switchTo(kind) {
      this.kind = kind;
      this.load();
    },
    async propose() {
      const choices = this.choices;
      const extraIds = this.extraIds;
      this.reset();
      this.isLoading = true;
      try {
        const { data } =
          this.kind === 'oversize'
            ? await CannedResponseFixAPI.propose(this.target.response.id)
            : await CannedResponseFixAPI.create({
                kind: this.kind,
                findingId: this.finding.id,
                choices: this.kind === 'resolve' ? choices : undefined,
                extraIds: this.kind === 'resolve' ? extraIds : undefined,
              });
        this.setFix(data);
      } catch (error) {
        const codigo = error?.response?.data?.error;
        useAlert(this.errorText(codigo || 'ai_failed'));
        this.choices = choices;
      } finally {
        this.isLoading = false;
      }
    },
    async loadPreview() {
      try {
        const { data } = await CannedResponseFixAPI.resolvePreview(
          this.finding.id,
          this.choices
        );
        this.preview = data;
        this.extraIds = [];
      } catch (error) {
        useAlert(this.$t('CANNED_MGMT.FIX.LOAD_ERROR'));
      }
    },
    toggleExtra(id) {
      this.extraIds = this.extraIds.includes(id)
        ? this.extraIds.filter(x => x !== id)
        : [...this.extraIds, id];
    },
    poll() {
      this.stopPolling();
      this.pollTimer = setTimeout(async () => {
        try {
          const { data } = await CannedResponseFixAPI.status(this.fix.id);
          this.setFix(data);
        } catch (error) {
          this.poll();
        }
      }, POLL_MS);
    },
    stopPolling() {
      clearTimeout(this.pollTimer);
      this.pollTimer = null;
    },
    edited() {
      this.dirty = true;
    },
    removePart(index) {
      this.parts.splice(index, 1);
      this.dirty = true;
    },
    async recheck() {
      this.isChecking = true;
      try {
        const { data } = await CannedResponseFixAPI.check(
          this.fix.id,
          this.parts
        );
        this.checks = data;
        this.dirty = false;
      } catch (error) {
        useAlert(this.$t('CANNED_MGMT.FIX.CHECK_ERROR'));
      } finally {
        this.isChecking = false;
      }
    },
    async apply() {
      this.isApplying = true;
      try {
        await CannedResponseFixAPI.apply(this.fix.id, this.parts, this.force);
        useAlert(this.$t('CANNED_MGMT.FIX.APPLIED_UNDO'));
        this.$emit('applied');
        this.$emit('close');
      } catch (error) {
        const data = error?.response?.data || {};
        if (data.checks) {
          this.checks = data.checks;
          this.dirty = false;
        }
        useAlert(this.errorText(data.error || 'apply_failed', data.message));
      } finally {
        this.isApplying = false;
      }
    },
    async discard() {
      try {
        if (this.fix) await CannedResponseFixAPI.discard(this.fix.id);
      } finally {
        this.$emit('close');
      }
    },
    errorText(codigo, detalle) {
      const clave = `CANNED_MGMT.FIX.ERRORS.${codigo}`;
      return this.$te(clave)
        ? this.$t(clave, { detail: detalle || '' })
        : this.$t('CANNED_MGMT.FIX.ERRORS.other', { detail: codigo });
    },
    number(n) {
      return (n || 0).toLocaleString();
    },
    sizeText(chars) {
      return LEVEL_TEXT[sizeLevel(chars)];
    },
    // El texto de antes de una parte (redacción, separar, resolver).
    baseline(index) {
      const r = this.originals[index];
      return r ? r.content : '';
    },
    diff(index) {
      return diffHtml(this.baseline(index), this.parts[index].content);
    },
    changeOf(index) {
      const medida = ((this.checks.changes || {}).parts || [])[index];
      return medida ? Math.round(medida.ratio * 100) : null;
    },
    checkLabel(clave) {
      const c = this.checks[clave] || {};
      const args = {
        size: {},
        data: { found: c.total - (c.missing || []).length, total: c.total },
        groups: { prefixes: (c.prefixes || []).join(', ') || '—' },
        names: {},
      }[clave];
      const texto = this.$t(
        `CANNED_MGMT.FIX.CHECKS.${clave.toUpperCase()}`,
        args
      );
      if (clave === 'names' && (c.bad || []).length) {
        return `${texto} (${this.$t(
          'CANNED_MGMT.FIX.CHECKS.TAKEN'
        )}: ${c.bad.join(', ')})`;
      }
      return texto;
    },
    nameOf(id) {
      return (this.originals.find(r => r.id === id) || {}).short_code;
    },
    mark(ok) {
      return ok ? '✓' : '✗';
    },
    markClass(ok, blocks) {
      if (ok) return 'text-green-700 dark:text-green-400';
      return blocks
        ? 'text-red-700 dark:text-red-400'
        : 'text-amber-700 dark:text-amber-400';
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')" size="fix-wide">
    <div class="flex flex-col gap-4 p-6">
      <header class="flex flex-col gap-1 pr-8">
        <h2
          class="!m-0 text-lg font-semibold text-slate-900 dark:text-slate-50"
        >
          {{ $t(`CANNED_MGMT.FIX.TITLES.${kind}`) }}
        </h2>
        <p class="!m-0 text-sm text-slate-600 dark:text-slate-300">
          {{ subtitle }}
        </p>
      </header>

      <woot-loading-state
        v-if="isLoading"
        :message="$t('CANNED_MGMT.FIX.LOADING')"
      />

      <!-- Sin propuesta todavía -->
      <div
        v-else-if="!fix || failed"
        class="flex flex-col items-start gap-3 text-sm text-slate-700 dark:text-slate-200"
      >
        <p class="!m-0">{{ $t(`CANNED_MGMT.FIX.INTROS.${kind}`) }}</p>
        <p
          v-if="failed"
          class="!m-0 px-3 py-2 rounded-md bg-red-50 text-red-700 dark:bg-red-900/40 dark:text-red-300"
        >
          {{ errorText(failed) }}
        </p>

        <!-- Contradicción: primero, cuál es el dato correcto -->
        <div v-if="kind === 'resolve'" class="flex flex-col w-full gap-3">
          <fieldset
            v-for="(c, i) in contradictions"
            :key="i"
            class="flex flex-col gap-1 p-3 border border-solid rounded-md border-slate-100 dark:border-slate-700"
          >
            <legend class="px-1 text-sm font-medium">{{ c.topic }}</legend>
            <label class="flex items-start gap-2 !mb-0">
              <input
                v-model="choices[i].choice"
                type="radio"
                value="a"
                class="!mt-1"
              />
              <span>
                <strong>{{ $t('CANNED_MGMT.FIX.RESOLVE.A_RIGHT') }}</strong>
                «{{ c.quote_a }}»
              </span>
            </label>
            <label class="flex items-start gap-2 !mb-0">
              <input
                v-model="choices[i].choice"
                type="radio"
                value="b"
                class="!mt-1"
              />
              <span>
                <strong>{{ $t('CANNED_MGMT.FIX.RESOLVE.B_RIGHT') }}</strong>
                «{{ c.quote_b }}»
              </span>
            </label>
            <label class="flex items-center gap-2 !mb-0">
              <input v-model="choices[i].choice" type="radio" value="custom" />
              <span class="whitespace-nowrap">
                {{ $t('CANNED_MGMT.FIX.RESOLVE.CUSTOM') }}
              </span>
              <input
                v-model="choices[i].value"
                type="text"
                class="!mb-0 flex-1 text-sm"
                :disabled="choices[i].choice !== 'custom'"
                :aria-label="$t('CANNED_MGMT.FIX.RESOLVE.CUSTOM')"
              />
            </label>
          </fieldset>
          <div class="flex flex-wrap items-center gap-2">
            <woot-button
              variant="smooth"
              color-scheme="secondary"
              icon="search"
              :is-disabled="!choicesComplete"
              @click="loadPreview"
            >
              {{ $t('CANNED_MGMT.FIX.RESOLVE.FIND_ELSEWHERE') }}
            </woot-button>
            <span
              v-if="preview && !preview.also_in.length"
              class="text-xs text-slate-500"
            >
              {{ $t('CANNED_MGMT.FIX.RESOLVE.NOWHERE_ELSE') }}
            </span>
          </div>
          <div
            v-if="preview && preview.also_in.length"
            class="flex flex-col gap-1 p-3 rounded-md bg-amber-50 dark:bg-amber-900/30"
          >
            <span class="text-sm">
              {{ $t('CANNED_MGMT.FIX.RESOLVE.ALSO_IN') }}
            </span>
            <label
              v-for="otra in preview.also_in"
              :key="otra.id"
              class="flex items-center gap-2 !mb-0 text-sm"
            >
              <input
                type="checkbox"
                class="!m-0"
                :checked="extraIds.includes(otra.id)"
                @change="toggleExtra(otra.id)"
              />
              {{ otra.short_code }}
              <span class="text-xs text-slate-500">
                ({{ otra.matches.join(', ') }})
              </span>
            </label>
          </div>
        </div>

        <woot-button
          icon="wand"
          :is-disabled="kind === 'resolve' && !choicesComplete"
          @click="propose"
        >
          {{ $t('CANNED_MGMT.FIX.PROPOSE') }}
        </woot-button>
      </div>

      <div
        v-else-if="isRunning"
        class="flex items-center gap-3 py-6 text-sm text-slate-700 dark:text-slate-200"
      >
        <span class="spinner" />
        {{ $t('CANNED_MGMT.FIX.RUNNING') }}
      </div>

      <!-- La propuesta -->
      <template v-else-if="isProposed">
        <p
          v-if="fix.stale"
          class="!m-0 px-3 py-2 text-sm rounded-md bg-amber-50 text-amber-800 dark:bg-amber-900/40 dark:text-amber-200"
        >
          {{ $t('CANNED_MGMT.FIX.STALE') }}
        </p>

        <!-- La IA desaconseja separarlas -->
        <div
          v-if="notAdvised"
          class="flex flex-col items-start gap-2 p-3 text-sm rounded-md bg-amber-50 text-amber-800 dark:bg-amber-900/40 dark:text-amber-200"
        >
          <span>
            {{ $t('CANNED_MGMT.FIX.NOT_ADVISED', { reason: proposal.reason }) }}
          </span>
          <woot-button size="small" icon="wand" @click="switchTo('merge')">
            {{ $t('CANNED_MGMT.AUDIT.ACTIONS.merge') }}
          </woot-button>
        </div>

        <div
          v-else
          class="flex flex-col gap-1 p-3 text-sm rounded-md bg-slate-25 dark:bg-slate-900 text-slate-700 dark:text-slate-200"
        >
          <span>
            <strong>
              {{ $t(`CANNED_MGMT.FIX.ACTIONS.${proposal.action}`) }}
            </strong>
            <template v-if="proposal.shape">
              · {{ $t(`CANNED_MGMT.FIX.SHAPES.${proposal.shape}`) }}
            </template>
            <template v-if="proposal.subject">
              · {{ proposal.subject }}
            </template>
          </span>
          <span v-if="proposal.reason">{{ proposal.reason }}</span>
          <span v-if="removedChars > 0" class="text-xs text-slate-500">
            {{
              $t('CANNED_MGMT.FIX.CLEANUP', {
                chars: number(removedChars),
                kinds: (proposal.cleanup.removed || [])
                  .map(r => $t(`CANNED_MGMT.FIX.REMOVED.${r.kind}`))
                  .join(', '),
              })
            }}
          </span>
          <span v-if="proposal.fallback" class="text-xs text-slate-500">
            {{ $t(`CANNED_MGMT.FIX.FALLBACK.${proposal.fallback}`) }}
          </span>
          <span
            v-if="kind === 'merge' && proposal.removed_id"
            class="text-xs text-slate-500"
          >
            {{
              $t('CANNED_MGMT.FIX.MERGE_KEEPS', {
                keep: nameOf(proposal.target_id),
                drop: nameOf(proposal.removed_id),
              })
            }}
          </span>
          <span
            v-if="(proposal.lost_groups || []).length"
            class="text-xs text-amber-700 dark:text-amber-400"
          >
            {{
              $t('CANNED_MGMT.FIX.LOST_GROUPS', {
                groups: proposal.lost_groups.join(', '),
              })
            }}
          </span>
        </div>

        <div v-if="!notAdvised" class="grid gap-4 lg:grid-cols-2">
          <!-- Original(es) -->
          <section class="flex flex-col min-w-0 gap-2">
            <h3
              class="!m-0 text-sm font-medium text-slate-800 dark:text-slate-100"
            >
              {{ $t('CANNED_MGMT.FIX.ORIGINAL') }}
            </h3>
            <div
              v-for="original in originals"
              :key="original.id"
              class="flex flex-col gap-1"
            >
              <span class="text-xs font-medium">
                {{ original.short_code }}
                <span
                  class="ml-1 tabular-nums"
                  :class="sizeText(original.agent_chars)"
                >
                  {{ number(original.agent_chars) }}
                </span>
              </span>
              <div
                class="p-2 overflow-y-auto text-xs whitespace-pre-wrap break-words rounded-md max-h-[40vh] bg-slate-25 dark:bg-slate-900 text-slate-700 dark:text-slate-300"
              >
                {{ original.content }}
              </div>
            </div>
          </section>

          <!-- Propuesta -->
          <section class="flex flex-col min-w-0 gap-3">
            <div class="flex items-center gap-2">
              <h3
                class="!m-0 flex-1 text-sm font-medium text-slate-800 dark:text-slate-100"
              >
                {{ $t('CANNED_MGMT.FIX.PARTS', { count: parts.length }) }}
              </h3>
              <template v-if="withDiff">
                <woot-button
                  size="tiny"
                  :variant="view === 'diff' ? 'smooth' : 'clear'"
                  @click="view = 'diff'"
                >
                  {{ $t('CANNED_MGMT.FIX.VIEW_DIFF') }}
                </woot-button>
                <woot-button
                  size="tiny"
                  :variant="view === 'edit' ? 'smooth' : 'clear'"
                  @click="view = 'edit'"
                >
                  {{ $t('CANNED_MGMT.FIX.VIEW_EDIT') }}
                </woot-button>
              </template>
            </div>
            <article
              v-for="(part, index) in parts"
              :key="index"
              class="flex flex-col gap-2 p-2 border border-solid rounded-md border-slate-100 dark:border-slate-700"
            >
              <div class="flex items-center gap-2">
                <input
                  v-model="part.short_code"
                  type="text"
                  class="!mb-0 flex-1 text-sm"
                  :readonly="fixedNames"
                  :aria-label="$t('CANNED_MGMT.ADD.FORM.SHORT_CODE.LABEL')"
                  @input="edited"
                />
                <span
                  v-if="changeOf(index) !== null"
                  class="text-xs tabular-nums text-slate-500"
                >
                  {{ $t('CANNED_MGMT.FIX.CHANGED', { pct: changeOf(index) }) }}
                </span>
                <woot-button
                  v-if="parts.length > 1 && !fixedNames"
                  v-tooltip.top="$t('CANNED_MGMT.FIX.REMOVE_PART')"
                  size="tiny"
                  variant="clear"
                  color-scheme="alert"
                  icon="delete"
                  @click="removePart(index)"
                />
              </div>
              <!-- eslint-disable vue/no-v-html -->
              <div
                v-if="withDiff && view === 'diff'"
                class="p-2 overflow-y-auto text-xs whitespace-pre-wrap break-words rounded-md max-h-[40vh] bg-slate-25 dark:bg-slate-900"
                v-html="diff(index)"
              />
              <!-- eslint-enable vue/no-v-html -->
              <textarea
                v-else
                v-model="part.content"
                rows="8"
                class="!mb-0 text-xs"
                :aria-label="$t('CANNED_MGMT.ADD.FORM.CONTENT.LABEL')"
                @input="edited"
              />
              <CharMeter
                :short-code="part.short_code"
                :content="part.content"
              />
            </article>
          </section>
        </div>

        <!-- Comprobaciones -->
        <section
          v-if="!notAdvised"
          class="flex flex-col gap-2 p-3 text-sm border border-solid rounded-md border-slate-100 dark:border-slate-700"
        >
          <div class="flex items-center gap-2">
            <h3
              class="!m-0 text-sm font-medium text-slate-800 dark:text-slate-100"
            >
              {{ $t('CANNED_MGMT.FIX.CHECKS.TITLE') }}
            </h3>
            <span
              v-if="dirty"
              class="text-xs text-amber-700 dark:text-amber-400"
            >
              {{ $t('CANNED_MGMT.FIX.CHECKS.OUTDATED') }}
            </span>
          </div>
          <ul class="!m-0 !pl-0 list-none flex flex-col gap-1">
            <li v-for="clave in presentBlockingChecks" :key="clave">
              <span
                class="inline-block w-4 font-bold"
                :class="markClass(checks[clave] && checks[clave].ok, true)"
              >
                {{ mark(checks[clave] && checks[clave].ok) }}
              </span>
              {{ checkLabel(clave) }}
            </li>
            <li
              v-if="missingData.length"
              class="pl-5 text-xs text-red-700 dark:text-red-400"
            >
              {{ $t('CANNED_MGMT.FIX.CHECKS.MISSING') }}
              {{ missingData.map(d => d.text).join(' · ') }}
            </li>
            <li v-if="checks.resolved">
              <span
                class="inline-block w-4 font-bold"
                :class="markClass(checks.resolved.ok, true)"
              >
                {{ mark(checks.resolved.ok) }}
              </span>
              {{ $t('CANNED_MGMT.FIX.CHECKS.RESOLVED') }}
              <span
                v-if="checks.resolved.still_wrong.length"
                class="block pl-5 text-xs text-red-700 dark:text-red-400"
              >
                {{ $t('CANNED_MGMT.FIX.CHECKS.STILL_WRONG') }}
                {{ checks.resolved.still_wrong.map(d => d.text).join(' · ') }}
              </span>
              <span
                v-if="checks.resolved.missing_right.length"
                class="block pl-5 text-xs text-red-700 dark:text-red-400"
              >
                {{ $t('CANNED_MGMT.FIX.CHECKS.MISSING_RIGHT') }}
                {{ checks.resolved.missing_right.map(d => d.text).join(' · ') }}
              </span>
            </li>
            <li v-if="checks.coverage">
              <span
                class="inline-block w-4 font-bold"
                :class="
                  markClass(checks.coverage.ok, blocking.includes('coverage'))
                "
              >
                {{ checks.coverage.ok ? '✓' : '!' }}
              </span>
              {{
                $t('CANNED_MGMT.FIX.CHECKS.COVERAGE', {
                  kept: checks.coverage.lines - checks.coverage.dropped_count,
                  total: checks.coverage.lines,
                })
              }}
              <ul
                v-if="checks.coverage.dropped.length"
                class="!my-1 !pl-5 text-xs text-amber-700 dark:text-amber-400"
              >
                <li v-for="(linea, i) in checks.coverage.dropped" :key="i">
                  {{ linea }}
                </li>
              </ul>
            </li>
            <li v-if="checks.changes">
              <span
                class="inline-block w-4 font-bold"
                :class="markClass(!tooMuchChange, false)"
              >
                {{ tooMuchChange ? '!' : '✓' }}
              </span>
              {{
                tooMuchChange
                  ? $t('CANNED_MGMT.FIX.CHECKS.TOO_MUCH_CHANGE')
                  : $t('CANNED_MGMT.FIX.CHECKS.SMALL_CHANGE')
              }}
            </li>
            <li v-if="checks.pair">
              <span
                class="inline-block w-4 font-bold"
                :class="markClass(checks.pair.ok, false)"
              >
                {{ checks.pair.ok ? '✓' : '!' }}
              </span>
              {{
                $t(
                  checks.pair.ok
                    ? 'CANNED_MGMT.FIX.CHECKS.PAIR_OK'
                    : 'CANNED_MGMT.FIX.CHECKS.PAIR_BAD',
                  { before: checks.pair.before, after: checks.pair.after }
                )
              }}
            </li>
            <li v-if="checks.duplicates && !checks.duplicates.skipped">
              <span
                class="inline-block w-4 font-bold"
                :class="markClass(checks.duplicates.ok, false)"
              >
                {{ checks.duplicates.ok ? '✓' : '!' }}
              </span>
              {{
                checks.duplicates.ok
                  ? $t('CANNED_MGMT.FIX.CHECKS.NO_DUPLICATES')
                  : $t('CANNED_MGMT.FIX.CHECKS.DUPLICATES', {
                      names: checks.duplicates.existing
                        .map(d => d.short_code)
                        .concat(
                          checks.duplicates.pairs.map(
                            p => `${p.a + 1} ↔ ${p.b + 1}`
                          )
                        )
                        .join(', '),
                    })
              }}
            </li>
            <li
              v-if="
                checks.search && !checks.search.skipped && checks.search.total
              "
            >
              <span
                class="inline-block w-4 font-bold"
                :class="markClass(checks.search.ok, false)"
              >
                {{ checks.search.ok ? '✓' : '!' }}
              </span>
              {{
                $t('CANNED_MGMT.FIX.CHECKS.SEARCH', {
                  found: checks.search.found,
                  total: checks.search.total,
                })
              }}
              <ul
                v-if="failedQuestions.length"
                class="!my-1 !pl-5 text-xs text-amber-700 dark:text-amber-400"
              >
                <li v-for="(q, i) in failedQuestions" :key="i">
                  «{{ q.text }}» →
                  {{ q.top.map(t => t.short_code).join(' · ') }}
                </li>
              </ul>
            </li>
          </ul>
          <label
            v-if="forceable"
            class="flex items-center gap-2 !mb-0 text-xs text-slate-700 dark:text-slate-200"
          >
            <input v-model="force" type="checkbox" class="!m-0" />
            {{ $t('CANNED_MGMT.FIX.FORCE') }}
          </label>
        </section>

        <footer class="flex flex-wrap items-center gap-2">
          <woot-button
            variant="smooth"
            color-scheme="secondary"
            icon="wand"
            @click="propose"
          >
            {{ $t('CANNED_MGMT.FIX.PROPOSE_AGAIN') }}
          </woot-button>
          <woot-button
            variant="clear"
            color-scheme="secondary"
            @click="discard"
          >
            {{ $t('CANNED_MGMT.FIX.DISCARD') }}
          </woot-button>
          <span class="flex-1" />
          <woot-button
            v-if="!notAdvised"
            variant="smooth"
            icon="arrow-clockwise"
            :is-loading="isChecking"
            @click="recheck"
          >
            {{ $t('CANNED_MGMT.FIX.RECHECK') }}
          </woot-button>
          <woot-button
            v-if="!notAdvised"
            icon="checkmark"
            :is-loading="isApplying"
            :is-disabled="cannotApply"
            @click="apply"
          >
            {{ $t('CANNED_MGMT.FIX.APPLY') }}
          </woot-button>
        </footer>
      </template>
    </div>
  </woot-modal>
</template>

<style lang="scss">
.modal-container.fix-wide {
  @apply w-[76rem] max-w-[96vw] max-h-[94vh] overflow-y-auto;
}
</style>
