<!--
  Plan-Trabajo-Campo R4 — alta / edición de un mantenimiento recurrente: qué
  equipo, cada cuánto, la próxima fecha, con cuántos días de anticipación se
  genera la orden, el tipo de orden, el técnico y si se avisa al cliente.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import CaseTypesAPI from 'dashboard/api/caseTypes';
import CustomerAssetsAPI from 'dashboard/api/customerAssets';
import MaintenancePlansAPI from 'dashboard/api/maintenancePlans';

const FIELDS = {
  title: '',
  customer_asset_id: '',
  case_type_id: '',
  assignee_id: '',
  every: 3,
  unit: 'month',
  next_due_on: '',
  lead_days: 7,
  notify_customer: true,
  active: true,
  notes: '',
};

const idOf = value => (value && value.id) || '';

export default {
  name: 'MaintenancePlanForm',
  props: {
    contactId: { type: Number, required: true },
    plan: { type: Object, default: null },
    // Equipo elegido al abrir desde la tarjeta de un equipo.
    assetId: { type: Number, default: null },
  },
  emits: ['saved', 'close'],
  data() {
    const source = this.plan || {};
    const form = Object.fromEntries(
      Object.entries(FIELDS).map(([key, fallback]) => [
        key,
        source[key] ?? fallback,
      ])
    );
    form.customer_asset_id = idOf(source.customer_asset) || this.assetId || '';
    form.case_type_id = idOf(source.case_type);
    form.assignee_id = idOf(source.assignee);
    return { form, types: [], assets: [], saving: false };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents' }),
  },
  async mounted() {
    this.$store.dispatch('agents/get');
    try {
      const [types, assets] = await Promise.all([
        CaseTypesAPI.getAll(),
        CustomerAssetsAPI.forContact(this.contactId),
      ]);
      this.types = (types.data.case_types || []).filter(
        type => type.case_class === 'work_order'
      );
      this.assets = assets.data.customer_assets || [];
      if (!this.form.case_type_id && this.types.length) {
        this.form.case_type_id = this.types[0].id;
      }
    } catch {
      useAlert(this.$t('MAINTENANCE.ERROR'));
    }
  },
  methods: {
    async save() {
      this.saving = true;
      const payload = {
        ...this.form,
        customer_asset_id: this.form.customer_asset_id || null,
        assignee_id: this.form.assignee_id || null,
      };
      try {
        const { data } = this.plan
          ? await MaintenancePlansAPI.update(this.plan.id, payload)
          : await MaintenancePlansAPI.create({
              ...payload,
              contact_id: this.contactId,
            });
        this.$emit('saved', data.maintenance_plan);
      } catch (error) {
        useAlert(error?.response?.data?.error || this.$t('MAINTENANCE.ERROR'));
      } finally {
        this.saving = false;
      }
    },
  },
};
</script>

<template>
  <woot-modal show :on-close="() => $emit('close')" size="medium">
    <woot-modal-header
      :header-title="
        plan ? $t('MAINTENANCE.PLAN.EDIT') : $t('MAINTENANCE.PLAN.NEW')
      "
      :header-content="$t('MAINTENANCE.PLAN.HELP')"
    />
    <form class="flex flex-col w-full gap-1 px-8 pb-6" @submit.prevent="save">
      <label>
        {{ $t('MAINTENANCE.PLAN.TITLE') }}
        <input
          v-model="form.title"
          type="text"
          required
          :placeholder="$t('MAINTENANCE.PLAN.TITLE_PLACEHOLDER')"
        />
      </label>
      <div class="grid grid-cols-2 gap-3">
        <label>
          {{ $t('MAINTENANCE.PLAN.ASSET') }}
          <select v-model="form.customer_asset_id">
            <option value="">{{ $t('MAINTENANCE.PLAN.NO_ASSET') }}</option>
            <option v-for="a in assets" :key="a.id" :value="a.id">
              {{ a.name }}
            </option>
          </select>
        </label>
        <label>
          {{ $t('MAINTENANCE.PLAN.TYPE') }}
          <select v-model="form.case_type_id" required>
            <option v-for="t in types" :key="t.id" :value="t.id">
              {{ t.name }}
            </option>
          </select>
        </label>
      </div>
      <div class="grid grid-cols-3 gap-3">
        <label>
          {{ $t('MAINTENANCE.PLAN.EVERY') }}
          <input v-model.number="form.every" type="number" min="1" required />
        </label>
        <label>
          {{ $t('MAINTENANCE.PLAN.UNIT') }}
          <select v-model="form.unit">
            <option value="week">{{ $t('MAINTENANCE.UNITS.week') }}</option>
            <option value="month">{{ $t('MAINTENANCE.UNITS.month') }}</option>
          </select>
        </label>
        <label>
          {{ $t('MAINTENANCE.PLAN.NEXT_DUE') }}
          <input v-model="form.next_due_on" type="date" required />
        </label>
      </div>
      <div class="grid grid-cols-2 gap-3">
        <label>
          {{ $t('MAINTENANCE.PLAN.ASSIGNEE') }}
          <select v-model="form.assignee_id">
            <option value="">{{ $t('MAINTENANCE.PLAN.NO_ASSIGNEE') }}</option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.name }}
            </option>
          </select>
        </label>
        <label>
          {{ $t('MAINTENANCE.PLAN.LEAD_DAYS') }}
          <input v-model.number="form.lead_days" type="number" min="0" />
        </label>
      </div>
      <label class="flex items-center gap-2">
        <input v-model="form.notify_customer" type="checkbox" class="!m-0" />
        {{ $t('MAINTENANCE.PLAN.NOTIFY') }}
      </label>
      <label v-if="plan" class="flex items-center gap-2">
        <input v-model="form.active" type="checkbox" class="!m-0" />
        {{ $t('MAINTENANCE.PLAN.ACTIVE') }}
      </label>
      <label>
        {{ $t('MAINTENANCE.NOTES') }}
        <textarea v-model="form.notes" rows="2" />
      </label>
      <div class="flex justify-end gap-2 mt-2">
        <button type="button" class="button clear" @click="$emit('close')">
          {{ $t('MAINTENANCE.CANCEL') }}
        </button>
        <woot-submit-button
          :button-text="$t('MAINTENANCE.SAVE')"
          :loading="saving"
        />
      </div>
    </form>
  </woot-modal>
</template>
