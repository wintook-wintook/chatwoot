<script>
// Embudo de contactos E3 — métricas del embudo: cuántas entraron, hasta dónde
// llegaron, cuántas se convirtieron (y en cuántos días), por qué se descartan,
// quién movió las tarjetas y qué tanto acierta la IA (lo que un vendedor corrigió).
/* global axios */
import ApiClient from 'dashboard/api/ApiClient';

const PERIODS = [7, 30, 90];
const SOURCES = ['manual', 'rule', 'ai', 'automation'];

class FunnelMetricsAPI extends ApiClient {
  constructor() {
    super('kanban_type_processes', { accountScoped: true });
  }

  get(boardId, days) {
    return axios.get(`${this.url}/${boardId}/funnel_metrics`, {
      params: { days },
    });
  }
}
const api = new FunnelMetricsAPI();

export default {
  name: 'FunnelMetricsModal',
  props: {
    show: { type: Boolean, default: false },
    boardId: { type: [Number, String], required: true },
    boardName: { type: String, default: '' },
  },
  data() {
    return {
      periods: PERIODS,
      sources: SOURCES,
      days: 30,
      metrics: null,
      loading: false,
      failed: false,
    };
  },
  computed: {
    maxReached() {
      const list = (this.metrics && this.metrics.columns) || [];
      return Math.max(1, ...list.map(c => c.reached));
    },
    totalMoves() {
      const s = (this.metrics && this.metrics.sources) || {};
      return Object.values(s).reduce((a, b) => a + b, 0);
    },
  },
  watch: {
    show: {
      immediate: true,
      handler(open) {
        if (open) this.load();
      },
    },
    days() {
      this.load();
    },
  },
  methods: {
    async load() {
      this.loading = true;
      this.failed = false;
      try {
        const { data } = await api.get(this.boardId, this.days);
        this.metrics = data;
      } catch (e) {
        this.failed = true;
      } finally {
        this.loading = false;
      }
    },
    barWidth(column) {
      return `${Math.round((column.reached / this.maxReached) * 100)}%`;
    },
    barClass(kind) {
      if (kind === 'converted') return 'bg-green-500';
      if (kind === 'discarded') return 'bg-slate-400';
      return 'bg-woot-500';
    },
    fmt(value, suffix = '') {
      return value === null || value === undefined ? '—' : `${value}${suffix}`;
    },
  },
};
</script>

<template>
  <woot-modal :show="show" size="medium" :on-close="() => $emit('close')">
    <div class="flex flex-col gap-4 p-6">
      <div class="flex items-center justify-between gap-2">
        <div>
          <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
            {{ $t('KANBAN.FUNNEL.METRICS.TITLE') }}
          </h2>
          <p class="text-xs text-slate-500 dark:text-slate-400">
            {{ boardName }} · {{ $t('KANBAN.FUNNEL.METRICS.SINCE_NOTE') }}
          </p>
        </div>
        <div class="flex gap-1">
          <button
            v-for="p in periods"
            :key="p"
            type="button"
            class="px-2 py-1 text-xs rounded border"
            :class="
              days === p
                ? 'bg-woot-500 text-white border-woot-500'
                : 'border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300'
            "
            @click="days = p"
          >
            {{ $t('KANBAN.FUNNEL.METRICS.DAYS', { n: p }) }}
          </button>
        </div>
      </div>

      <p v-if="loading" class="text-sm text-slate-500">
        {{ $t('KANBAN.FUNNEL.METRICS.LOADING') }}
      </p>
      <p v-else-if="failed" class="text-sm text-red-600">
        {{ $t('KANBAN.FUNNEL.METRICS.ERROR') }}
      </p>

      <template v-else-if="metrics">
        <div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <div class="p-3 rounded-lg bg-slate-50 dark:bg-slate-800">
            <p class="text-xs text-slate-500 dark:text-slate-400">
              {{ $t('KANBAN.FUNNEL.METRICS.ENTRIES') }}
            </p>
            <p class="text-xl font-semibold text-slate-900 dark:text-slate-100">
              {{ metrics.entries }}
            </p>
          </div>
          <div class="p-3 rounded-lg bg-slate-50 dark:bg-slate-800">
            <p class="text-xs text-slate-500 dark:text-slate-400">
              {{ $t('KANBAN.FUNNEL.METRICS.CONVERTED') }}
            </p>
            <p class="text-xl font-semibold text-slate-900 dark:text-slate-100">
              {{ metrics.converted.count }}
              <span class="text-sm font-normal text-slate-500">
                ({{ fmt(metrics.converted.rate, '%') }})
              </span>
            </p>
          </div>
          <div class="p-3 rounded-lg bg-slate-50 dark:bg-slate-800">
            <p class="text-xs text-slate-500 dark:text-slate-400">
              {{ $t('KANBAN.FUNNEL.METRICS.AVG_DAYS') }}
            </p>
            <p class="text-xl font-semibold text-slate-900 dark:text-slate-100">
              {{ fmt(metrics.converted.avg_days) }}
            </p>
          </div>
          <div class="p-3 rounded-lg bg-slate-50 dark:bg-slate-800">
            <p class="text-xs text-slate-500 dark:text-slate-400">
              {{ $t('KANBAN.FUNNEL.METRICS.AI_ACCURACY') }}
            </p>
            <p class="text-xl font-semibold text-slate-900 dark:text-slate-100">
              {{ fmt(metrics.ai.accuracy, '%') }}
            </p>
            <p class="text-xs text-slate-500 dark:text-slate-400">
              {{
                $t('KANBAN.FUNNEL.METRICS.AI_DETAIL', {
                  moves: metrics.ai.moves,
                  corrected: metrics.ai.corrected,
                })
              }}
            </p>
          </div>
        </div>

        <div>
          <p
            class="mb-2 text-sm font-medium text-slate-700 dark:text-slate-200"
          >
            {{ $t('KANBAN.FUNNEL.METRICS.REACH') }}
          </p>
          <div
            v-for="column in metrics.columns"
            :key="column.id"
            class="flex items-center gap-2 mb-1 text-xs"
          >
            <span class="w-28 truncate text-slate-600 dark:text-slate-300">
              {{ column.name }}
            </span>
            <div class="flex-1 h-4 rounded bg-slate-100 dark:bg-slate-800">
              <div
                class="h-4 rounded"
                :class="barClass(column.kind)"
                :style="{ width: barWidth(column) }"
              />
            </div>
            <span class="w-24 text-right text-slate-600 dark:text-slate-300">
              {{ column.reached }} · {{ column.reach_rate }}%
            </span>
            <span
              class="w-16 text-right text-slate-400"
              :title="$t('KANBAN.FUNNEL.METRICS.NOW_HINT')"
            >
              {{ $t('KANBAN.FUNNEL.METRICS.NOW', { n: column.current }) }}
            </span>
          </div>
        </div>

        <div class="grid gap-4 sm:grid-cols-2">
          <div>
            <p
              class="mb-2 text-sm font-medium text-slate-700 dark:text-slate-200"
            >
              {{ $t('KANBAN.FUNNEL.METRICS.DISCARDS') }}
            </p>
            <p
              v-if="!metrics.discards.length"
              class="text-xs text-slate-500 dark:text-slate-400"
            >
              {{ $t('KANBAN.FUNNEL.METRICS.NONE') }}
            </p>
            <div
              v-for="row in metrics.discards"
              :key="row.reason || 'none'"
              class="flex justify-between gap-2 text-xs text-slate-600 dark:text-slate-300"
            >
              <span class="truncate">
                {{ row.reason || $t('KANBAN.FUNNEL.METRICS.NO_REASON') }}
              </span>
              <span>{{ row.count }}</span>
            </div>
          </div>
          <div>
            <p
              class="mb-2 text-sm font-medium text-slate-700 dark:text-slate-200"
            >
              {{ $t('KANBAN.FUNNEL.METRICS.WHO_MOVED') }}
            </p>
            <div
              v-for="source in sources"
              :key="source"
              class="flex justify-between gap-2 text-xs text-slate-600 dark:text-slate-300"
            >
              <span>{{ $t(`KANBAN.FUNNEL.METRICS.SOURCES.${source}`) }}</span>
              <span>
                {{ metrics.sources[source] || 0 }}
                <span v-if="totalMoves" class="text-slate-400">
                  ({{
                    Math.round(
                      ((metrics.sources[source] || 0) * 100) / totalMoves
                    )
                  }}%)
                </span>
              </span>
            </div>
          </div>
        </div>
      </template>
    </div>
  </woot-modal>
</template>
