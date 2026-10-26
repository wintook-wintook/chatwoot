<!--
  Plan-Catalogo-Cotizaciones V1 — estado de una cotización, con las marcas
  «Vista» (el cliente abrió el enlace) y «Vencida» (enviada con vigencia pasada).
-->
<script>
const COLORS = {
  draft: 'bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-200',
  sent: 'bg-woot-50 text-woot-700 dark:bg-woot-900/30 dark:text-woot-300',
  won: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300',
  lost: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300',
  postponed:
    'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300',
  cancelled:
    'bg-slate-200 text-slate-600 dark:bg-slate-700 dark:text-slate-300',
};

export default {
  name: 'QuoteStatusChip',
  props: {
    quote: { type: Object, required: true },
  },
  computed: {
    color() {
      return COLORS[this.quote.status] || COLORS.draft;
    },
  },
};
</script>

<template>
  <span class="inline-flex flex-wrap items-center gap-1">
    <span class="px-2 py-0.5 text-xs font-medium rounded" :class="color">
      {{ $t(`QUOTES.STATUSES.${quote.status}`) }}
    </span>
    <span
      v-if="quote.status === 'sent' && quote.viewed_at"
      class="text-xs text-slate-500 dark:text-slate-400"
    >
      {{ $t('QUOTES.VIEWED') }}
    </span>
    <span
      v-if="quote.expired"
      class="px-1.5 py-0.5 text-xs font-medium text-red-700 rounded bg-red-50 dark:bg-red-900/30 dark:text-red-300"
    >
      {{ $t('QUOTES.EXPIRED') }}
    </span>
  </span>
</template>
