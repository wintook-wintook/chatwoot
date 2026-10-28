<!--
  Plan-Trabajo-Campo R4 — renglones de mantenimientos (en el contacto y en
  Servicio › Mantenimientos): cada cuánto, próxima fecha, equipo, técnico,
  órdenes abiertas; Editar, Generar ya y Eliminar.
-->
<script>
import { useAlert } from 'dashboard/composables';
import MaintenancePlansAPI from 'dashboard/api/maintenancePlans';

export default {
  name: 'PlanList',
  props: {
    plans: { type: Array, required: true },
    showContact: { type: Boolean, default: false },
  },
  emits: ['edit', 'changed'],
  methods: {
    frequency(plan) {
      return this.$t(`MAINTENANCE.EVERY_${plan.unit.toUpperCase()}`, {
        n: plan.every,
      });
    },
    dueLabel(plan) {
      const [y, m, d] = plan.next_due_on.split('-').map(Number);
      return new Date(y, m - 1, d).toLocaleDateString(undefined, {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
      });
    },
    overdue(plan) {
      return plan.next_due_on < new Date().toISOString().slice(0, 10);
    },
    async generate(plan) {
      try {
        const { data } = await MaintenancePlansAPI.generate(plan.id);
        useAlert(
          this.$t('MAINTENANCE.GENERATED', { folio: data.case_ticket.folio })
        );
        this.$emit('changed');
      } catch (error) {
        useAlert(error?.response?.data?.error || this.$t('MAINTENANCE.ERROR'));
      }
    },
    async remove(plan) {
      // eslint-disable-next-line no-alert
      if (!window.confirm(this.$t('MAINTENANCE.CONFIRM_DELETE'))) return;
      try {
        await MaintenancePlansAPI.delete(plan.id);
        this.$emit('changed');
      } catch (error) {
        useAlert(error?.response?.data?.error || this.$t('MAINTENANCE.ERROR'));
      }
    },
    openContact(plan) {
      this.$router.push({
        name: 'contact_profile_dashboard',
        params: {
          accountId: this.$route.params.accountId,
          contactId: plan.contact.id,
        },
        query: { tab: 'assets' },
      });
    },
  },
};
</script>

<template>
  <ul
    class="p-0 m-0 list-none bg-white border divide-y rounded-lg dark:bg-slate-900 border-slate-75 dark:border-slate-700 divide-slate-50 dark:divide-slate-800"
  >
    <li
      v-for="plan in plans"
      :key="plan.id"
      class="flex flex-wrap items-center gap-3 px-3 py-2"
      :class="{ 'opacity-60': !plan.active }"
    >
      <div class="flex flex-col flex-1 min-w-0">
        <span
          class="text-sm font-medium truncate text-slate-800 dark:text-slate-100"
        >
          {{ plan.title }}
          <span v-if="plan.customer_asset" class="font-normal text-slate-500">
            · {{ plan.customer_asset.name }}
          </span>
        </span>
        <span class="text-xs truncate text-slate-500 dark:text-slate-400">
          <button
            v-if="showContact"
            type="button"
            class="text-woot-600 hover:underline"
            @click="openContact(plan)"
          >
            {{ plan.contact.name }}
          </button>
          <span v-if="showContact"> · </span>
          {{ frequency(plan) }}
          <span v-if="plan.case_type"> · {{ plan.case_type.name }}</span>
          <span v-if="plan.assignee"> · {{ plan.assignee.name }}</span>
          <span v-if="plan.open_orders">
            · {{ $t('MAINTENANCE.OPEN_ORDERS', { n: plan.open_orders }) }}
          </span>
        </span>
      </div>
      <span
        class="text-sm whitespace-nowrap"
        :class="
          overdue(plan) ? 'text-red-600' : 'text-slate-600 dark:text-slate-300'
        "
      >
        {{ $t('MAINTENANCE.NEXT', { date: dueLabel(plan) }) }}
      </span>
      <div class="flex gap-1">
        <woot-button
          size="tiny"
          variant="smooth"
          :title="$t('MAINTENANCE.GENERATE_HELP')"
          @click="generate(plan)"
        >
          {{ $t('MAINTENANCE.GENERATE') }}
        </woot-button>
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          icon="edit"
          @click="$emit('edit', plan)"
        />
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="alert"
          icon="delete"
          @click="remove(plan)"
        />
      </div>
    </li>
  </ul>
</template>
