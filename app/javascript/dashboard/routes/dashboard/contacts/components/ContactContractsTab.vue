<!--
  Plan-Contratos R1 — Página del contacto › Contratos: lo que tiene contratado
  (monitoreo, iguala, licencia…), cada cuánto se cobra, el próximo cobro, el plazo y
  su estado, con las acciones de cada uno.
-->
<script>
import { mapGetters } from 'vuex';
import ContractsAPI from 'dashboard/api/contracts';
import ContractTypesAPI from 'dashboard/api/contractTypes';
import Spinner from 'shared/components/Spinner.vue';
import ContractForm from 'dashboard/views/contracts/ContractForm.vue';
import ContractActions from 'dashboard/views/contracts/ContractActions.vue';
import {
  contractAccess,
  contractAmount,
  everyLabel,
  formatDate,
  stateChipClass,
} from 'dashboard/views/contracts/contractHelpers';

export default {
  name: 'ContactContractsTab',
  components: { Spinner, ContractForm, ContractActions },
  props: {
    contactId: { type: Number, required: true },
  },
  data() {
    return { contracts: [], types: [], loading: true, form: null };
  },
  computed: {
    ...mapGetters({ currentUser: 'getCurrentUser' }),
    access() {
      return contractAccess(this.currentUser, this.$route.params.accountId);
    },
  },
  watch: {
    contactId: 'fetch',
  },
  mounted() {
    this.fetch();
    this.fetchTypes();
  },
  methods: {
    formatDate,
    contractAmount,
    stateChipClass,
    everyLabel(contract) {
      return everyLabel(this.$t.bind(this), contract.every, contract.unit);
    },
    async fetch() {
      this.loading = true;
      try {
        const { data } = await ContractsAPI.list({
          contact_id: this.contactId,
        });
        this.contracts = data.contracts || [];
      } catch {
        this.contracts = [];
      } finally {
        this.loading = false;
      }
    },
    async fetchTypes() {
      try {
        const { data } = await ContractTypesAPI.list();
        this.types = data.contract_types || [];
      } catch {
        this.types = [];
      }
    },
    customValues(contract) {
      const type = this.types.find(t => t.id === contract.contract_type_id);
      const fields = (type && type.custom_fields) || [];
      return fields
        .map(field => ({
          label: field.label,
          value: (contract.custom_attributes || {})[field.key],
        }))
        .filter(item => item.value);
    },
    onSaved() {
      this.form = null;
      this.fetch();
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <header class="flex items-center justify-between gap-2">
      <h3 class="m-0 text-sm font-semibold text-slate-700 dark:text-slate-200">
        {{ $t('CONTRACTS.TITLE') }}
      </h3>
      <woot-button
        v-if="access.canEdit"
        size="small"
        icon="add"
        @click="form = { contract: null }"
      >
        {{ $t('CONTRACTS.NEW') }}
      </woot-button>
    </header>
    <Spinner v-if="loading" />
    <p
      v-else-if="!contracts.length"
      class="py-6 m-0 text-sm text-center text-slate-500 dark:text-slate-400"
    >
      {{ $t('CONTRACTS.EMPTY_CONTACT') }}
    </p>
    <ul
      v-else
      class="p-0 m-0 list-none bg-white border divide-y rounded-lg dark:bg-slate-900 border-slate-75 dark:border-slate-700 divide-slate-50 dark:divide-slate-800"
    >
      <li
        v-for="contract in contracts"
        :key="contract.id"
        class="flex items-start gap-3 px-3 py-2.5"
        :class="{ 'opacity-60': contract.status === 'cancelled' }"
      >
        <span
          class="flex-shrink-0 w-2.5 h-2.5 mt-1.5 rounded-full"
          :style="{
            backgroundColor:
              contract.links.contract_type &&
              contract.links.contract_type.color,
          }"
        />
        <div class="flex flex-col flex-1 min-w-0 gap-0.5">
          <span class="flex flex-wrap items-center gap-2">
            <span
              class="text-sm font-medium truncate text-slate-800 dark:text-slate-100"
            >
              {{ contract.title }}
            </span>
            <span
              class="px-2 py-0.5 text-xs font-medium rounded-full"
              :class="stateChipClass(contract.state)"
            >
              {{ $t(`CONTRACTS.STATES.${contract.state}`) }}
            </span>
          </span>
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{
              contract.links.contract_type && contract.links.contract_type.name
            }}
            · {{ everyLabel(contract) }}
            <template v-if="contractAmount(contract)">
              · {{ contractAmount(contract) }}
            </template>
          </span>
          <span class="text-xs text-slate-600 dark:text-slate-300">
            <template v-if="contract.status === 'cancelled'">
              {{
                $t('CONTRACTS.CARD.CANCELLED', {
                  date: formatDate(contract.cancelled_on),
                })
              }}
              <template v-if="contract.cancel_reason">
                ·
                {{
                  $t('CONTRACTS.CARD.REASON', {
                    reason: contract.cancel_reason,
                  })
                }}
              </template>
            </template>
            <template v-else>
              {{
                $t('CONTRACTS.CARD.NEXT_CHARGE', {
                  date: formatDate(contract.next_charge_on),
                })
              }}
              ·
              {{
                contract.ends_on
                  ? $t('CONTRACTS.CARD.ENDS', {
                      date: formatDate(contract.ends_on),
                    })
                  : $t('CONTRACTS.CARD.NO_TERM')
              }}
              <template v-if="contract.ends_on && contract.auto_renew">
                ({{ $t('CONTRACTS.CARD.AUTO_RENEW') }})
              </template>
            </template>
          </span>
          <span
            v-if="
              contract.links.customer_asset || customValues(contract).length
            "
            class="text-xs text-slate-500 dark:text-slate-400"
          >
            <template v-if="contract.links.customer_asset">
              {{
                $t('CONTRACTS.CARD.ASSET', {
                  name: contract.links.customer_asset.name,
                })
              }}
            </template>
            <template v-for="item in customValues(contract)">
              · {{ item.label }}: {{ item.value }}
            </template>
          </span>
        </div>
        <ContractActions
          :contract="contract"
          :can-edit="access.canEdit"
          @changed="fetch"
          @edit="item => (form = { contract: item })"
        />
      </li>
    </ul>

    <ContractForm
      :show="!!form"
      :contract="form && form.contract"
      :contact-id="contactId"
      :types="types"
      :show-amounts="access.showAmounts"
      @close="form = null"
      @saved="onSaved"
    />
  </div>
</template>
