<script>
// feat/licencias (F2b) — ASIGNAR UNA LICENCIA A UNA CUENTA
// ============================================================================
// Se elige un plan activo y se precargan su nombre, agentes y días; se pueden ajustar solo
// para esta cuenta. «Ya» reemplaza la licencia actual (y reactiva la cuenta si estaba
// suspendida); «En cola» empieza cuando termine la actual. Lo resuelve Licenses::Issuer.
// ============================================================================
import { useAlert } from 'dashboard/composables';
import Modal from 'dashboard/components/Modal.vue';
import LicensesAPI from 'dashboard/api/licenses';

export default {
  components: { Modal },
  props: {
    account: { type: Object, required: true },
    plans: { type: Array, default: () => [] },
  },
  emits: ['close', 'issued'],
  data() {
    return {
      show: true,
      saving: false,
      form: {
        license_plan_id: '',
        start: this.account.license ? 'queue' : 'now',
        name: '',
        max_agents: null,
        duration_days: null,
        notes: '',
      },
    };
  },
  computed: {
    activePlans() {
      return this.plans.filter(plan => plan.active);
    },
    hasCurrent() {
      return Boolean(this.account.license);
    },
    canSubmit() {
      return (
        this.form.license_plan_id &&
        this.form.max_agents > 0 &&
        this.form.duration_days > 0 &&
        !this.saving
      );
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
  methods: {
    t(key, args) {
      return this.$t(`LICENSES.${key}`, args);
    },
    close() {
      this.$emit('close');
    },
    async submit() {
      if (!this.canSubmit) return;
      this.saving = true;
      try {
        await LicensesAPI.issue({
          target_account_id: this.account.id,
          license_plan_id: Number(this.form.license_plan_id),
          start: this.form.start,
          name: this.form.name.trim(),
          max_agents: this.form.max_agents,
          duration_days: this.form.duration_days,
          notes: this.form.notes.trim(),
        });
        useAlert(this.t('ISSUE.DONE'));
        this.$emit('issued');
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
  <Modal :show.sync="show" :on-close="close">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="t('ISSUE.TITLE', { name: account.name })"
        :header-content="t('ISSUE.DESC')"
      />
      <form class="flex flex-col gap-3 px-8 pb-6" @submit.prevent="submit">
        <label>
          {{ t('ISSUE.PLAN') }}
          <select v-model="form.license_plan_id">
            <option value="" disabled>{{ t('ISSUE.CHOOSE_PLAN') }}</option>
            <option v-for="plan in activePlans" :key="plan.id" :value="plan.id">
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

        <template v-if="form.license_plan_id">
          <label>
            {{ t('ISSUE.NAME') }}
            <input v-model="form.name" type="text" maxlength="120" />
          </label>
          <div class="grid grid-cols-2 gap-4">
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
          <label>
            {{ t('ISSUE.NOTES') }}
            <textarea v-model="form.notes" rows="2" />
          </label>
        </template>

        <div class="flex justify-end gap-2 mt-2">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            @click.prevent="close"
          >
            {{ t('ISSUE.CANCEL') }}
          </woot-button>
          <woot-button :is-disabled="!canSubmit" :is-loading="saving">
            {{ t('ISSUE.SUBMIT') }}
          </woot-button>
        </div>
      </form>
    </div>
  </Modal>
</template>
