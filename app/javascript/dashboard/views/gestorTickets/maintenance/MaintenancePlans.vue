<!--
  Plan-Trabajo-Campo R4 — Servicio › Mantenimientos: los mantenimientos
  recurrentes de todos los clientes, los próximos primero (vencidos en rojo).
  Se dan de alta desde la página del contacto › Equipos.
-->
<script>
import MaintenancePlansAPI from 'dashboard/api/maintenancePlans';
import Spinner from 'shared/components/Spinner.vue';
import MaintenancePlanForm from './MaintenancePlanForm.vue';
import PlanList from './PlanList.vue';

const WINDOWS = ['30', '90', 'all'];

export default {
  name: 'MaintenancePlans',
  components: { Spinner, MaintenancePlanForm, PlanList },
  data() {
    return {
      plans: [],
      loading: true,
      search: '',
      window: '30',
      includeInactive: false,
      editing: null,
      windows: WINDOWS,
    };
  },
  computed: {
    visible() {
      const term = this.search.trim().toLowerCase();
      const limit = new Date();
      limit.setDate(limit.getDate() + Number(this.window));
      const until = limit.toISOString().slice(0, 10);
      return this.plans.filter(plan => {
        if (this.window !== 'all' && plan.next_due_on > until) return false;
        if (!term) return true;
        return [plan.title, plan.contact.name, plan.customer_asset?.name]
          .filter(Boolean)
          .some(text => text.toLowerCase().includes(term));
      });
    },
  },
  watch: {
    includeInactive: 'fetch',
  },
  mounted() {
    this.fetch();
  },
  methods: {
    async fetch() {
      this.loading = true;
      try {
        const { data } = await MaintenancePlansAPI.list(
          this.includeInactive ? { active: 'all' } : {}
        );
        this.plans = data.maintenance_plans || [];
      } catch {
        this.plans = [];
      } finally {
        this.loading = false;
      }
    },
    onSaved() {
      this.editing = null;
      this.fetch();
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <header
      class="flex flex-wrap items-center justify-between gap-3 px-6 pt-5 pb-3"
    >
      <div>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('MAINTENANCE.TITLE') }}
        </h1>
        <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
          {{ $t('MAINTENANCE.HELP') }}
        </p>
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <input
          v-model="search"
          type="search"
          class="!mb-0 w-56"
          :placeholder="$t('MAINTENANCE.SEARCH')"
        />
        <select v-model="window" class="!mb-0 w-40">
          <option v-for="w in windows" :key="w" :value="w">
            {{ $t(`MAINTENANCE.WINDOW.${w.toUpperCase()}`) }}
          </option>
        </select>
        <label class="flex items-center gap-1 text-sm text-slate-600">
          <input v-model="includeInactive" type="checkbox" class="!m-0" />
          {{ $t('MAINTENANCE.INCLUDE_INACTIVE') }}
        </label>
      </div>
    </header>
    <div class="flex-1 px-6 pb-6 overflow-y-auto">
      <Spinner v-if="loading" />
      <p
        v-else-if="!visible.length"
        class="py-12 m-0 text-sm text-center text-slate-500 dark:text-slate-400"
      >
        {{ $t('MAINTENANCE.EMPTY') }}
      </p>
      <PlanList
        v-else
        :plans="visible"
        show-contact
        @edit="plan => (editing = plan)"
        @changed="fetch"
      />
    </div>
    <MaintenancePlanForm
      v-if="editing"
      :contact-id="editing.contact.id"
      :plan="editing"
      @saved="onSaved"
      @close="editing = null"
    />
  </div>
</template>
