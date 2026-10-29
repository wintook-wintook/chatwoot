<!--
  Página del contacto › pestaña Cotizaciones: todas las del contacto (con o sin
  oportunidad), su estado, a qué caso van y su total. «Nueva» y abrir una
  regresan aquí con «Volver al contacto».
-->
<script>
import QuotesAPI from 'dashboard/api/quotes';
import OrganizationTag from './OrganizationTag.vue'; // Plan-Organizaciones
import Spinner from 'shared/components/Spinner.vue';
import QuoteStatusChip from 'dashboard/views/gestorTickets/quotes/QuoteStatusChip.vue';
import { formatMoney } from 'dashboard/helper/caseCommercial';
import { backQuery } from 'dashboard/views/gestorTickets/backLink';

export default {
  name: 'ContactQuotesTab',
  components: { Spinner, QuoteStatusChip, OrganizationTag },
  props: {
    contactId: { type: Number, required: true },
  },
  data() {
    return { quotes: [], loading: true };
  },
  mounted() {
    this.fetch();
  },
  methods: {
    async fetch() {
      this.loading = true;
      try {
        const { data } = await QuotesAPI.list({
          contact_id: this.contactId,
          status: 'all',
        });
        this.quotes = data.quotes || [];
      } catch {
        this.quotes = [];
      } finally {
        this.loading = false;
      }
    },
    newQuote() {
      this.$router.push({
        name: 'gestorTickets_quote_new',
        params: { accountId: this.$route.params.accountId },
        query: { contact_id: this.contactId, ...backQuery(this.$route) },
      });
    },
    open(quote) {
      this.$router.push({
        name: 'gestorTickets_quote',
        params: { accountId: this.$route.params.accountId, id: quote.id },
        query: backQuery(this.$route),
      });
    },
    total(quote) {
      return quote.total === null
        ? '—'
        : formatMoney(quote.total, quote.currency);
    },
    link(quote) {
      const ticket = quote.opportunity || quote.origin_ticket;
      if (!ticket) return '';
      return `${this.$t(`QUOTES.ORIGIN_CLASS.${ticket.case_class}`)} ${
        ticket.folio
      }`;
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <div class="flex justify-end">
      <woot-button size="small" icon="add" @click="newQuote">
        {{ $t('QUOTES.PANEL.NEW') }}
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
        <OrganizationTag
          :organization-id="quote.organization && quote.organization.id"
          :contact-id="contactId"
        />
        <span class="text-xs text-slate-500 dark:text-slate-400">{{
          link(quote)
        }}</span>
        <span class="flex-1" />
        <span class="text-sm font-medium text-slate-800 dark:text-slate-100">{{
          total(quote)
        }}</span>
      </li>
    </ul>
  </div>
</template>
