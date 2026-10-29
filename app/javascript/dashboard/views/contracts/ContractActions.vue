<!--
  Plan-Contratos R1 — el menú «⋯» de un contrato: registrar el pago del periodo,
  renovar el plazo, suspender, cancelar (con motivo) o reactivar, y editar.
-->
<script>
import { useAlert } from 'dashboard/composables';
import ContractsAPI from 'dashboard/api/contracts';
import { formatDate } from './contractHelpers';

export default {
  name: 'ContractActions',
  props: {
    contract: { type: Object, required: true },
    canEdit: { type: Boolean, default: true },
  },
  emits: ['changed', 'edit'],
  data() {
    return { open: false, busy: false };
  },
  computed: {
    isActive() {
      return this.contract.status === 'active';
    },
    actions() {
      if (!this.canEdit) return [];
      const { status, term_months: term } = this.contract;
      return [
        this.isActive && { key: 'REGISTER_PAYMENT', icon: 'checkmark' },
        status !== 'cancelled' && term && { key: 'RENEW', icon: 'repeat' },
        this.isActive && { key: 'SUSPEND', icon: 'power' },
        status !== 'active' && { key: 'REACTIVATE', icon: 'play-circle' },
        status !== 'cancelled' && {
          key: 'CANCEL',
          icon: 'dismiss-circle',
          danger: true,
        },
        { key: 'EDIT', icon: 'edit' },
      ].filter(Boolean);
    },
  },
  methods: {
    close() {
      this.open = false;
    },
    async run(key) {
      this.open = false;
      if (key === 'EDIT') {
        this.$emit('edit', this.contract);
        return;
      }
      let reason = null;
      if (key === 'CANCEL') {
        // eslint-disable-next-line no-alert
        reason = window.prompt(this.$t('CONTRACTS.ACTIONS.CANCEL_PROMPT'), '');
        if (reason === null) return;
      }
      this.busy = true;
      try {
        const { data } = await this.request(key, reason);
        useAlert(this.message(key, data.contract));
        this.$emit('changed', data.contract);
      } catch (error) {
        useAlert(error?.response?.data?.error || this.$t('CONTRACTS.ERROR'));
      } finally {
        this.busy = false;
      }
    },
    request(key, reason) {
      const { id } = this.contract;
      if (key === 'REGISTER_PAYMENT') return ContractsAPI.registerPayment(id);
      if (key === 'RENEW') return ContractsAPI.renew(id);
      if (key === 'CANCEL') return ContractsAPI.cancel(id, reason);
      if (key === 'REACTIVATE') return ContractsAPI.reactivate(id);
      return ContractsAPI.update(id, { status: 'suspended' });
    },
    message(key, contract) {
      if (key === 'REGISTER_PAYMENT')
        return this.$t('CONTRACTS.ACTIONS.PAID', {
          date: formatDate(contract.next_charge_on),
        });
      if (key === 'RENEW')
        return this.$t('CONTRACTS.ACTIONS.RENEWED', {
          date: formatDate(contract.ends_on),
        });
      if (key === 'CANCEL') return this.$t('CONTRACTS.ACTIONS.CANCELLED_OK');
      if (key === 'REACTIVATE') return this.$t('CONTRACTS.ACTIONS.REACTIVATED');
      return this.$t('CONTRACTS.ACTIONS.SUSPENDED');
    },
  },
};
</script>

<template>
  <div v-if="actions.length" v-on-clickaway="close" class="relative">
    <woot-button
      size="tiny"
      variant="clear"
      color-scheme="secondary"
      icon="more-vertical"
      :is-loading="busy"
      :title="$t('CONTRACTS.ACTIONS.MENU')"
      @click.stop="open = !open"
    />
    <ul
      v-if="open"
      class="absolute right-0 z-50 py-1 mt-1 list-none bg-white border rounded-md shadow-md top-full dark:bg-slate-800 border-slate-100 dark:border-slate-700 min-w-[190px]"
    >
      <li v-for="action in actions" :key="action.key">
        <button
          type="button"
          class="flex items-center w-full gap-2 px-4 py-1.5 text-sm text-left hover:bg-slate-50 dark:hover:bg-slate-700"
          :class="
            action.danger
              ? 'text-red-600 dark:text-red-400'
              : 'text-slate-700 dark:text-slate-200'
          "
          @click.stop="run(action.key)"
        >
          <fluent-icon :icon="action.icon" size="14" />
          {{ $t(`CONTRACTS.ACTIONS.${action.key}`) }}
        </button>
      </li>
    </ul>
  </div>
</template>
