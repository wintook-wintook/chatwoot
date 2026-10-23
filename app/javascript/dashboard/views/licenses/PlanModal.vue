<script>
// feat/licencias (F2b) — CREAR / EDITAR UN PLAN
// ============================================================================
// Editar un plan solo vale para las licencias que se emitan después: las emitidas guardan
// su copia. Los canales y funciones se guardan en el plan, pero todavía no se aplican a la
// cuenta (decisión 23/10/2026, pregunta 14.1 del plan).
// ============================================================================
import { useAlert } from 'dashboard/composables';
import Modal from 'dashboard/components/Modal.vue';
import LicensesAPI from 'dashboard/api/licenses';

export default {
  components: { Modal },
  props: {
    // { id: null } = plan nuevo
    plan: { type: Object, required: true },
    availableFeatures: { type: Array, default: () => [] },
  },
  emits: ['close', 'saved'],
  data() {
    return {
      show: true,
      saving: false,
      form: {
        name: this.plan.name || '',
        duration_days: this.plan.duration_days || 30,
        default_max_agents: this.plan.default_max_agents || 5,
        license_type: this.plan.license_type || 'paid',
        signup_default: Boolean(this.plan.signup_default),
        active: this.plan.id ? Boolean(this.plan.active) : true,
        features: [...(this.plan.features || [])],
      },
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
    canSave() {
      return (
        this.form.name.trim() &&
        this.form.duration_days > 0 &&
        this.form.default_max_agents > 0 &&
        !this.saving
      );
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
    close() {
      this.$emit('close');
    },
    async save() {
      if (!this.canSave) return;
      this.saving = true;
      const payload = { ...this.form, name: this.form.name.trim() };
      try {
        if (this.isNew) await LicensesAPI.createPlan(payload);
        else await LicensesAPI.updatePlan(this.plan.id, payload);
        useAlert(this.t('PLAN_FORM.SAVED'));
        this.$emit('saved');
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
  <Modal :show.sync="show" :on-close="close" size="medium">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="
          isNew ? t('PLAN_FORM.NEW_TITLE') : t('PLAN_FORM.EDIT_TITLE')
        "
        :header-content="t('PLAN_FORM.DESC')"
      />
      <form class="flex flex-col gap-3 px-8 pb-6" @submit.prevent="save">
        <label>
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
        <label class="flex items-center gap-2">
          <input v-model="form.signup_default" type="checkbox" class="!mb-0" />
          {{ t('PLAN_FORM.SIGNUP') }}
        </label>
        <label class="flex items-center gap-2">
          <input v-model="form.active" type="checkbox" class="!mb-0" />
          {{ t('PLAN_FORM.ACTIVE') }}
        </label>

        <p class="mb-0 text-xs text-slate-500 dark:text-slate-400">
          {{ t('PLAN_FORM.FEATURES_HINT') }}
        </p>
        <div
          v-for="group in [
            { key: 'CHANNELS', items: channels },
            { key: 'FUNCTIONS', items: functions },
          ]"
          :key="group.key"
        >
          <h4
            class="mb-2 text-sm font-semibold text-slate-700 dark:text-slate-200"
          >
            {{ t(`PLAN_FORM.${group.key}`) }}
          </h4>
          <div class="grid grid-cols-2 gap-x-4 gap-y-1 md:grid-cols-3">
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
        </div>

        <div class="flex justify-end gap-2 mt-2">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            @click.prevent="close"
          >
            {{ t('PLAN_FORM.CANCEL') }}
          </woot-button>
          <woot-button :is-disabled="!canSave" :is-loading="saving">
            {{ t('PLAN_FORM.SAVE') }}
          </woot-button>
        </div>
      </form>
    </div>
  </Modal>
</template>
