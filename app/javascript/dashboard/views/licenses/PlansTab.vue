<script>
// feat/licencias (F2b) — PESTAÑA «PLANES»
// ============================================================================
// El catálogo. Crear y editar solo con «Gestionar licencias»; no se borran, se desactivan.
// Uno es el de registro: la demo que recibe toda cuenta nueva.
// ============================================================================
import PlanModal from './PlanModal.vue';

export default {
  components: { PlanModal },
  props: {
    plans: { type: Array, default: () => [] },
    availableFeatures: { type: Array, default: () => [] },
    canManage: { type: Boolean, default: false },
  },
  emits: ['changed'],
  data() {
    return { editing: null };
  },
  methods: {
    t(key, args) {
      return this.$t(`LICENSES.${key}`, args);
    },
    openNew() {
      this.editing = { id: null };
    },
    onSaved() {
      this.editing = null;
      this.$emit('changed');
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0">
    <div v-if="canManage" class="flex justify-end mb-4 shrink-0">
      <woot-button
        class="rounded-md button nice"
        icon="add-circle"
        @click="openNew"
      >
        {{ t('PLANS.NEW') }}
      </woot-button>
    </div>

    <div class="flex-1 min-h-0 overflow-auto">
      <table class="min-w-full overflow-x-auto text-sm">
        <thead>
          <th
            v-for="col in [
              'NAME',
              'DAYS',
              'AGENTS',
              'TYPE',
              'FEATURES',
              'ACCOUNTS',
            ]"
            :key="col"
            class="py-4 pr-4 font-semibold text-left whitespace-nowrap text-slate-700 dark:text-slate-300"
          >
            {{ t(`PLANS.TABLE.${col}`) }}
          </th>
          <th v-if="canManage" />
        </thead>
        <tbody
          class="divide-y divide-slate-50 dark:divide-slate-800 text-slate-700 dark:text-slate-300"
        >
          <tr v-for="plan in plans" :key="plan.id">
            <td class="py-3 pr-4">
              <span class="font-medium">{{ plan.name }}</span>
              <woot-label
                v-if="plan.signup_default"
                small
                color-scheme="primary"
                class="!mb-0 ltr:ml-2 rtl:mr-2"
                :title="t('PLANS.SIGNUP')"
              />
              <woot-label
                v-if="!plan.active"
                small
                color-scheme="secondary"
                class="!mb-0 ltr:ml-2 rtl:mr-2"
                :title="t('PLANS.INACTIVE')"
              />
            </td>
            <td class="py-3 pr-4">{{ plan.duration_days }}</td>
            <td class="py-3 pr-4">{{ plan.default_max_agents }}</td>
            <td class="py-3 pr-4">
              {{ t(`TYPE.${plan.license_type.toUpperCase()}`) }}
            </td>
            <td class="py-3 pr-4">
              {{ t('PLANS.FEATURES_COUNT', { count: plan.features.length }) }}
            </td>
            <td class="py-3 pr-4">{{ plan.accounts_count }}</td>
            <td v-if="canManage" class="py-3 pr-4">
              <woot-button
                size="small"
                variant="smooth"
                color-scheme="secondary"
                icon="edit"
                @click="editing = plan"
              >
                {{ t('PLANS.EDIT') }}
              </woot-button>
            </td>
          </tr>
        </tbody>
      </table>
      <p
        v-if="!plans.length"
        class="py-6 text-sm text-slate-500 dark:text-slate-400"
      >
        {{ t('PLANS.EMPTY') }}
      </p>
    </div>

    <PlanModal
      v-if="editing"
      :plan="editing"
      :available-features="availableFeatures"
      @close="editing = null"
      @saved="onSaved"
    />
  </div>
</template>
