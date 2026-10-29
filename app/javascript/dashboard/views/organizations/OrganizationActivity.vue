<!--
  Plan-Organizaciones O2 — en la página de la organización, lo de todos sus contactos:
  oportunidades, casos, cotizaciones, contratos y equipos (con lo que el usuario puede
  ver; los montos solo con «Ver montos»).
-->
<script>
import OrganizationsAPI from 'dashboard/api/organizations';
import { formatMoney } from 'dashboard/helper/caseCommercial';
import { formatDate } from './organizationHelpers';

const TABS = ['opportunities', 'cases', 'quotes', 'contracts', 'assets'];

export default {
  name: 'OrganizationActivity',
  props: {
    organizationId: { type: Number, required: true },
  },
  data() {
    return { summary: null, tab: 'opportunities' };
  },
  computed: {
    tabs() {
      return TABS.map(key => ({
        key,
        count: ((this.summary && this.summary[key]) || []).length,
      }));
    },
    rows() {
      return (this.summary && this.summary[this.tab]) || [];
    },
  },
  watch: {
    organizationId: { immediate: true, handler: 'fetch' },
  },
  methods: {
    formatDate,
    async fetch() {
      try {
        const { data } = await OrganizationsAPI.summary(this.organizationId);
        this.summary = data;
      } catch {
        this.summary = null;
      }
    },
    money(amount, currency) {
      return amount === null || amount === undefined
        ? ''
        : formatMoney(amount, currency);
    },
    title(row) {
      if (this.tab === 'quotes') return `#${row.number}-${row.version}`;
      if (this.tab === 'assets')
        return [row.name, row.brand, row.model].filter(Boolean).join(' · ');
      return [row.folio, row.title].filter(Boolean).join(' · ');
    },
    detail(row) {
      if (this.tab === 'quotes')
        return [
          this.$t(`ORGANIZATIONS.ACTIVITY.QUOTE_STATUS.${row.status}`),
          this.money(row.total, row.currency),
        ]
          .filter(Boolean)
          .join(' · ');
      if (this.tab === 'contracts')
        return [
          this.$t(`CONTRACTS.STATES.${row.state}`),
          this.money(row.amount, row.currency),
        ]
          .filter(Boolean)
          .join(' · ');
      if (this.tab === 'assets') return '';
      return [
        row.outcome
          ? this.$t(`ORGANIZATIONS.ACTIVITY.OUTCOME.${row.outcome}`)
          : '',
        this.money(row.amount, row.currency),
        formatDate(row.created_at),
      ]
        .filter(Boolean)
        .join(' · ');
    },
    open(row) {
      const { accountId } = this.$route.params;
      if (this.tab === 'opportunities' || this.tab === 'cases') {
        this.$router.push({
          name: 'gestorTickets_detail',
          params: { accountId, id: row.id },
        });
      } else if (this.tab === 'quotes') {
        this.$router.push({
          name: 'gestorTickets_quote',
          params: { accountId, id: row.id },
        });
      } else {
        this.$router.push({
          name: 'contact_profile_dashboard',
          params: { accountId, contactId: row.contact_id },
          query: { tab: this.tab },
        });
      }
    },
  },
};
</script>

<template>
  <section>
    <nav class="flex flex-wrap gap-1 mb-2">
      <button
        v-for="item in tabs"
        :key="item.key"
        type="button"
        class="flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-md"
        :class="
          tab === item.key
            ? 'bg-woot-50 text-woot-700 font-semibold dark:bg-woot-800 dark:text-woot-100'
            : 'text-slate-600 hover:bg-slate-50 dark:text-slate-300 dark:hover:bg-slate-800'
        "
        @click="tab = item.key"
      >
        {{ $t(`ORGANIZATIONS.ACTIVITY.TABS.${item.key}`) }}
        <span class="text-xs opacity-70">{{ item.count }}</span>
      </button>
    </nav>
    <p v-if="!rows.length" class="m-0 text-sm text-slate-500">
      {{ $t('ORGANIZATIONS.ACTIVITY.EMPTY') }}
    </p>
    <ul class="flex flex-col gap-1 p-0 m-0 list-none">
      <li v-for="row in rows" :key="row.id">
        <button
          type="button"
          class="flex flex-col w-full px-3 py-2 text-left rounded-md bg-slate-25 dark:bg-slate-800 hover:bg-slate-50 dark:hover:bg-slate-700"
          @click="open(row)"
        >
          <span class="text-sm font-medium text-slate-800 dark:text-slate-100">
            {{ title(row) }}
          </span>
          <span v-if="detail(row)" class="text-xs text-slate-500">
            {{ detail(row) }}
          </span>
        </button>
      </li>
    </ul>
  </section>
</template>
