<!--
  Plan-Trabajo-Campo R4 — alta / edición de un equipo del cliente (marca,
  modelo, serie, ubicación, instalación y garantía).
-->
<script>
import { useAlert } from 'dashboard/composables';
import CustomerAssetsAPI from 'dashboard/api/customerAssets';

const FIELDS = [
  'name',
  'brand',
  'model',
  'serial',
  'location',
  'installed_on',
  'warranty_until',
  'notes',
];

export default {
  name: 'AssetForm',
  props: {
    contactId: { type: Number, required: true },
    asset: { type: Object, default: null },
  },
  emits: ['saved', 'close'],
  data() {
    const source = this.asset || {};
    return {
      form: Object.fromEntries(FIELDS.map(key => [key, source[key] || ''])),
      saving: false,
    };
  },
  methods: {
    async save() {
      this.saving = true;
      try {
        const { data } = this.asset
          ? await CustomerAssetsAPI.update(this.asset.id, this.form)
          : await CustomerAssetsAPI.create({
              ...this.form,
              contact_id: this.contactId,
            });
        this.$emit('saved', data.customer_asset);
      } catch (error) {
        useAlert(error?.response?.data?.error || this.$t('MAINTENANCE.ERROR'));
      } finally {
        this.saving = false;
      }
    },
    async retire() {
      try {
        const { data } = await CustomerAssetsAPI.update(this.asset.id, {
          active: false,
        });
        this.$emit('saved', data.customer_asset);
      } catch (error) {
        useAlert(error?.response?.data?.error || this.$t('MAINTENANCE.ERROR'));
      }
    },
  },
};
</script>

<template>
  <woot-modal show :on-close="() => $emit('close')" size="medium">
    <woot-modal-header
      :header-title="
        asset ? $t('MAINTENANCE.ASSET.EDIT') : $t('MAINTENANCE.ASSET.NEW')
      "
    />
    <form class="flex flex-col w-full gap-1 px-8 pb-6" @submit.prevent="save">
      <label>
        {{ $t('MAINTENANCE.ASSET.NAME') }}
        <input
          v-model="form.name"
          type="text"
          required
          :placeholder="$t('MAINTENANCE.ASSET.NAME_PLACEHOLDER')"
        />
      </label>
      <div class="grid grid-cols-3 gap-3">
        <label>
          {{ $t('MAINTENANCE.ASSET.BRAND') }}
          <input v-model="form.brand" type="text" />
        </label>
        <label>
          {{ $t('MAINTENANCE.ASSET.MODEL') }}
          <input v-model="form.model" type="text" />
        </label>
        <label>
          {{ $t('MAINTENANCE.ASSET.SERIAL') }}
          <input v-model="form.serial" type="text" />
        </label>
      </div>
      <label>
        {{ $t('MAINTENANCE.ASSET.LOCATION') }}
        <input
          v-model="form.location"
          type="text"
          :placeholder="$t('MAINTENANCE.ASSET.LOCATION_PLACEHOLDER')"
        />
      </label>
      <div class="grid grid-cols-2 gap-3">
        <label>
          {{ $t('MAINTENANCE.ASSET.INSTALLED_ON') }}
          <input v-model="form.installed_on" type="date" />
        </label>
        <label>
          {{ $t('MAINTENANCE.ASSET.WARRANTY_UNTIL') }}
          <input v-model="form.warranty_until" type="date" />
        </label>
      </div>
      <label>
        {{ $t('MAINTENANCE.NOTES') }}
        <textarea v-model="form.notes" rows="2" />
      </label>
      <div class="flex items-center justify-between gap-2 mt-2">
        <button
          v-if="asset && asset.active"
          type="button"
          class="button clear alert"
          @click="retire"
        >
          {{ $t('MAINTENANCE.ASSET.RETIRE') }}
        </button>
        <span v-else />
        <div class="flex gap-2">
          <button type="button" class="button clear" @click="$emit('close')">
            {{ $t('MAINTENANCE.CANCEL') }}
          </button>
          <woot-submit-button
            :button-text="$t('MAINTENANCE.SAVE')"
            :loading="saving"
          />
        </div>
      </div>
    </form>
  </woot-modal>
</template>
