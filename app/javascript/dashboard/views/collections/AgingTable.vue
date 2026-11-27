<!-- Cobranza: la antigüedad de saldos por moneda (por vencer, 1–15, 16–30, 31–60, 61–90, más de 90 días). -->
<script>
import { money, BUCKETS } from './money';

export default {
  name: 'AgingTable',
  props: {
    aging: { type: Object, default: () => ({}) },
  },
  computed: {
    buckets() {
      return BUCKETS;
    },
    currencies() {
      return Object.keys(this.aging || {});
    },
  },
  methods: {
    money,
    total(currency) {
      return Object.values(this.aging[currency] || {}).reduce(
        (a, b) => a + b,
        0
      );
    },
    pct(currency, bucket) {
      const t = this.total(currency);
      return t
        ? Math.round(((this.aging[currency][bucket] || 0) * 100) / t)
        : 0;
    },
  },
};
</script>

<template>
  <div class="overflow-x-auto">
    <p v-if="!currencies.length" class="m-0 text-sm text-slate-500">
      {{ $t('COLLECTIONS.AGING.EMPTY') }}
    </p>
    <table v-else class="w-full text-sm">
      <thead>
        <tr class="text-xs text-left text-slate-500">
          <th class="py-1 pr-2">{{ $t('COLLECTIONS.AGING.CURRENCY') }}</th>
          <th v-for="b in buckets" :key="b" class="py-1 pr-2">
            {{ $t(`COLLECTIONS.AGING.${b}`) }}
          </th>
          <th class="py-1">{{ $t('COLLECTIONS.AGING.TOTAL') }}</th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="c in currencies"
          :key="c"
          class="border-t border-slate-100 dark:border-slate-700"
        >
          <td class="py-2 pr-2 font-medium">{{ c }}</td>
          <td v-for="b in buckets" :key="b" class="py-2 pr-2">
            <span
              :class="
                b === 'not_due'
                  ? 'text-slate-700 dark:text-slate-200'
                  : 'text-red-700 dark:text-red-400'
              "
            >
              {{ money(aging[c][b] || 0, c) }}
            </span>
            <span class="block text-xs text-slate-500">
              {{ $t('COLLECTIONS.AGING.PCT', { pct: pct(c, b) }) }}
            </span>
          </td>
          <td class="py-2 font-semibold">{{ money(total(c), c) }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
