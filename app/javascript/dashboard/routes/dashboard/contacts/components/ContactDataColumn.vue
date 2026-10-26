<!--
  Página del contacto › columna «Datos»: lo fijo del contacto y sus campos
  particulares (atributos personalizados) en un solo bloque, un renglón cada uno.
-->
<script>
import CustomAttributes from 'dashboard/routes/dashboard/conversation/customAttributes/CustomAttributes.vue';

const formatDate = unix =>
  unix
    ? new Date(unix * 1000).toLocaleDateString(undefined, {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
      })
    : '';

export default {
  name: 'ContactDataColumn',
  components: { CustomAttributes },
  props: {
    contact: { type: Object, required: true },
  },
  computed: {
    additional() {
      return this.contact.additional_attributes || {};
    },
    location() {
      const { city, country, location } = this.additional;
      return [city, country].filter(Boolean).join(', ') || location || '';
    },
    rows() {
      return [
        { key: 'COMPANY', value: this.additional.company_name },
        { key: 'LOCATION', value: this.location },
        { key: 'CREATED_AT', value: formatDate(this.contact.created_at) },
        {
          key: 'LAST_ACTIVITY',
          value: formatDate(this.contact.last_activity_at),
        },
        { key: 'DESCRIPTION', value: this.additional.description },
      ].filter(row => row.value);
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-6 p-4">
    <section>
      <h3
        class="mb-2 text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
      >
        {{ $t('CONTACT_PAGE.DATA.TITLE') }}
      </h3>
      <dl class="flex flex-col gap-2 m-0">
        <div
          v-for="row in rows"
          :key="row.key"
          class="grid grid-cols-[7.5rem_1fr] gap-2 text-sm"
        >
          <dt class="text-slate-500 dark:text-slate-400">
            {{ $t(`CONTACT_PAGE.DATA.${row.key}`) }}
          </dt>
          <dd class="m-0 break-words text-slate-800 dark:text-slate-100">
            {{ row.value }}
          </dd>
        </div>
      </dl>
      <!-- Campos particulares (Clientes › Atributos personalizados), un renglón cada uno -->
      <CustomAttributes
        inline
        class="mt-2"
        :contact-id="contact.id"
        attribute-type="contact_attribute"
        attribute-from="contact_panel"
        :custom-attributes="contact.custom_attributes"
      />
    </section>
  </div>
</template>
