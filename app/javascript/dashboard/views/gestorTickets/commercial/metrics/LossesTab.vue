<!--
  @tickets_cases — Plan-Metricas-Comercial M4: «¿Por qué perdemos?».
  Motivos de pérdida y de cancelación del período, cada uno con cantidad y monto
  perdido por moneda (perder 10 chicas no es lo mismo que una grande). Barras de
  una serie (cantidad) con etiqueta directa, tooltip y vista de tabla.
-->
<script>
import { moneyList } from 'dashboard/helper/caseCommercial';
import KpiTile from './KpiTile.vue';

const OUTCOMES = ['lost', 'cancelled'];

export default {
  name: 'LossesTab',
  components: { KpiTile },
  props: {
    report: { type: Object, required: true },
  },
  data() {
    return { tableView: { lost: false, cancelled: false } };
  },
  computed: {
    outcomes() {
      return OUTCOMES;
    },
    summary() {
      return this.report.summary || {};
    },
    reasons() {
      return this.report.loss_reasons || [];
    },
    totalDecided() {
      const s = this.summary;
      return (
        (s.won_count || 0) + (s.lost_count || 0) + (s.cancelled_count || 0)
      );
    },
  },
  methods: {
    rows(outcome) {
      return this.reasons.filter(r => r.outcome === outcome);
    },
    max(outcome) {
      return Math.max(1, ...this.rows(outcome).map(r => r.count));
    },
    barWidth(count, outcome) {
      return `${Math.max(2, (count / this.max(outcome)) * 100)}%`;
    },
    money(values) {
      return moneyList(values);
    },
    label(r) {
      return (
        r.label || this.$t('CASE_TICKETS.COMMERCIAL.METRICS.REASONS.NO_REASON')
      );
    },
    share(count) {
      return this.totalDecided
        ? `${Math.round((count / this.totalDecided) * 100)}%`
        : '—';
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="grid gap-3 grid-cols-[repeat(auto-fit,minmax(200px,1fr))]">
      <KpiTile
        :label="$t('CASE_TICKETS.COMMERCIAL.METRICS.LOSSES.LOST')"
        :value="`${summary.lost_count || 0} · ${money(summary.lost_value)}`"
        :sub="
          $t('CASE_TICKETS.COMMERCIAL.METRICS.LOSSES.SHARE', {
            pct: share(summary.lost_count || 0),
          })
        "
      />
      <KpiTile
        :label="$t('CASE_TICKETS.COMMERCIAL.METRICS.LOSSES.CANCELLED')"
        :value="`${summary.cancelled_count || 0} · ${money(
          summary.cancelled_value
        )}`"
        :sub="
          $t('CASE_TICKETS.COMMERCIAL.METRICS.LOSSES.SHARE', {
            pct: share(summary.cancelled_count || 0),
          })
        "
      />
    </div>

    <div class="grid gap-4 lg:grid-cols-2">
      <section
        v-for="outcome in outcomes"
        :key="outcome"
        class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <div class="flex items-center justify-between mb-3">
          <h2
            class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ $t(`CASE_TICKETS.COMMERCIAL.METRICS.LOSSES.TITLE_${outcome}`) }}
          </h2>
          <button
            type="button"
            class="text-xs text-woot-600 dark:text-woot-300 hover:underline"
            @click="tableView[outcome] = !tableView[outcome]"
          >
            {{
              tableView[outcome]
                ? $t('CASE_TICKETS.COMMERCIAL.METRICS.CHART_VIEW')
                : $t('CASE_TICKETS.COMMERCIAL.METRICS.TABLE_VIEW')
            }}
          </button>
        </div>
        <p
          v-if="!rows(outcome).length"
          class="m-0 text-sm text-slate-400 dark:text-slate-500"
        >
          {{ $t('CASE_TICKETS.COMMERCIAL.METRICS.LOSSES.NONE') }}
        </p>
        <div v-else-if="!tableView[outcome]" class="flex flex-col gap-2">
          <div
            v-for="r in rows(outcome)"
            :key="r.label || 'none'"
            class="grid items-center gap-3 grid-cols-[9rem_1fr] group"
            :title="`${label(r)}: ${r.count} · ${money(r.values)}`"
          >
            <span class="text-sm truncate text-slate-600 dark:text-slate-300">
              {{ label(r) }}
            </span>
            <div class="flex items-center min-w-0 gap-2">
              <div
                class="h-5 rounded-r bg-slate-500 dark:bg-slate-400 group-hover:bg-slate-600 flex-shrink-0"
                :style="{ width: barWidth(r.count, outcome) }"
              />
              <span
                class="text-xs whitespace-nowrap text-slate-700 dark:text-slate-200"
              >
                <strong>{{ r.count }}</strong> · {{ money(r.values) }}
              </span>
            </div>
          </div>
        </div>
        <table v-else class="w-full text-sm">
          <thead>
            <tr class="text-xs text-left uppercase text-slate-500">
              <th class="py-1">
                {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.REASON') }}
              </th>
              <th class="py-1 text-right">#</th>
              <th class="py-1 text-right">
                {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.AMOUNT') }}
              </th>
            </tr>
          </thead>
          <tbody class="text-slate-700 dark:text-slate-200">
            <tr
              v-for="r in rows(outcome)"
              :key="r.label || 'none'"
              class="border-t border-slate-50 dark:border-slate-700"
            >
              <td class="py-1">{{ label(r) }}</td>
              <td class="py-1 text-right">{{ r.count }}</td>
              <td class="py-1 text-right">{{ money(r.values) }}</td>
            </tr>
          </tbody>
        </table>
      </section>
    </div>
  </div>
</template>
