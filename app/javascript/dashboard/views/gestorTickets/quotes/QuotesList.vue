<!--
  Plan-Catalogo-Cotizaciones V1 — Ventas › Cotizaciones: cifras arriba
  (enviadas, aceptación, monto en juego, vencidas), pestañas por estado y la
  lista. Las cotizaciones pueden estar solas o ligadas a una oportunidad o a un
  caso (proyecto, orden, soporte). El servidor ya filtra por rol.
-->
<script>
import QuotesAPI from 'dashboard/api/quotes';
import Spinner from 'shared/components/Spinner.vue';
import QuoteStatusChip from './QuoteStatusChip.vue';
import { formatMoney } from 'dashboard/helper/caseCommercial';

const TABS = [
  'open',
  'draft',
  'sent',
  'won',
  'lost',
  'postponed',
  'cancelled',
  'expired',
  'all',
];

export default {
  name: 'QuotesList',
  components: { Spinner, QuoteStatusChip },
  data() {
    return {
      quotes: [],
      counts: {},
      count: 0,
      page: 1,
      perPage: 25,
      loading: true,
      summary: null,
      search: '',
      timer: null,
    };
  },
  computed: {
    activeTab() {
      const { tab } = this.$route.query;
      return TABS.includes(tab) ? tab : 'open';
    },
    tabs() {
      return TABS.map(key => ({
        key,
        name: this.$t(`QUOTES.TABS.${key}`),
        count: this.tabCount(key),
      }));
    },
    activeTabIndex() {
      return TABS.indexOf(this.activeTab);
    },
    pages() {
      return Math.max(1, Math.ceil(this.count / this.perPage));
    },
    cards() {
      if (!this.summary) return [];
      const s = this.summary;
      return [
        { key: 'SENT', value: s.sent },
        {
          key: 'ACCEPTANCE',
          value: s.acceptance_rate === null ? '—' : `${s.acceptance_rate}%`,
        },
        { key: 'IN_PLAY', value: this.amounts(s.in_play) },
        { key: 'EXPIRED', value: s.expired, alert: s.expired > 0 },
        {
          key: 'RESPONSE',
          value:
            s.avg_response_days === null
              ? '—'
              : this.$t('QUOTES.SUMMARY.DAYS', { days: s.avg_response_days }),
        },
      ];
    },
  },
  watch: {
    activeTab() {
      this.page = 1;
      this.fetch();
    },
  },
  mounted() {
    this.fetch();
    this.fetchSummary();
  },
  methods: {
    tabCount(key) {
      const c = this.counts;
      if (key === 'open')
        return (c.draft || 0) + (c.sent || 0) + (c.postponed || 0);
      if (key === 'all')
        return Object.keys(c)
          .filter(k => k !== 'expired')
          .reduce((sum, k) => sum + c[k], 0);
      return c[key] || 0;
    },
    async fetch() {
      this.loading = true;
      try {
        const { data } = await QuotesAPI.list({
          status: this.activeTab,
          q: this.search,
          page: this.page,
        });
        this.quotes = data.quotes || [];
        this.counts = data.meta.counts || {};
        this.count = data.meta.count;
        this.perPage = data.meta.per_page;
      } catch {
        this.quotes = [];
      } finally {
        this.loading = false;
      }
    },
    async fetchSummary() {
      try {
        const { data } = await QuotesAPI.summary();
        this.summary = data;
      } catch {
        this.summary = null;
      }
    },
    onSearch() {
      clearTimeout(this.timer);
      this.timer = setTimeout(() => {
        this.page = 1;
        this.fetch();
      }, 300);
    },
    onTab(index) {
      this.$router.replace({
        query: { ...this.$route.query, tab: TABS[index] },
      });
    },
    amounts(list) {
      if (!list || !list.length) return '—';
      return list.map(a => formatMoney(a.amount, a.currency)).join(' · ');
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
    day(value) {
      if (!value) return '—';
      return new Date(
        `${String(value).slice(0, 10)}T12:00:00`
      ).toLocaleDateString(undefined, {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
      });
    },
    open(quote) {
      this.$router.push({
        name: 'gestorTickets_quote',
        params: { accountId: this.$route.params.accountId, id: quote.id },
      });
    },
    newQuote() {
      this.$router.push({
        name: 'gestorTickets_quote_new',
        params: { accountId: this.$route.params.accountId },
      });
    },
    goTo(page) {
      this.page = page;
      this.fetch();
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-white dark:bg-slate-900"
  >
    <header
      class="flex flex-wrap items-center justify-between gap-3 px-6 pt-5 pb-3"
    >
      <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
        {{ $t('QUOTES.TITLE') }}
      </h1>
      <div class="flex items-center gap-2">
        <input
          v-model="search"
          type="search"
          class="!mb-0 w-64"
          :placeholder="$t('QUOTES.SEARCH')"
          @input="onSearch"
        />
        <woot-button size="small" icon="add" @click="newQuote">
          {{ $t('QUOTES.NEW') }}
        </woot-button>
      </div>
    </header>

    <div
      v-if="cards.length"
      class="grid grid-cols-2 gap-3 px-6 pb-3 md:grid-cols-5"
    >
      <div
        v-for="card in cards"
        :key="card.key"
        class="flex flex-col min-w-0 gap-1 p-3 border rounded-lg border-slate-75 dark:border-slate-700"
      >
        <span class="text-xs text-slate-500 dark:text-slate-400">
          {{ $t(`QUOTES.SUMMARY.${card.key}`) }}
        </span>
        <span
          class="text-base font-semibold truncate"
          :class="
            card.alert
              ? 'text-red-600 dark:text-red-400'
              : 'text-slate-800 dark:text-slate-100'
          "
          :title="String(card.value)"
        >
          {{ card.value }}
        </span>
      </div>
    </div>

    <woot-tabs :index="activeTabIndex" class="px-6" @change="onTab">
      <woot-tabs-item
        v-for="(tab, i) in tabs"
        :key="tab.key"
        :index="i"
        :name="tab.name"
        :count="tab.count"
        :show-badge="tab.count > 0"
      />
    </woot-tabs>

    <div class="flex-1 px-6 pb-4 overflow-auto">
      <Spinner v-if="loading" />
      <p
        v-else-if="!quotes.length"
        class="py-12 text-sm text-center text-slate-500 dark:text-slate-400"
      >
        {{ $t('QUOTES.EMPTY') }}
      </p>
      <table v-else class="w-full text-sm">
        <thead>
          <tr
            class="text-left border-b text-slate-500 dark:text-slate-400 border-slate-50 dark:border-slate-800"
          >
            <th class="px-3 py-2 font-medium">
              {{ $t('QUOTES.COLUMNS.FOLIO') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('QUOTES.COLUMNS.CONTACT') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('QUOTES.COLUMNS.LINK') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('QUOTES.COLUMNS.STATUS') }}
            </th>
            <th class="px-3 py-2 font-medium text-right">
              {{ $t('QUOTES.COLUMNS.TOTAL') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('QUOTES.COLUMNS.VALID_UNTIL') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('QUOTES.COLUMNS.ASSIGNEE') }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-50 dark:divide-slate-800">
          <tr
            v-for="quote in quotes"
            :key="quote.id"
            class="cursor-pointer hover:bg-slate-25 dark:hover:bg-slate-800"
            @click="open(quote)"
          >
            <td class="px-3 py-2 font-mono whitespace-nowrap">
              {{ quote.folio }}
            </td>
            <td class="px-3 py-2 text-slate-800 dark:text-slate-100">
              {{ quote.contact && quote.contact.name }}
            </td>
            <td class="px-3 py-2 text-slate-600 dark:text-slate-300">
              {{ link(quote) || '—' }}
            </td>
            <td class="px-3 py-2"><QuoteStatusChip :quote="quote" /></td>
            <td class="px-3 py-2 text-right whitespace-nowrap">
              {{ total(quote) }}
            </td>
            <td class="px-3 py-2 whitespace-nowrap">
              {{ day(quote.valid_until) }}
            </td>
            <td class="px-3 py-2">
              {{ quote.assignee ? quote.assignee.name : '—' }}
            </td>
          </tr>
        </tbody>
      </table>
      <div
        v-if="pages > 1"
        class="flex items-center justify-end gap-2 pt-3 text-sm"
      >
        <woot-button
          size="tiny"
          variant="clear"
          :disabled="page <= 1"
          icon="chevron-left"
          @click="goTo(page - 1)"
        />
        <span>{{ page }} / {{ pages }}</span>
        <woot-button
          size="tiny"
          variant="clear"
          :disabled="page >= pages"
          icon="chevron-right"
          @click="goTo(page + 1)"
        />
      </div>
    </div>
  </div>
</template>
