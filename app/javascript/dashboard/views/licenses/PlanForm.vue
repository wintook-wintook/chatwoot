<script>
// feat/licencias (F2b) — CREAR / EDITAR UN PLAN, A PÁGINA COMPLETA
// ============================================================================
// Antes era un modal; ahora es una página de captura como el editor de plantillas de
// WhatsApp: «‹ Planes» y «Guardar» en el encabezado, al guardar regresa a la tabla y, si se
// sale con cambios sin guardar, lo pregunta (Index.vue, beforeRouteLeave → confirmLeave).
//
// Editar un plan solo vale para las licencias que se emitan después: las emitidas guardan
// su copia. Los canales y funciones se guardan en el plan, pero todavía no se aplican a la
// cuenta (decisión 23/10/2026, pregunta 14.1 del plan).
// ============================================================================
import { useAlert } from 'dashboard/composables';
import LicensesAPI from 'dashboard/api/licenses';
import BaseSettingsHeader from 'dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue';

export const LIST_ROUTE = 'licenses_plans';

// Un plan nuevo arranca con lo que el sistema enciende a toda cuenta nueva (defaultFeatures).
const formFor = (plan, defaultFeatures = []) => ({
  name: plan.name || '',
  duration_days: plan.duration_days || 30,
  default_max_agents: plan.default_max_agents || 5,
  license_type: plan.license_type || 'paid',
  signup_default: Boolean(plan.signup_default),
  active: plan.id ? Boolean(plan.active) : true,
  features: plan.id ? [...(plan.features || [])] : [...defaultFeatures],
});

export default {
  components: { BaseSettingsHeader },
  props: {
    // { id: null } = plan nuevo
    plan: { type: Object, required: true },
    availableFeatures: { type: Array, default: () => [] },
    defaultFeatures: { type: Array, default: () => [] },
  },
  emits: ['saved'],
  data() {
    const form = formFor(this.plan, this.defaultFeatures);
    return {
      saving: false,
      form,
      savedSnapshot: JSON.stringify(form),
    };
  },
  computed: {
    isNew() {
      return !this.plan.id;
    },
    channels() {
      return this.availableFeatures.filter(name => name.startsWith('channel_'));
    },
    functions() {
      return this.availableFeatures.filter(
        name => !name.startsWith('channel_')
      );
    },
    featureGroups() {
      return [
        { key: 'CHANNELS', items: this.channels },
        { key: 'FUNCTIONS', items: this.functions },
      ];
    },
    canSave() {
      return Boolean(
        this.form.name.trim() &&
          this.form.duration_days > 0 &&
          this.form.default_max_agents > 0 &&
          !this.saving
      );
    },
    hasUnsavedChanges() {
      return JSON.stringify(this.form) !== this.savedSnapshot;
    },
  },
  methods: {
    t(key, args) {
      return this.$t(`LICENSES.${key}`, args);
    },
    // channel_whatsapp → whatsapp; case_management → case management
    featureLabel(name) {
      return name.replace(/^channel_/, '').replace(/_/g, ' ');
    },
    goToList() {
      this.$router.push({ name: LIST_ROUTE });
    },
    // Para Index.vue (beforeRouteLeave): true si se puede salir.
    async confirmLeave() {
      if (!this.hasUnsavedChanges) return true;
      return this.$refs.leaveDialog.showConfirmation();
    },
    async save() {
      if (!this.canSave) return;
      this.saving = true;
      const payload = { ...this.form, name: this.form.name.trim() };
      try {
        if (this.isNew) await LicensesAPI.createPlan(payload);
        else await LicensesAPI.updatePlan(this.plan.id, payload);
        useAlert(this.t('PLAN_FORM.SAVED'));
        this.savedSnapshot = JSON.stringify(this.form);
        this.$emit('saved');
        this.goToList();
      } catch (error) {
        useAlert(this.t('PLAN_FORM.ERROR'));
      } finally {
        this.saving = false;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0">
    <div class="shrink-0">
      <BaseSettingsHeader
        :title="isNew ? t('PLAN_FORM.NEW_TITLE') : t('PLAN_FORM.EDIT_TITLE')"
        :description="t('PLAN_FORM.DESC')"
      >
        <template #actions>
          <!-- Como en el editor de plantillas: el regreso hace lo mismo que «Cancelar». -->
          <woot-button variant="clear" icon="chevron-left" @click="goToList">
            {{ t('TABS.PLANS') }}
          </woot-button>
          <woot-button
            :is-disabled="!canSave"
            :is-loading="saving"
            @click="save"
          >
            {{ t('PLAN_FORM.SAVE') }}
          </woot-button>
        </template>
      </BaseSettingsHeader>
    </div>

    <form
      class="flex-1 min-h-0 pr-2 mt-6 overflow-y-auto"
      @submit.prevent="save"
    >
      <section class="plan-section">
        <h3 class="plan-section__title">{{ t('PLAN_FORM.DATA') }}</h3>
        <label class="block">
          {{ t('PLAN_FORM.NAME') }}
          <input v-model="form.name" type="text" maxlength="120" />
        </label>
        <div class="grid grid-cols-1 gap-4 md:grid-cols-3">
          <label>
            {{ t('PLAN_FORM.DAYS') }}
            <input v-model.number="form.duration_days" type="number" min="1" />
          </label>
          <label>
            {{ t('PLAN_FORM.AGENTS') }}
            <input
              v-model.number="form.default_max_agents"
              type="number"
              min="1"
            />
          </label>
          <label>
            {{ t('PLAN_FORM.TYPE') }}
            <select v-model="form.license_type">
              <option value="demo">{{ t('TYPE.DEMO') }}</option>
              <option value="paid">{{ t('TYPE.PAID') }}</option>
            </select>
          </label>
        </div>
        <label class="flex items-center gap-2 !mb-2">
          <input v-model="form.signup_default" type="checkbox" class="!mb-0" />
          {{ t('PLAN_FORM.SIGNUP') }}
        </label>
        <label class="flex items-center gap-2 !mb-0">
          <input v-model="form.active" type="checkbox" class="!mb-0" />
          {{ t('PLAN_FORM.ACTIVE') }}
        </label>
      </section>

      <section
        v-for="group in featureGroups"
        :key="group.key"
        class="plan-section"
      >
        <h3 class="plan-section__title">{{ t(`PLAN_FORM.${group.key}`) }}</h3>
        <p class="mb-3 text-xs text-slate-500 dark:text-slate-400">
          {{ t('PLAN_FORM.FEATURES_HINT') }}
          <template v-if="isNew">{{ t('PLAN_FORM.DEFAULTS_HINT') }}</template>
        </p>
        <div class="grid grid-cols-2 gap-x-4 gap-y-2 md:grid-cols-4">
          <label
            v-for="name in group.items"
            :key="name"
            class="flex items-center gap-2 !mb-0 text-sm capitalize"
          >
            <input
              v-model="form.features"
              type="checkbox"
              class="!mb-0"
              :value="name"
            />
            {{ featureLabel(name) }}
          </label>
        </div>
      </section>
    </form>

    <woot-confirm-modal
      ref="leaveDialog"
      :title="t('PLAN_FORM.LEAVE.TITLE')"
      :description="t('PLAN_FORM.LEAVE.DESCRIPTION')"
      :confirm-label="t('PLAN_FORM.LEAVE.CONFIRM')"
      :cancel-label="t('PLAN_FORM.LEAVE.CANCEL')"
    />
  </div>
</template>

<style scoped lang="scss">
.plan-section {
  @apply p-4 mb-4 border border-solid rounded-lg bg-white dark:bg-slate-800 border-slate-100 dark:border-slate-700;
}

.plan-section__title {
  @apply mb-3 text-sm font-semibold text-slate-700 dark:text-slate-200;
}
</style>
