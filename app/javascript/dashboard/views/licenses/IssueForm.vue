<script>
// feat/licencias (F2b) — ASIGNAR UNA LICENCIA A UNA CUENTA, A PÁGINA COMPLETA
// ============================================================================
// Antes era un modal; ahora es una página como la captura de planes: «‹ <cuenta>» y «Asignar»
// en el encabezado; al asignar regresa a la ficha de la cuenta (pestaña Licencias) y, si se
// sale con cambios sin asignar, lo pregunta (Index.vue, guardas de ruta → confirmLeave).
//
// Se elige un plan activo y se precargan su nombre, agentes y días; se pueden ajustar solo
// para esta cuenta. «Ya» reemplaza la licencia actual (y reactiva la cuenta si estaba
// suspendida); «En cola» empieza cuando termine la actual. Lo resuelve Licenses::Issuer.
// ============================================================================
import { useAlert } from 'dashboard/composables';
import LicensesAPI from 'dashboard/api/licenses';
import BaseSettingsHeader from 'dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue';

const emptyForm = hasCurrent => ({
  license_plan_id: '',
  start: hasCurrent ? 'queue' : 'now',
  name: '',
  max_agents: null,
  duration_days: null,
  notes: '',
});

export default {
  components: { BaseSettingsHeader },
  props: {
    licensedAccountId: { type: Number, required: true },
    plans: { type: Array, default: () => [] },
  },
  emits: ['issued'],
  data() {
    return {
      account: null,
      loading: true,
      notFound: false,
      saving: false,
      done: false,
      form: emptyForm(false),
      savedSnapshot: JSON.stringify(emptyForm(false)),
    };
  },
  computed: {
    activePlans() {
      return this.plans.filter(plan => plan.active);
    },
    hasCurrent() {
      return Boolean(this.account && this.account.license);
    },
    canSubmit() {
      return Boolean(
        this.form.license_plan_id &&
          this.form.max_agents > 0 &&
          this.form.duration_days > 0 &&
          !this.saving
      );
    },
    hasUnsavedChanges() {
      return !this.done && JSON.stringify(this.form) !== this.savedSnapshot;
    },
  },
  watch: {
    // Cambiar de plan vuelve a precargar sus valores.
    'form.license_plan_id'(id) {
      const plan = this.plans.find(item => item.id === Number(id));
      if (!plan) return;
      this.form.name = plan.name;
      this.form.max_agents = plan.default_max_agents;
      this.form.duration_days = plan.duration_days;
    },
  },
  mounted() {
    this.fetch();
  },
  methods: {
    t(key, args) {
      return this.$t(`LICENSES.${key}`, args);
    },
    async fetch() {
      this.loading = true;
      try {
        const { data } = await LicensesAPI.getAccount(this.licensedAccountId);
        this.account = data;
        this.form = emptyForm(Boolean(data.license));
        this.savedSnapshot = JSON.stringify(this.form);
      } catch (error) {
        this.notFound = true;
      } finally {
        this.loading = false;
      }
    },
    goBack(tab) {
      this.$router.push({
        name: 'licenses_accounts_show',
        params: { licensedAccountId: this.licensedAccountId },
        query: tab ? { tab } : {},
      });
    },
    // Para Index.vue (guardas de ruta): true si se puede salir.
    async confirmLeave() {
      if (!this.hasUnsavedChanges) return true;
      return this.$refs.leaveDialog.showConfirmation();
    },
    async submit() {
      if (!this.canSubmit) return;
      this.saving = true;
      try {
        await LicensesAPI.issue({
          target_account_id: this.licensedAccountId,
          license_plan_id: Number(this.form.license_plan_id),
          start: this.form.start,
          name: this.form.name.trim(),
          max_agents: this.form.max_agents,
          duration_days: this.form.duration_days,
          notes: this.form.notes.trim(),
        });
        useAlert(this.t('ISSUE.DONE'));
        this.done = true;
        this.$emit('issued');
        this.goBack('licenses');
      } catch (error) {
        const data = error && error.response && error.response.data;
        useAlert((data && data.message) || this.t('ISSUE.ERROR'));
      } finally {
        this.saving = false;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0">
    <p v-if="loading" class="text-sm text-slate-500">
      {{ t('DETAIL.LOADING') }}
    </p>
    <p v-else-if="notFound" class="text-sm text-slate-600 dark:text-slate-300">
      {{ t('DETAIL.NOT_FOUND') }}
    </p>
    <template v-else>
      <div class="shrink-0">
        <BaseSettingsHeader
          :title="t('ISSUE.TITLE', { name: account.name })"
          :description="t('ISSUE.DESC')"
        >
          <template #actions>
            <woot-button variant="clear" icon="chevron-left" @click="goBack()">
              {{ account.name }}
            </woot-button>
            <woot-button
              :is-disabled="!canSubmit"
              :is-loading="saving"
              @click="submit"
            >
              {{ t('ISSUE.SUBMIT') }}
            </woot-button>
          </template>
        </BaseSettingsHeader>
      </div>

      <form
        class="flex-1 min-h-0 pr-2 mt-6 overflow-y-auto"
        @submit.prevent="submit"
      >
        <section class="issue-section">
          <h3 class="issue-section__title">{{ t('ISSUE.SECTION_PLAN') }}</h3>
          <label class="block">
            {{ t('ISSUE.PLAN') }}
            <select v-model="form.license_plan_id">
              <option value="" disabled>{{ t('ISSUE.CHOOSE_PLAN') }}</option>
              <option
                v-for="plan in activePlans"
                :key="plan.id"
                :value="plan.id"
              >
                {{ plan.name }}
              </option>
            </select>
          </label>
          <fieldset v-if="hasCurrent" class="flex flex-col gap-1">
            <legend class="mb-1 text-sm">{{ t('ISSUE.START') }}</legend>
            <label class="flex items-center gap-2 !mb-0 text-sm">
              <input
                v-model="form.start"
                type="radio"
                value="queue"
                class="!mb-0"
              />
              {{ t('ISSUE.START_QUEUE') }}
            </label>
            <label class="flex items-center gap-2 !mb-0 text-sm">
              <input
                v-model="form.start"
                type="radio"
                value="now"
                class="!mb-0"
              />
              {{ t('ISSUE.START_NOW') }}
            </label>
          </fieldset>
        </section>

        <section v-if="form.license_plan_id" class="issue-section">
          <h3 class="issue-section__title">
            {{ t('ISSUE.SECTION_VALUES') }}
          </h3>
          <label class="block">
            {{ t('ISSUE.NAME') }}
            <input v-model="form.name" type="text" maxlength="120" />
          </label>
          <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
            <label>
              {{ t('ISSUE.AGENTS') }}
              <input v-model.number="form.max_agents" type="number" min="1" />
            </label>
            <label>
              {{ t('ISSUE.DAYS') }}
              <input
                v-model.number="form.duration_days"
                type="number"
                min="1"
              />
            </label>
          </div>
          <label class="block !mb-0">
            {{ t('ISSUE.NOTES') }}
            <textarea v-model="form.notes" rows="3" class="!mb-0" />
          </label>
        </section>
      </form>
    </template>

    <woot-confirm-modal
      ref="leaveDialog"
      :title="t('PLAN_FORM.LEAVE.TITLE')"
      :description="t('ISSUE.LEAVE_DESCRIPTION')"
      :confirm-label="t('PLAN_FORM.LEAVE.CONFIRM')"
      :cancel-label="t('PLAN_FORM.LEAVE.CANCEL')"
    />
  </div>
</template>

<style scoped lang="scss">
.issue-section {
  @apply p-4 mb-4 border border-solid rounded-lg bg-white dark:bg-slate-800 border-slate-100 dark:border-slate-700;
}

.issue-section__title {
  @apply mb-3 text-sm font-semibold text-slate-700 dark:text-slate-200;
}
</style>
