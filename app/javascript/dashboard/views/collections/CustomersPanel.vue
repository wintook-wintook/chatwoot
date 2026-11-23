<!--
  Cobranza › Clientes: los de la cartera con lo que deben, su etapa y si están ligados a su contacto. «Por ligar»: los que
  no se encontraron solos (por WhatsApp, correo o RFC); se crean con los datos de la cartera, se ligan a un contacto que
  ya existe o se ignoran. Al dar clic, su detalle: facturas, promesas, comprobantes y su conversación.
-->
<script>
import { useAlert } from 'dashboard/composables';
import CollectionsAPI from 'dashboard/api/collections';
import ContactAPI from 'dashboard/api/contacts';
import { money, shortDate } from './money';

const FILTERS = ['balance', 'pending', 'ignored', 'all'];

export default {
  name: 'CustomersPanel',
  props: {
    initialFilter: { type: String, default: 'balance' },
  },
  emits: ['changed'],
  data() {
    return {
      filter: this.initialFilter,
      q: '',
      page: 1,
      total: 0,
      rows: [],
      loading: false,
      busy: false,
      detail: null,
      linking: null,
      search: '',
      found: [],
    };
  },
  computed: {
    filters() {
      return FILTERS;
    },
    pages() {
      return Math.max(Math.ceil(this.total / 50), 1);
    },
  },
  watch: {
    initialFilter(value) {
      this.filter = value;
      this.load();
    },
  },
  mounted() {
    this.load();
  },
  methods: {
    money,
    shortDate,
    t(key, params) {
      return this.$t(`COLLECTIONS.CUSTOMERS.${key}`, params);
    },
    async load() {
      this.loading = true;
      try {
        const { data } = await CollectionsAPI.customers({
          filter: this.filter,
          q: this.q,
          page: this.page,
        });
        this.rows = data.customers;
        this.total = data.total;
      } finally {
        this.loading = false;
      }
    },
    setFilter(f) {
      this.filter = f;
      this.page = 1;
      this.load();
    },
    async act(promise) {
      this.busy = true;
      try {
        await promise;
        await this.load();
        this.$emit('changed');
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('ERROR'));
      } finally {
        this.busy = false;
      }
    },
    create(row) {
      this.act(CollectionsAPI.createCustomer(row.id));
    },
    ignore(row) {
      this.act(CollectionsAPI.ignore(row.id));
    },
    createAll() {
      this.act(CollectionsAPI.createPending());
    },
    openLink(row) {
      this.linking = row;
      this.search = row.contact_name || row.name;
      this.findContacts();
    },
    async findContacts() {
      if (!this.search.trim()) return;
      const { data } = await ContactAPI.search(this.search.trim());
      this.found = data.payload || [];
    },
    async link(contact) {
      await this.act(CollectionsAPI.link(this.linking.id, contact.id));
      this.linking = null;
    },
    async openDetail(row) {
      const { data } = await CollectionsAPI.customer(row.id);
      this.detail = data;
    },
    openConversation(id) {
      this.$router.push({
        name: 'inbox_conversation',
        params: { conversation_id: id },
      });
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <div class="flex flex-wrap items-center gap-2">
      <button
        v-for="f in filters"
        :key="f"
        type="button"
        class="px-3 py-1 text-sm border rounded-full"
        :class="
          filter === f
            ? 'border-woot-500 text-woot-700 bg-woot-25 dark:bg-woot-900/20'
            : 'border-slate-200 dark:border-slate-600 text-slate-600 dark:text-slate-300'
        "
        @click="setFilter(f)"
      >
        {{ t(`FILTERS.${f}`) }}
      </button>
      <input
        v-model="q"
        type="search"
        class="!mb-0 !w-56"
        :placeholder="t('SEARCH')"
        @keyup.enter="load"
      />
      <woot-button
        v-if="filter === 'pending' && total"
        size="small"
        icon="person-add"
        :is-loading="busy"
        @click="createAll"
      >
        {{ t('CREATE_ALL', { n: total }) }}
      </woot-button>
    </div>
    <p v-if="filter === 'pending'" class="m-0 text-xs text-slate-500">
      {{ t('PENDING_HINT') }}
    </p>

    <p v-if="loading" class="m-0 text-sm text-slate-500">{{ t('LOADING') }}</p>
    <p v-else-if="!rows.length" class="m-0 text-sm text-slate-500">
      {{ t('EMPTY') }}
    </p>
    <div v-else class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="text-xs text-left text-slate-500">
            <th class="py-1 pr-2">{{ t('COLS.CUSTOMER') }}</th>
            <th class="py-1 pr-2">{{ t('COLS.CONTACT') }}</th>
            <th class="py-1 pr-2">{{ t('COLS.BALANCE') }}</th>
            <th class="py-1 pr-2">{{ t('COLS.OVERDUE') }}</th>
            <th class="py-1 pr-2">{{ t('COLS.STAGE') }}</th>
            <th class="py-1 pr-2">{{ t('COLS.LAST') }}</th>
            <th class="py-1" />
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="row in rows"
            :key="row.id"
            class="border-t cursor-pointer border-slate-100 dark:border-slate-700 hover:bg-slate-25 dark:hover:bg-slate-800"
            @click="openDetail(row)"
          >
            <td class="py-2 pr-2">
              <span class="font-medium">{{ row.name }}</span>
              <span class="block text-xs text-slate-500">
                {{ row.rfc || row.external_key }}
              </span>
            </td>
            <td class="py-2 pr-2 text-xs">
              <span v-if="row.contact">{{ row.contact.name }}</span>
              <span v-else class="text-amber-700">
                {{ t(`LINK.${row.link_status}`) }}
              </span>
              <span class="block text-slate-500">
                {{ row.phone || row.email }}
              </span>
            </td>
            <td class="py-2 pr-2">{{ money(row.total, row.currency) }}</td>
            <td class="py-2 pr-2 text-red-700 dark:text-red-400">
              {{ row.overdue ? money(row.overdue, row.currency) : '—' }}
            </td>
            <td class="py-2 pr-2 text-xs">
              {{ row.total ? t(`STAGES.${row.stage}`) : '—' }}
            </td>
            <td class="py-2 pr-2 text-xs">
              {{ shortDate(row.last_contacted_at) }}
            </td>
            <td class="py-2 text-right whitespace-nowrap" @click.stop>
              <template v-if="row.link_status === 'pending'">
                <woot-button
                  size="tiny"
                  variant="smooth"
                  :is-loading="busy"
                  @click="create(row)"
                >
                  {{ t('CREATE') }}
                </woot-button>
                <woot-button size="tiny" variant="clear" @click="openLink(row)">
                  {{ t('LINK_BUTTON') }}
                </woot-button>
                <woot-button
                  size="tiny"
                  variant="clear"
                  color-scheme="secondary"
                  @click="ignore(row)"
                >
                  {{ t('IGNORE') }}
                </woot-button>
              </template>
            </td>
          </tr>
        </tbody>
      </table>
      <div v-if="pages > 1" class="flex items-center gap-2 mt-2 text-sm">
        <woot-button
          size="tiny"
          variant="clear"
          :disabled="page === 1"
          @click="
            page -= 1;
            load();
          "
        >
          {{ t('PREV') }}
        </woot-button>
        <span>{{ t('PAGE', { page, pages }) }}</span>
        <woot-button
          size="tiny"
          variant="clear"
          :disabled="page >= pages"
          @click="
            page += 1;
            load();
          "
        >
          {{ t('NEXT') }}
        </woot-button>
      </div>
    </div>

    <!-- Ligar a un contacto que ya existe -->
    <woot-modal :show="!!linking" :on-close="() => (linking = null)">
      <woot-modal-header
        :header-title="t('LINK_TITLE', { name: linking ? linking.name : '' })"
      />
      <div class="flex flex-col gap-2 px-8 pb-8">
        <input
          v-model="search"
          type="search"
          class="!mb-0"
          :placeholder="t('SEARCH_CONTACT')"
          @keyup.enter="findContacts"
        />
        <button
          v-for="c in found"
          :key="c.id"
          type="button"
          class="flex justify-between p-2 text-sm text-left border rounded-md border-slate-100 dark:border-slate-700 hover:border-woot-300"
          @click="link(c)"
        >
          <span>{{ c.name }}</span>
          <span class="text-xs text-slate-500">
            {{ c.phone_number || c.email }}
          </span>
        </button>
        <p v-if="!found.length" class="m-0 text-xs text-slate-500">
          {{ t('NO_CONTACTS') }}
        </p>
      </div>
    </woot-modal>

    <!-- Detalle del cliente -->
    <woot-modal
      :show="!!detail"
      size="medium"
      :on-close="() => (detail = null)"
    >
      <template v-if="detail">
        <woot-modal-header
          :header-title="detail.name"
          :header-content="
            t('DETAIL_SUB', {
              total: money(detail.total, detail.currency),
              overdue: money(detail.overdue, detail.currency),
            })
          "
        />
        <div class="flex flex-col gap-3 px-8 pb-8 text-sm">
          <woot-button
            v-if="detail.conversation_id"
            size="small"
            variant="smooth"
            icon="chat"
            class="self-start"
            @click="openConversation(detail.conversation_id)"
          >
            {{ t('OPEN_CONVERSATION') }}
          </woot-button>
          <table class="w-full">
            <thead>
              <tr class="text-xs text-left text-slate-500">
                <th class="py-1 pr-2">{{ t('INV.FOLIO') }}</th>
                <th class="py-1 pr-2">{{ t('INV.DUE') }}</th>
                <th class="py-1 pr-2">{{ t('INV.BALANCE') }}</th>
                <th class="py-1">{{ t('INV.STATUS') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="r in detail.receivables"
                :key="r.id"
                class="border-t border-slate-100 dark:border-slate-700"
              >
                <td class="py-1 pr-2">{{ r.folio }}</td>
                <td class="py-1 pr-2">{{ shortDate(r.due_on) }}</td>
                <td class="py-1 pr-2">{{ money(r.balance, r.currency) }}</td>
                <td class="py-1 text-xs">
                  {{
                    r.disputed_at
                      ? t('INV.DISPUTED')
                      : r.claimed_at
                      ? t('INV.CLAIMED')
                      : t(`INV.${r.status}`)
                  }}
                </td>
              </tr>
            </tbody>
          </table>
          <div v-if="detail.promises.length">
            <p class="m-0 text-xs font-medium">{{ t('PROMISES') }}</p>
            <p
              v-for="p in detail.promises"
              :key="p.id"
              class="m-0 text-xs text-slate-600"
            >
              {{
                t('PROMISE_LINE', {
                  date: shortDate(p.promised_on),
                  status: $t(`COLLECTIONS.PROMISES.STATUS.${p.status}`),
                })
              }}
            </p>
          </div>
        </div>
      </template>
    </woot-modal>
  </div>
</template>
