<!--
  Página del contacto › Casos: sus casos y oportunidades (todas las clases que
  el rol deja ver; el servidor ya filtra). Por defecto los abiertos.
  «+ Nuevo caso» abre el mismo modal de alta que la conversación.
-->
<script>
import { mapGetters } from 'vuex';
import CaseTicketsAPI from 'dashboard/api/caseTickets';
import Spinner from 'shared/components/Spinner.vue';
import OrganizationTag from './OrganizationTag.vue'; // Plan-Organizaciones
import CaseTicketModal from 'dashboard/components/contacts/CaseTicket/CaseTicketModal.vue';
import { formatMoney } from 'dashboard/helper/caseCommercial';

export default {
  name: 'ContactCasesTab',
  components: { Spinner, CaseTicketModal, OrganizationTag },
  props: {
    contactId: { type: Number, required: true },
  },
  data() {
    return { tickets: [], loading: true, showClosed: false, showNew: false };
  },
  computed: {
    ...mapGetters({
      agents: 'agents/getAgents',
      getContactTickets: 'caseTickets/getContactTickets',
    }),
    // Los del store (el modal de alta los actualiza): si cambian, se recarga.
    panelTickets() {
      return this.getContactTickets(this.contactId);
    },
  },
  watch: {
    contactId: 'fetch',
    showClosed: 'fetch',
    panelTickets: 'fetch',
  },
  mounted() {
    if (!this.agents.length) this.$store.dispatch('agents/get');
    this.fetch();
  },
  methods: {
    async fetch() {
      this.loading = true;
      try {
        const { data } = await CaseTicketsAPI.getAll({
          contact_id: this.contactId,
          status: this.showClosed ? '' : 'pending',
          per_page: 100,
        });
        this.tickets = data.case_tickets || [];
      } catch {
        this.tickets = [];
      } finally {
        this.loading = false;
      }
    },
    onNewClose() {
      this.showNew = false;
      this.fetch();
    },
    assigneeName(ticket) {
      const agent = this.agents.find(a => a.id === ticket.assignee_id);
      return agent ? agent.name : '—';
    },
    statusLabel(status) {
      const key = `CASE_TICKETS.STATUSES.${status}`;
      return this.$te(key) ? this.$t(key) : status;
    },
    amount(ticket) {
      return ticket.amount ? formatMoney(ticket.amount, ticket.currency) : '';
    },
    created(ticket) {
      return new Date(ticket.created_at).toLocaleDateString(undefined, {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
      });
    },
    open(ticket) {
      this.$router.push({
        name: 'gestorTickets_detail',
        params: { accountId: this.$route.params.accountId, id: ticket.id },
      });
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <div class="flex items-center justify-end gap-4">
      <label
        class="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-300"
      >
        <input v-model="showClosed" type="checkbox" class="m-0" />
        {{ $t('CONTACT_PAGE.CASES.SHOW_CLOSED') }}
      </label>
      <woot-button size="small" icon="add" @click="showNew = true">
        {{ $t('CONTACT_PAGE.CASES.NEW') }}
      </woot-button>
    </div>
    <CaseTicketModal
      v-if="showNew"
      :show="showNew"
      :contact-id="contactId"
      @close="onNewClose"
      @created="fetch"
    />
    <Spinner v-if="loading" />
    <p
      v-else-if="!tickets.length"
      class="py-8 text-sm text-center text-slate-500 dark:text-slate-400"
    >
      {{ $t('CONTACT_PAGE.CASES.EMPTY') }}
    </p>
    <div
      v-else
      class="overflow-x-auto bg-white border rounded-lg dark:bg-slate-900 border-slate-75 dark:border-slate-700"
    >
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-slate-500 dark:text-slate-400">
            <th class="px-3 py-2 font-medium">
              {{ $t('CONTACT_PAGE.CASES.FOLIO') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('CONTACT_PAGE.CASES.TITLE') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('CONTACT_PAGE.CASES.STATUS') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('CONTACT_PAGE.CASES.ASSIGNEE') }}
            </th>
            <th class="px-3 py-2 font-medium text-right">
              {{ $t('CONTACT_PAGE.CASES.AMOUNT') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('CONTACT_PAGE.CASES.CREATED') }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-50 dark:divide-slate-800">
          <tr
            v-for="ticket in tickets"
            :key="ticket.id"
            class="cursor-pointer hover:bg-slate-25 dark:hover:bg-slate-800"
            @click="open(ticket)"
          >
            <td class="px-3 py-2 font-mono whitespace-nowrap">
              {{ ticket.folio }}
            </td>
            <td class="px-3 py-2">
              <span class="block text-slate-800 dark:text-slate-100">
                {{ ticket.title }}
                <OrganizationTag
                  :organization-id="ticket.organization_id"
                  :contact-id="contactId"
                />
              </span>
              <span
                v-if="ticket.case_type"
                class="flex items-center gap-1 text-xs text-slate-500 dark:text-slate-400"
              >
                <span
                  class="inline-block w-2 h-2 rounded-full"
                  :style="{ backgroundColor: ticket.case_type.color }"
                />
                {{ ticket.case_type.name }}
              </span>
            </td>
            <td class="px-3 py-2 whitespace-nowrap">
              {{ statusLabel(ticket.status) }}
            </td>
            <td class="px-3 py-2 whitespace-nowrap">
              {{ assigneeName(ticket) }}
            </td>
            <td class="px-3 py-2 text-right whitespace-nowrap">
              {{ amount(ticket) }}
            </td>
            <td class="px-3 py-2 whitespace-nowrap">
              {{ created(ticket) }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
