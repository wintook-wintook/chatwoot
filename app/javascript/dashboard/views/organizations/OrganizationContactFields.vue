<!--
  Plan-Organizaciones O2 — «Organización» y «Contacto» juntos para los formularios que
  piden cliente. v-model = contacto; :organization.sync = organización.
  - Elegir organización → el contacto se busca solo entre los suyos (y si el elegido no
    es de ella, se quita).
  - Elegir primero el contacto → su organización se llena sola.
  La organización es opcional: sin ella, el servidor toma la del contacto.
-->
<script>
import OrganizationsAPI from 'dashboard/api/organizations';
import ContactPicker from 'dashboard/views/gestorTickets/ContactPicker.vue';
import OrganizationPicker from './OrganizationPicker.vue';

export default {
  name: 'OrganizationContactFields',
  components: { ContactPicker, OrganizationPicker },
  props: {
    value: { type: Object, default: null },
    organization: { type: Object, default: null },
  },
  emits: ['input', 'update:organization'],
  computed: {
    organizationId() {
      return (this.organization && this.organization.id) || null;
    },
  },
  methods: {
    chooseOrganization(organization) {
      this.$emit('update:organization', organization);
      const contact = this.value;
      if (
        organization &&
        contact &&
        contact.organization_id !== organization.id
      )
        this.$emit('input', null);
    },
    async chooseContact(contact) {
      this.$emit('input', contact);
      if (!contact || this.organization || !contact.organization_id) return;
      try {
        const { data } = await OrganizationsAPI.find(contact.organization_id);
        const { id, name, stage } = data.organization;
        this.$emit('update:organization', { id, name, stage });
      } catch {
        // Sin acceso a la organización: el servidor la toma del contacto igual.
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3 mb-3">
    <div>
      <span class="text-sm font-medium text-slate-800 dark:text-slate-100">
        {{ $t('ORGANIZATIONS.PICKER.LABEL') }}
      </span>
      <OrganizationPicker :value="organization" @input="chooseOrganization" />
    </div>
    <div>
      <span class="text-sm font-medium text-slate-800 dark:text-slate-100">
        {{ $t('ORGANIZATIONS.PICKER.CONTACT') }}
      </span>
      <ContactPicker
        :value="value"
        :organization-id="organizationId"
        @input="chooseContact"
      />
    </div>
  </div>
</template>
