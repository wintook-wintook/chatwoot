<!--
  Presupuesto de ventas › Por vendedor y cliente: se elige el vendedor y se le ponen
  metas por cliente (organización o, sin ella, contacto), mes por mes. Abajo, su meta
  global y cuánto suman sus clientes, para ver si cuadra.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import SalesBudgetsAPI from 'dashboard/api/salesBudgets';
import OrganizationContactFields from 'dashboard/views/organizations/OrganizationContactFields.vue';
import { yearMonths, monthLabel, money, clientKey } from './budgetHelpers';

const T = 'SALES_BUDGET.CAPTURE';

export default {
  name: 'BudgetClientGrid',
  components: { OrganizationContactFields },
  props: {
    year: { type: Number, required: true },
    currency: { type: String, default: 'MXN' },
  },
  data() {
    return {
      userId: '',
      clients: [], // [{ key, organizationId, contactId, name }]
      cells: {},
      dirty: {},
      sellerGoal: {},
      newContact: null,
      newOrganization: null,
      saving: false,
    };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents' }),
    months() {
      return yearMonths(this.year);
    },
    hasChanges() {
      return Object.keys(this.dirty).length > 0;
    },
  },
  watch: {
    year: 'fetch',
    currency: 'fetch',
    userId: 'fetch',
  },
  mounted() {
    this.$store.dispatch('agents/get');
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    monthLabel,
    money(value) {
      return money(value, this.currency);
    },
    cellKey(client, period) {
      return `${client.key}|${period}`;
    },
    async fetch() {
      this.dirty = {};
      this.cells = {};
      this.clients = [];
      this.sellerGoal = {};
      if (!this.userId) return;
      const params = {
        year: this.year,
        currency: this.currency,
        user_id: this.userId,
      };
      try {
        const [clientRes, sellerRes] = await Promise.all([
          SalesBudgetsAPI.list({ ...params, kind: 'seller_client' }),
          SalesBudgetsAPI.list({ ...params, kind: 'seller' }),
        ]);
        const clients = {};
        const cells = {};
        clientRes.data.lines.forEach(line => {
          const key = clientKey(line);
          clients[key] = clients[key] || {
            key,
            organizationId: line.organization_id,
            contactId: line.contact_id,
            name: line.client_name,
          };
          cells[`${key}|${line.period}`] = line.amount;
        });
        this.clients = Object.values(clients).sort((a, b) =>
          (a.name || '').localeCompare(b.name || '')
        );
        this.cells = cells;
        const goal = {};
        sellerRes.data.lines.forEach(line => {
          goal[line.period] = line.amount;
        });
        this.sellerGoal = goal;
      } catch {
        useAlert(this.t('ERROR'));
      }
    },
    value(client, period) {
      const v = this.cells[this.cellKey(client, period)];
      return v === undefined || v === null ? '' : v;
    },
    onInput(client, period, event) {
      const k = this.cellKey(client, period);
      this.$set(this.cells, k, event.target.value);
      this.$set(this.dirty, k, { client, period });
    },
    clientsSum(period) {
      return this.clients.reduce(
        (sum, c) => sum + Number(this.value(c, period) || 0),
        0
      );
    },
    // Lo de la meta global que no está repartido entre clientes (negativo = se pasan).
    unassigned(period) {
      return Number(this.sellerGoal[period] || 0) - this.clientsSum(period);
    },
    addClient() {
      const org = this.newOrganization;
      const contact = this.newContact;
      if (!org && !contact) return;
      const client = org
        ? { key: `o:${org.id}`, organizationId: org.id, name: org.name }
        : { key: `c:${contact.id}`, contactId: contact.id, name: contact.name };
      if (!this.clients.some(c => c.key === client.key)) {
        this.clients = [...this.clients, client];
      }
      this.newContact = null;
      this.newOrganization = null;
    },
    async removeClient(client) {
      // eslint-disable-next-line no-alert
      if (!window.confirm(this.t('REMOVE_CONFIRM', { name: client.name }))) {
        return;
      }
      try {
        await SalesBudgetsAPI.removeClient({
          year: this.year,
          currency: this.currency,
          userId: this.userId,
          organizationId: client.organizationId,
          contactId: client.contactId,
        });
        this.fetch();
      } catch {
        useAlert(this.t('ERROR'));
      }
    },
    async save() {
      if (this.saving || !this.hasChanges) return;
      this.saving = true;
      try {
        const lines = Object.values(this.dirty).map(({ client, period }) => ({
          user_id: this.userId,
          organization_id: client.organizationId || undefined,
          contact_id: client.organizationId ? undefined : client.contactId,
          period,
          amount: this.value(client, period),
        }));
        await SalesBudgetsAPI.save({
          year: this.year,
          currency: this.currency,
          lines,
        });
        useAlert(this.t('SAVED'));
        this.fetch();
      } catch (error) {
        useAlert(error?.response?.data?.error || this.t('ERROR'));
      } finally {
        this.saving = false;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <div class="flex flex-wrap items-center gap-2">
      <select v-model="userId" class="!mb-0 text-sm w-60">
        <option value="">{{ t('CHOOSE_SELLER') }}</option>
        <option v-for="agent in agents" :key="agent.id" :value="agent.id">
          {{ agent.name }}
        </option>
      </select>
      <woot-button
        v-if="userId"
        size="small"
        :is-loading="saving"
        :disabled="!hasChanges"
        @click="save"
      >
        {{ t('SAVE') }}
      </woot-button>
    </div>

    <p v-if="!userId" class="m-0 text-sm text-slate-500 dark:text-slate-400">
      {{ t('CHOOSE_SELLER_HINT') }}
    </p>
    <template v-else>
      <div
        class="flex flex-wrap items-end gap-2 p-3 bg-white border rounded-xl border-slate-100 dark:bg-slate-800 dark:border-slate-700"
      >
        <div class="flex-1 min-w-[280px]">
          <OrganizationContactFields
            v-model="newContact"
            :organization.sync="newOrganization"
          />
        </div>
        <woot-button
          size="small"
          variant="smooth"
          icon="add"
          :disabled="!newContact && !newOrganization"
          @click="addClient"
        >
          {{ t('ADD_CLIENT') }}
        </woot-button>
      </div>

      <div
        class="overflow-x-auto bg-white border rounded-xl border-slate-100 dark:bg-slate-800 dark:border-slate-700"
      >
        <table class="min-w-full text-sm">
          <thead>
            <tr class="text-xs text-slate-500 dark:text-slate-400">
              <th
                class="sticky left-0 px-3 py-2 font-medium text-left bg-white dark:bg-slate-800"
              >
                {{ t('CLIENT') }}
              </th>
              <th
                v-for="p in months"
                :key="p"
                class="px-1 py-2 font-medium text-right capitalize"
              >
                {{ monthLabel(p) }}
              </th>
              <th />
            </tr>
          </thead>
          <tbody>
            <tr v-if="!clients.length">
              <td
                :colspan="months.length + 2"
                class="px-3 py-3 text-sm text-slate-500 dark:text-slate-400"
              >
                {{ t('NO_CLIENTS') }}
              </td>
            </tr>
            <tr
              v-for="client in clients"
              :key="client.key"
              class="border-t border-slate-50 dark:border-slate-700/60"
            >
              <td
                class="sticky left-0 px-3 py-1 whitespace-nowrap bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100"
              >
                {{ client.name }}
              </td>
              <td v-for="p in months" :key="p" class="px-1 py-1">
                <input
                  type="number"
                  min="0"
                  step="1000"
                  class="!mb-0 !w-24 !h-8 text-right text-sm tabular-nums"
                  :class="{ '!border-woot-400': dirty[cellKey(client, p)] }"
                  :value="value(client, p)"
                  :aria-label="`${client.name} ${monthLabel(p)}`"
                  @input="onInput(client, p, $event)"
                />
              </td>
              <td class="px-2">
                <woot-button
                  size="tiny"
                  variant="clear"
                  color-scheme="alert"
                  icon="delete"
                  :title="t('REMOVE_CLIENT')"
                  @click="removeClient(client)"
                />
              </td>
            </tr>
          </tbody>
          <tfoot class="text-xs text-slate-600 dark:text-slate-300">
            <tr class="border-t border-slate-100 dark:border-slate-700">
              <td class="sticky left-0 px-3 py-1.5 bg-white dark:bg-slate-800">
                {{ t('CLIENTS_SUM') }}
              </td>
              <td
                v-for="p in months"
                :key="p"
                class="px-1 py-1.5 text-right whitespace-nowrap tabular-nums"
              >
                {{ money(clientsSum(p)) }}
              </td>
              <td />
            </tr>
            <tr>
              <td class="sticky left-0 px-3 py-1.5 bg-white dark:bg-slate-800">
                {{ t('SELLER_GOAL') }}
              </td>
              <td
                v-for="p in months"
                :key="p"
                class="px-1 py-1.5 text-right whitespace-nowrap tabular-nums"
              >
                {{ money(sellerGoal[p]) }}
              </td>
              <td />
            </tr>
            <tr class="font-semibold">
              <td class="sticky left-0 px-3 py-1.5 bg-white dark:bg-slate-800">
                {{ t('UNASSIGNED') }}
              </td>
              <td
                v-for="p in months"
                :key="p"
                class="px-1 py-1.5 text-right whitespace-nowrap tabular-nums"
                :class="{
                  'text-amber-700 dark:text-amber-300': unassigned(p) < 0,
                }"
              >
                {{ money(unassigned(p)) }}
              </td>
              <td />
            </tr>
          </tfoot>
        </table>
      </div>
      <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
        {{ t('UNASSIGNED_HINT') }}
      </p>
    </template>
  </div>
</template>
