<!--
  Plan-Organizaciones — en las pestañas del contacto, la organización de un registro solo
  cuando NO es la que el contacto tiene hoy (p. ej. lo cerrado que se quedó en Acme cuando
  se cambió a Globex sin llevárselo).
-->
<script>
import OrganizationsAPI from 'dashboard/api/organizations';

// Un pedido por organización aunque la pestaña tenga muchas filas.
const names = new Map();
const nameOf = id => {
  if (!names.has(id)) {
    names.set(
      id,
      OrganizationsAPI.find(id)
        .then(({ data }) => data.organization.name)
        .catch(() => '')
    );
  }
  return names.get(id);
};

export default {
  name: 'OrganizationTag',
  props: {
    organizationId: { type: Number, default: null },
    contactId: { type: Number, required: true },
  },
  data() {
    return { name: '' };
  },
  computed: {
    contactOrganizationId() {
      const contact =
        this.$store.getters['contacts/getContact'](this.contactId) || {};
      return contact.organization_id || null;
    },
    show() {
      return (
        !!this.organizationId &&
        this.organizationId !== this.contactOrganizationId
      );
    },
  },
  watch: {
    show: {
      immediate: true,
      async handler(value) {
        if (value) this.name = await nameOf(this.organizationId);
      },
    },
  },
};
</script>

<template>
  <span
    v-if="show && name"
    v-tooltip.top="$t('ORGANIZATIONS.CONTACT.OTHER_ORGANIZATION')"
    class="inline-flex items-center px-1.5 py-0.5 text-xs rounded bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
  >
    {{ name }}
  </span>
</template>
