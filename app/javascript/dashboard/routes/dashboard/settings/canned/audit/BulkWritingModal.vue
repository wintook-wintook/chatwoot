<script>
// proyecto@arreglar_predefinidas F2 — «CORREGIR TODAS» (REDACCIÓN DE BAJO RIESGO)
// ============================================================================
// Solo los hallazgos de redacción que son de ortografía o numeración (el servidor elige,
// ver CannedResponseFixesController::BULK_TYPES), hasta 30 por lote. Cada uno se propone
// por separado; aquí se ven los cambios de todos y se aplican los marcados. Vienen
// marcados los que no tienen candados en rojo ni reescritura de más.
// Lo confuso y el tono van uno por uno, desde su hallazgo.
// ============================================================================
import CannedResponseFixAPI from 'dashboard/api/cannedResponseFix';
import { useAlert } from 'dashboard/composables';
import { diffHtml } from './wordDiff';

const POLL_MS = 3000;

export default {
  props: {
    show: { type: Boolean, default: false },
  },
  emits: ['close', 'applied'],
  data() {
    return {
      batch: null,
      fixes: [],
      selected: [],
      isStarting: false,
      isApplying: false,
      count: null,
    };
  },
  computed: {
    running() {
      return this.fixes.some(f => f.status === 'running');
    },
    proposed() {
      return this.fixes.filter(f => f.status === 'proposed' && !f.stale);
    },
  },
  watch: {
    show: {
      immediate: true,
      handler(visible) {
        if (visible) this.start();
        else clearTimeout(this.pollTimer);
      },
    },
  },
  beforeDestroy() {
    clearTimeout(this.pollTimer);
  },
  methods: {
    async start() {
      this.isStarting = true;
      try {
        const { data } = await CannedResponseFixAPI.bulkWriting();
        this.batch = data.batch;
        this.count = data.count;
        if (data.count) await this.refresh();
      } catch (error) {
        const codigo = error?.response?.data?.error;
        useAlert(
          this.$t(`CANNED_MGMT.FIX.ERRORS.${codigo || 'apply_failed'}`, {
            detail: '',
          })
        );
      } finally {
        this.isStarting = false;
      }
    },
    async refresh() {
      const { data } = await CannedResponseFixAPI.batch(this.batch);
      const nuevas = data.filter(
        f =>
          f.status === 'proposed' &&
          !this.fixes.some(v => v.id === f.id && v.status === 'proposed')
      );
      this.fixes = data;
      nuevas.filter(this.isSafe).forEach(f => {
        if (!this.selected.includes(f.id)) this.selected.push(f.id);
      });
      clearTimeout(this.pollTimer);
      if (this.running) {
        this.pollTimer = setTimeout(() => this.refresh(), POLL_MS);
      }
    },
    // La IA no cambió nada: no hay qué aplicar.
    unchanged(fix) {
      const original = fix.originals[0] || {};
      const parte = (fix.proposal.parts || [])[0] || {};
      return (
        parte.content === original.content &&
        parte.short_code === original.short_code
      );
    },
    isSafe(fix) {
      const checks = fix.checks || {};
      return (
        !this.unchanged(fix) &&
        !(checks.blocking || []).length &&
        !(checks.changes && checks.changes.ok === false)
      );
    },
    toggle(id) {
      this.selected = this.selected.includes(id)
        ? this.selected.filter(x => x !== id)
        : [...this.selected, id];
    },
    diff(fix) {
      const antes = (fix.originals[0] || {}).content || '';
      const despues = ((fix.proposal.parts || [])[0] || {}).content || '';
      return diffHtml(antes, despues);
    },
    async applySelected() {
      this.isApplying = true;
      let bien = 0;
      let mal = 0;
      // eslint-disable-next-line no-restricted-syntax
      for (const fix of this.proposed.filter(f =>
        this.selected.includes(f.id)
      )) {
        try {
          // eslint-disable-next-line no-await-in-loop
          await CannedResponseFixAPI.apply(fix.id, fix.proposal.parts, false);
          bien += 1;
        } catch (error) {
          mal += 1;
        }
      }
      this.isApplying = false;
      useAlert(this.$t('CANNED_MGMT.FIX.BULK.DONE', { ok: bien, failed: mal }));
      this.$emit('applied');
      this.$emit('close');
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
          {{ $t('CANNED_MGMT.FIX.BULK.TITLE') }}
        </h2>
        <p class="!m-0 text-sm text-slate-600 dark:text-slate-300">
          {{ $t('CANNED_MGMT.FIX.BULK.SUBTITLE') }}
        </p>
      </header>

      <woot-loading-state
        v-if="isStarting"
        :message="$t('CANNED_MGMT.FIX.LOADING')"
      />
      <p v-else-if="count === 0" class="!m-0 text-sm">
        {{ $t('CANNED_MGMT.FIX.BULK.NONE') }}
      </p>
      <template v-else>
        <p
          v-if="running"
          class="flex items-center gap-2 !m-0 text-sm text-slate-600 dark:text-slate-300"
        >
          <span class="spinner" />
          {{
            $t('CANNED_MGMT.FIX.BULK.RUNNING', {
              done: fixes.filter(f => f.status !== 'running').length,
              total: fixes.length,
            })
          }}
        </p>
        <article
          v-for="fix in fixes"
          :key="fix.id"
          class="flex flex-col gap-2 p-3 border border-solid rounded-md border-slate-100 dark:border-slate-700"
        >
          <div class="flex items-center gap-2">
            <input
              type="checkbox"
              class="!m-0"
              :disabled="fix.status !== 'proposed' || fix.stale"
              :checked="selected.includes(fix.id)"
              :aria-label="(fix.originals[0] || {}).short_code"
              @change="toggle(fix.id)"
            />
            <span class="flex-1 text-sm font-medium truncate">
              {{ (fix.originals[0] || {}).short_code }}
            </span>
            <span
              v-if="fix.status === 'running'"
              class="text-xs text-slate-500"
            >
              {{ $t('CANNED_MGMT.FIX.BULK.WAITING') }}
            </span>
            <span
              v-else-if="fix.status === 'failed'"
              class="text-xs text-red-700 dark:text-red-400"
            >
              {{ $t('CANNED_MGMT.FIX.BULK.FAILED') }}
            </span>
            <span v-else-if="unchanged(fix)" class="text-xs text-slate-500">
              {{ $t('CANNED_MGMT.FIX.BULK.UNCHANGED') }}
            </span>
            <span
              v-else-if="!isSafe(fix)"
              class="text-xs text-amber-700 dark:text-amber-400"
            >
              {{ $t('CANNED_MGMT.FIX.BULK.REVIEW') }}
            </span>
          </div>
          <!-- eslint-disable vue/no-v-html -->
          <div
            v-if="fix.status === 'proposed'"
            class="p-2 overflow-y-auto text-xs whitespace-pre-wrap break-words rounded-md max-h-48 bg-slate-25 dark:bg-slate-900"
            v-html="diff(fix)"
          />
          <!-- eslint-enable vue/no-v-html -->
        </article>
        <footer class="flex items-center gap-2">
          <span class="flex-1" />
          <woot-button
            icon="checkmark"
            :is-loading="isApplying"
            :is-disabled="!selected.length || isApplying"
            @click="applySelected"
          >
            {{ $t('CANNED_MGMT.FIX.BULK.APPLY', { count: selected.length }) }}
          </woot-button>
        </footer>
      </template>
    </div>
  </woot-modal>
</template>
