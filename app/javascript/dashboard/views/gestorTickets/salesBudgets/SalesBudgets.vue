<!--
  Inicio › Presupuesto (presupuesto de ventas, etapa 1). Avance: meta contra lo
  logrado, para todos los de Ventas (con «solo lo suyo», lo propio). Captura por
  vendedor y por vendedor + cliente: solo Ventas en «Todo» (o administrador).
-->
<script>
import BudgetProgress from './BudgetProgress.vue';
import BudgetSellerGrid from './BudgetSellerGrid.vue';
import BudgetClientGrid from './BudgetClientGrid.vue';

const TABS = ['progress', 'sellers', 'clients'];

export default {
  name: 'SalesBudgets',
  components: { BudgetProgress, BudgetSellerGrid, BudgetClientGrid },
  data() {
    const tab = TABS.includes(this.$route.query.tab)
      ? this.$route.query.tab
      : 'progress';
    return {
      tab,
      currency: 'MXN',
      currencies: ['MXN'],
      canCapture: false,
      year: new Date().getFullYear(),
    };
  },
  computed: {
    tabs() {
      return this.canCapture ? TABS : ['progress'];
    },
    tabIndex() {
      return Math.max(0, this.tabs.indexOf(this.tab));
    },
    years() {
      const now = new Date().getFullYear();
      return [now - 1, now, now + 1];
    },
  },
  methods: {
    onLoaded(data) {
      this.canCapture = !!data.can_capture;
      this.currencies = data.currencies || ['MXN'];
      if (!this.canCapture) this.tab = 'progress';
    },
    onTabChange(index) {
      this.tab = this.tabs[index];
      this.$router.replace({ query: { tab: this.tab } });
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <div
      class="flex flex-col flex-shrink-0 gap-3 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div class="flex flex-wrap items-center gap-3">
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('SALES_BUDGET.TITLE') }}
        </h1>
        <div class="flex items-center gap-2 ml-auto">
          <select
            v-if="tab !== 'progress'"
            v-model.number="year"
            class="!mb-0 text-sm w-28"
            :aria-label="$t('SALES_BUDGET.YEAR')"
          >
            <option v-for="y in years" :key="y" :value="y">{{ y }}</option>
          </select>
          <select
            v-model="currency"
            class="!mb-0 text-sm w-28"
            :aria-label="$t('SALES_BUDGET.CURRENCY')"
          >
            <option v-for="c in currencies" :key="c" :value="c">{{ c }}</option>
          </select>
        </div>
      </div>
      <woot-tabs v-if="tabs.length > 1" :index="tabIndex" @change="onTabChange">
        <woot-tabs-item
          v-for="(name, index) in tabs"
          :key="name"
          :index="index"
          :name="$t(`SALES_BUDGET.TABS.${name.toUpperCase()}`)"
          :show-badge="false"
        />
      </woot-tabs>
    </div>
    <div class="flex-1 px-6 py-4 overflow-y-auto">
      <BudgetProgress
        v-show="tab === 'progress'"
        :currency="currency"
        @loaded="onLoaded"
      />
      <BudgetSellerGrid
        v-if="tab === 'sellers'"
        :year="year"
        :currency="currency"
      />
      <BudgetClientGrid
        v-if="tab === 'clients'"
        :year="year"
        :currency="currency"
      />
    </div>
  </div>
</template>
