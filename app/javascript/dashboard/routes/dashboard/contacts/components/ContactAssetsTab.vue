<!--
  Plan-Trabajo-Campo R4 — Página del contacto › Equipos: sus equipos (marca,
  modelo, serie, ubicación, garantía) con el historial de órdenes de cada uno, y
  sus mantenimientos recurrentes (generan la orden solos y avisan al cliente).
-->
<script>
import CustomerAssetsAPI from 'dashboard/api/customerAssets';
import MaintenancePlansAPI from 'dashboard/api/maintenancePlans';
import Spinner from 'shared/components/Spinner.vue';
import AssetForm from 'dashboard/views/gestorTickets/maintenance/AssetForm.vue';
import MaintenancePlanForm from 'dashboard/views/gestorTickets/maintenance/MaintenancePlanForm.vue';
import PlanList from 'dashboard/views/gestorTickets/maintenance/PlanList.vue';
import { backQuery } from 'dashboard/views/gestorTickets/backLink';

export default {
  name: 'ContactAssetsTab',
  components: { Spinner, AssetForm, MaintenancePlanForm, PlanList },
  props: {
    contactId: { type: Number, required: true },
  },
  data() {
    return {
      assets: [],
      plans: [],
      loading: true,
      showRetired: false,
      // { asset } — null es alta.
      assetForm: null,
      planForm: null,
      openHistory: null,
      history: [],
    };
  },
  watch: {
    contactId: 'fetch',
    showRetired: 'fetch',
  },
  mounted() {
    this.fetch();
  },
  methods: {
    async fetch() {
      this.loading = true;
      try {
        const [assets, plans] = await Promise.all([
          CustomerAssetsAPI.forContact(this.contactId, this.showRetired),
          MaintenancePlansAPI.list({
            contact_id: this.contactId,
            active: 'all',
          }),
        ]);
        this.assets = assets.data.customer_assets || [];
        this.plans = plans.data.maintenance_plans || [];
      } catch {
        this.assets = [];
        this.plans = [];
      } finally {
        this.loading = false;
      }
    },
    detail(asset) {
      return [asset.brand, asset.model, asset.serial && `#${asset.serial}`]
        .filter(Boolean)
        .join(' · ');
    },
    plansOf(asset) {
      return this.plans.filter(
        p => p.customer_asset && p.customer_asset.id === asset.id
      ).length;
    },
    async toggleHistory(asset) {
      if (this.openHistory === asset.id) {
        this.openHistory = null;
        return;
      }
      this.openHistory = asset.id;
      this.history = [];
      try {
        const { data } = await CustomerAssetsAPI.history(asset.id);
        this.history = data.customer_asset.history || [];
      } catch {
        this.history = [];
      }
    },
    date(value) {
      return value
        ? new Date(value).toLocaleDateString(undefined, {
            day: 'numeric',
            month: 'short',
            year: 'numeric',
          })
        : '';
    },
    openOrder(order) {
      this.$router.push({
        name: 'gestorTickets_detail',
        params: { accountId: this.$route.params.accountId, id: order.id },
        query: backQuery(this.$route),
      });
    },
    onAssetSaved() {
      this.assetForm = null;
      this.fetch();
    },
    onPlanSaved() {
      this.planForm = null;
      this.fetch();
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-6">
    <Spinner v-if="loading" />
    <template v-else>
      <!-- Equipos -->
      <section class="flex flex-col gap-2">
        <header class="flex items-center justify-between gap-2">
          <h3
            class="m-0 text-sm font-semibold text-slate-700 dark:text-slate-200"
          >
            {{ $t('MAINTENANCE.ASSETS_TITLE') }}
          </h3>
          <div class="flex items-center gap-3">
            <label class="flex items-center gap-1 text-xs text-slate-500">
              <input v-model="showRetired" type="checkbox" class="!m-0" />
              {{ $t('MAINTENANCE.ASSET.SHOW_RETIRED') }}
            </label>
            <woot-button
              size="small"
              icon="add"
              @click="assetForm = { asset: null }"
            >
              {{ $t('MAINTENANCE.ASSET.NEW') }}
            </woot-button>
          </div>
        </header>
        <p
          v-if="!assets.length"
          class="py-6 m-0 text-sm text-center text-slate-500 dark:text-slate-400"
        >
          {{ $t('MAINTENANCE.ASSET.EMPTY') }}
        </p>
        <ul
          v-else
          class="p-0 m-0 list-none bg-white border divide-y rounded-lg dark:bg-slate-900 border-slate-75 dark:border-slate-700 divide-slate-50 dark:divide-slate-800"
        >
          <li v-for="asset in assets" :key="asset.id" class="px-3 py-2">
            <div
              class="flex flex-wrap items-center gap-3"
              :class="{ 'opacity-60': !asset.active }"
            >
              <fluent-icon icon="settings" size="16" class="text-slate-500" />
              <div class="flex flex-col flex-1 min-w-0">
                <span
                  class="text-sm font-medium truncate text-slate-800 dark:text-slate-100"
                >
                  {{ asset.name }}
                  <span
                    v-if="asset.under_warranty"
                    class="px-1.5 ml-1 text-xs font-normal text-green-700 bg-green-50 rounded dark:bg-green-900/30 dark:text-green-300"
                  >
                    {{ $t('MAINTENANCE.ASSET.WARRANTY') }}
                  </span>
                  <span
                    v-if="!asset.active"
                    class="text-xs font-normal text-slate-500"
                  >
                    · {{ $t('MAINTENANCE.ASSET.RETIRED') }}
                  </span>
                </span>
                <span
                  class="text-xs truncate text-slate-500 dark:text-slate-400"
                >
                  {{ detail(asset) }}
                  <span v-if="asset.location"> · {{ asset.location }}</span>
                </span>
              </div>
              <button
                type="button"
                class="text-xs text-woot-600 hover:underline"
                @click="toggleHistory(asset)"
              >
                {{ $t('MAINTENANCE.ASSET.HISTORY', { n: asset.orders_count }) }}
              </button>
              <span v-if="plansOf(asset)" class="text-xs text-slate-500">
                {{ $t('MAINTENANCE.ASSET.PLANS', { n: plansOf(asset) }) }}
              </span>
              <div class="flex gap-1">
                <woot-button
                  size="tiny"
                  variant="smooth"
                  @click="planForm = { plan: null, assetId: asset.id }"
                >
                  {{ $t('MAINTENANCE.PLAN.NEW') }}
                </woot-button>
                <woot-button
                  size="tiny"
                  variant="clear"
                  color-scheme="secondary"
                  icon="edit"
                  @click="assetForm = { asset }"
                />
              </div>
            </div>
            <!-- Historial de órdenes del equipo -->
            <ul
              v-if="openHistory === asset.id"
              class="p-0 mt-2 mb-0 ml-7 list-none border-l border-slate-75 dark:border-slate-700"
            >
              <li
                v-if="!history.length"
                class="px-3 py-1 text-xs text-slate-500"
              >
                {{ $t('MAINTENANCE.ASSET.NO_HISTORY') }}
              </li>
              <li
                v-for="order in history"
                :key="order.id"
                class="flex items-center gap-2 px-3 py-1 text-xs cursor-pointer hover:bg-slate-25 dark:hover:bg-slate-800"
                @click="openOrder(order)"
              >
                <span class="font-medium text-slate-700 dark:text-slate-200">{{
                  order.folio
                }}</span>
                <span
                  class="flex-1 truncate text-slate-600 dark:text-slate-300"
                  >{{ order.title }}</span
                >
                <span v-if="order.assignee" class="text-slate-500">{{
                  order.assignee
                }}</span>
                <span class="text-slate-500">{{
                  date(order.resolved_at || order.created_at)
                }}</span>
              </li>
            </ul>
          </li>
        </ul>
      </section>

      <!-- Mantenimientos -->
      <section class="flex flex-col gap-2">
        <header class="flex items-center justify-between gap-2">
          <div>
            <h3
              class="m-0 text-sm font-semibold text-slate-700 dark:text-slate-200"
            >
              {{ $t('MAINTENANCE.PLANS_TITLE') }}
            </h3>
            <p class="m-0 text-xs text-slate-500">
              {{ $t('MAINTENANCE.PLAN.HELP') }}
            </p>
          </div>
          <woot-button
            size="small"
            icon="add"
            @click="planForm = { plan: null, assetId: null }"
          >
            {{ $t('MAINTENANCE.PLAN.NEW') }}
          </woot-button>
        </header>
        <p
          v-if="!plans.length"
          class="py-6 m-0 text-sm text-center text-slate-500 dark:text-slate-400"
        >
          {{ $t('MAINTENANCE.PLAN.EMPTY') }}
        </p>
        <PlanList
          v-else
          :plans="plans"
          @edit="plan => (planForm = { plan, assetId: null })"
          @changed="fetch"
        />
      </section>
    </template>

    <AssetForm
      v-if="assetForm"
      :contact-id="contactId"
      :asset="assetForm.asset"
      @saved="onAssetSaved"
      @close="assetForm = null"
    />
    <MaintenancePlanForm
      v-if="planForm"
      :contact-id="contactId"
      :plan="planForm.plan"
      :asset-id="planForm.assetId"
      @saved="onPlanSaved"
      @close="planForm = null"
    />
  </div>
</template>
