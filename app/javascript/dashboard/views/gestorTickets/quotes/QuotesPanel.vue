<!--
  Plan-Catalogo-Cotizaciones V1 — pestaña «Cotizaciones» del detalle de un caso.
  En una oportunidad: sus cotizaciones y «+ Cotización». En un proyecto, una
  orden o un caso de soporte: las que salieron de ahí y «Cotizar trabajo
  adicional» (al aceptarse, lo cotizado pasa a la orden o al proyecto).
-->
<script>
import QuotesAPI from 'dashboard/api/quotes';
import Spinner from 'shared/components/Spinner.vue';
import QuoteStatusChip from './QuoteStatusChip.vue';
import { formatMoney } from 'dashboard/helper/caseCommercial';
import { backQuery } from '../backLink';

export default {
  name: 'QuotesPanel',
  components: { Spinner, QuoteStatusChip },
  props: {
    ticket: { type: Object, required: true },
  },
  emits: ['count'],
  data() {
    return { quotes: [], loading: true };
  },
  computed: {
    isOpportunity() {
      return !!(
        this.ticket.case_type &&
        this.ticket.case_type.case_class === 'commercial'
      );
    },
    filter() {
      return this.isOpportunity
        ? { opportunity_id: this.ticket.id }
        : { origin_ticket_id: this.ticket.id };
    },
  },
  watch: {
    'ticket.id': 'fetch',
  },
  mounted() {
    this.fetch();
  },
  methods: {
    async fetch() {
      this.loading = true;
      try {
        const { data } = await QuotesAPI.list({
          ...this.filter,
          status: 'all',
        });
        this.quotes = data.quotes || [];
        this.$emit('count', this.quotes.length);
      } catch {
        this.quotes = [];
      } finally {
        this.loading = false;
      }
    },
    // «Volver» de la cotización regresa a este caso, en la pestaña Cotizaciones.
    backToCase() {
      return backQuery(this.$route, { tab: 'quotes' });
    },
    newQuote() {
      const query = { ...this.filter, ...this.backToCase() };
      if (this.ticket.contact_id) query.contact_id = this.ticket.contact_id;
      this.$router.push({
        name: 'gestorTickets_quote_new',
        params: { accountId: this.$route.params.accountId },
        query,
      });
    },
    open(quote) {
      this.$router.push({
        name: 'gestorTickets_quote',
        params: { accountId: this.$route.params.accountId, id: quote.id },
        query: this.backToCase(),
      });
    },
    total(quote) {
      return quote.total === null
        ? '—'
        : formatMoney(quote.total, quote.currency);
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <div class="flex justify-end">
      <woot-button
        v-if="ticket.contact_id"
        size="small"
        icon="add"
        @click="newQuote"
      >
        {{
          isOpportunity ? $t('QUOTES.PANEL.NEW') : $t('QUOTES.PANEL.EXTRA_WORK')
        }}
      </woot-button>
    </div>
    <Spinner v-if="loading" />
    <p
      v-else-if="!quotes.length"
      class="py-6 text-sm text-center text-slate-500 dark:text-slate-400"
    >
      {{ $t('QUOTES.PANEL.EMPTY') }}
    </p>
    <ul
      v-else
      class="p-0 m-0 list-none bg-white border divide-y rounded-lg dark:bg-slate-900 border-slate-75 dark:border-slate-700 divide-slate-50 dark:divide-slate-800"
    >
      <li
        v-for="quote in quotes"
        :key="quote.id"
        class="flex flex-wrap items-center gap-3 px-3 py-2 cursor-pointer hover:bg-slate-25 dark:hover:bg-slate-800"
        @click="open(quote)"
      >
        <span class="font-mono text-sm">{{ quote.folio }}</span>
        <QuoteStatusChip :quote="quote" />
        <span class="flex-1" />
        <span class="text-sm font-medium text-slate-800 dark:text-slate-100">{{
          total(quote)
        }}</span>
      </li>
    </ul>
  </div>
</template>
