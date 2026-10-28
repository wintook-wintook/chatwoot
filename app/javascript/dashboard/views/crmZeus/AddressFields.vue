<!--
  CrmZeus O2 — campos de una dirección (pestaña «Dirección» de CRMZeus). Los usan el
  domicilio de la organización y los consignatarios (que además llevan nombre del
  consignatario, RFC, teléfonos, correo y contacto). v-model con el objeto completo.
-->
<script>
import CityPicker from './CityPicker.vue';

export default {
  name: 'CrmAddressFields',
  components: { CityPicker },
  props: {
    value: { type: Object, required: true },
    countries: { type: Array, default: () => [] },
    consignee: { type: Boolean, default: false },
    disabled: { type: Boolean, default: false },
  },
  data() {
    return { address: { ...this.value } };
  },
  watch: {
    value(newValue) {
      this.address = { ...newValue };
    },
  },
  methods: {
    update(field, fieldValue) {
      this.address = { ...this.address, [field]: fieldValue };
      this.$emit('input', this.address);
    },
    setCity(city) {
      this.address = {
        ...this.address,
        city_id: city ? city.id : null,
        city: city ? city.full_name : '',
      };
      this.$emit('input', this.address);
    },
  },
};
</script>

<template>
  <fieldset :disabled="disabled" class="flex flex-col gap-1">
    <div
      v-if="consignee"
      class="grid grid-cols-1 gap-x-4 sm:grid-cols-[2fr_1fr]"
    >
      <label>
        {{ $t('CRM_ZEUS.ADDRESS.CONSIGNEE_NAME') }}
        <input
          :value="address.consignee_name"
          type="text"
          maxlength="100"
          required
          @input="update('consignee_name', $event.target.value)"
        />
      </label>
      <label>
        {{ $t('CRM_ZEUS.ADDRESS.TAX_ID') }}
        <input
          :value="address.tax_id"
          type="text"
          maxlength="18"
          @input="update('tax_id', $event.target.value)"
        />
      </label>
    </div>
    <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-[3fr_1fr_1fr]">
      <label>
        {{ $t('CRM_ZEUS.ADDRESS.STREET') }}
        <input
          :value="address.street"
          type="text"
          maxlength="100"
          @input="update('street', $event.target.value)"
        />
      </label>
      <label>
        {{ $t('CRM_ZEUS.ADDRESS.EXTERIOR_NUMBER') }}
        <input
          :value="address.exterior_number"
          type="text"
          maxlength="10"
          @input="update('exterior_number', $event.target.value)"
        />
      </label>
      <label>
        {{ $t('CRM_ZEUS.ADDRESS.INTERIOR_NUMBER') }}
        <input
          :value="address.interior_number"
          type="text"
          maxlength="10"
          @input="update('interior_number', $event.target.value)"
        />
      </label>
    </div>
    <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-2">
      <label>
        {{ $t('CRM_ZEUS.ADDRESS.NEIGHBORHOOD') }}
        <input
          :value="address.neighborhood"
          type="text"
          maxlength="100"
          @input="update('neighborhood', $event.target.value)"
        />
      </label>
      <label>
        {{ $t('CRM_ZEUS.ADDRESS.TOWN') }}
        <input
          :value="address.town"
          type="text"
          maxlength="100"
          @input="update('town', $event.target.value)"
        />
      </label>
    </div>
    <label>
      {{ $t('CRM_ZEUS.ADDRESS.REFERENCE') }}
      <input
        :value="address.reference"
        type="text"
        maxlength="100"
        @input="update('reference', $event.target.value)"
      />
    </label>
    <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-[3fr_1fr]">
      <div>
        <span class="block mb-1 text-sm text-slate-800 dark:text-slate-100">
          {{ $t('CRM_ZEUS.ADDRESS.CITY') }}
        </span>
        <CityPicker
          :label="address.city || ''"
          :countries="countries"
          :disabled="disabled"
          @change="setCity"
        />
      </div>
      <label>
        {{ $t('CRM_ZEUS.ADDRESS.POSTAL_CODE') }}
        <input
          :value="address.postal_code"
          type="text"
          maxlength="10"
          inputmode="numeric"
          @input="update('postal_code', $event.target.value)"
        />
      </label>
    </div>
    <template v-if="consignee">
      <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-3">
        <label>
          {{ $t('CRM_ZEUS.ADDRESS.PHONE') }}
          <input
            :value="address.phone"
            type="text"
            maxlength="35"
            @input="update('phone', $event.target.value)"
          />
        </label>
        <label>
          {{ $t('CRM_ZEUS.ADDRESS.PHONE2') }}
          <input
            :value="address.phone2"
            type="text"
            maxlength="35"
            @input="update('phone2', $event.target.value)"
          />
        </label>
        <label>
          {{ $t('CRM_ZEUS.ADDRESS.EMAIL') }}
          <input
            :value="address.email"
            type="email"
            @input="update('email', $event.target.value)"
          />
        </label>
      </div>
      <label>
        {{ $t('CRM_ZEUS.ADDRESS.CONTACT') }}
        <input
          :value="address.contact_name"
          type="text"
          maxlength="100"
          @input="update('contact_name', $event.target.value)"
        />
      </label>
    </template>
    <label class="flex items-center gap-2">
      <input
        :checked="address.for_billing"
        type="checkbox"
        class="!m-0"
        @change="update('for_billing', $event.target.checked)"
      />
      {{ $t('CRM_ZEUS.ADDRESS.FOR_BILLING') }}
    </label>
  </fieldset>
</template>
