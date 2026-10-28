<!--
  Plan-Organizaciones O1 — alta y edición de una organización (panel lateral). Empresa
  (se le factura: RFC y datos fiscales) o Público en general (sin factura) es aparte de
  la etapa. Desde un contacto («Convertir en prospecto») se llena con su empresa escrita
  o, sin ella, con su nombre como público en general, y el contacto queda ligado.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import OrganizationsAPI from 'dashboard/api/organizations';
import { KINDS, STAGES } from './organizationHelpers';

export default {
  name: 'OrganizationForm',
  props: {
    show: { type: Boolean, default: false },
    organization: { type: Object, default: null },
    // «Convertir en prospecto» desde la página del contacto.
    contact: { type: Object, default: null },
  },
  emits: ['close', 'saved'],
  data() {
    return { form: this.blank(), stage: 'prospect', saving: false };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents' }),
    isEdit() {
      return !!(this.organization && this.organization.id);
    },
    isCompany() {
      return this.form.kind === 'company';
    },
    kinds() {
      return KINDS;
    },
    stages() {
      return STAGES;
    },
    canSave() {
      return !!(this.form.name || '').trim();
    },
  },
  watch: {
    show: {
      immediate: true,
      handler(open) {
        if (!open) return;
        this.stage = 'prospect';
        this.form = this.isEdit
          ? { ...this.blank(), ...this.organization }
          : this.fromContact();
      },
    },
  },
  mounted() {
    this.$store.dispatch('agents/get');
  },
  methods: {
    blank() {
      return {
        name: '',
        kind: 'company',
        tax_id: '',
        website: '',
        email_domain: '',
        industry: '',
        phone_number: '',
        address: '',
        owner_id: null,
        notes: '',
      };
    },
    // Su empresa escrita → Empresa; sin ella → Público en general con su nombre.
    fromContact() {
      const form = this.blank();
      if (!this.contact) return form;
      const company = (
        (this.contact.additional_attributes || {}).company_name || ''
      ).trim();
      const domain = (this.contact.email || '').split('@')[1] || '';
      return {
        ...form,
        name: company || this.contact.name || '',
        kind: company ? 'company' : 'general_public',
        email_domain: company ? domain : '',
        phone_number: company ? '' : this.contact.phone_number || '',
      };
    },
    payload() {
      const form = this.form;
      const data = {
        name: form.name.trim(),
        kind: form.kind,
        phone_number: form.phone_number,
        address: form.address,
        owner_id: form.owner_id || null,
        notes: form.notes,
      };
      // Público en general no factura: sin RFC ni datos de empresa.
      if (this.isCompany) {
        Object.assign(data, {
          tax_id: form.tax_id,
          website: form.website,
          email_domain: form.email_domain,
          industry: form.industry,
        });
      } else {
        Object.assign(data, { tax_id: null, website: null, industry: null });
      }
      return data;
    },
    async save() {
      if (!this.canSave) return;
      this.saving = true;
      try {
        const { data } = this.isEdit
          ? await OrganizationsAPI.update(this.organization.id, this.payload())
          : await OrganizationsAPI.create(this.payload(), {
              contactId: this.contact && this.contact.id,
              stage: this.stage,
            });
        useAlert(this.$t('ORGANIZATIONS.SAVED'));
        this.$emit('saved', data.organization);
      } catch (error) {
        useAlert(
          error?.response?.data?.error || this.$t('ORGANIZATIONS.ERROR')
        );
      } finally {
        this.saving = false;
      }
    },
  },
};
</script>

<template>
  <woot-modal
    :show="show"
    :on-close="() => $emit('close')"
    modal-type="right-aligned"
    size="wide"
  >
    <div class="flex flex-col h-auto">
      <woot-modal-header
        :header-title="
          isEdit
            ? $t('ORGANIZATIONS.FORM.EDIT_TITLE')
            : contact
            ? $t('ORGANIZATIONS.FORM.FROM_CONTACT_TITLE', {
                name: contact.name,
              })
            : $t('ORGANIZATIONS.FORM.NEW_TITLE')
        "
      />
      <form
        class="flex flex-col self-stretch w-full gap-1 px-8 pt-4 pb-0"
        @submit.prevent="save"
      >
        <!-- Empresa (factura) | Público en general (sin factura) -->
        <div class="mb-3">
          <span class="text-sm font-medium text-slate-800 dark:text-slate-100">
            {{ $t('ORGANIZATIONS.FORM.KIND') }}
          </span>
          <div class="flex gap-2 mt-1">
            <button
              v-for="kind in kinds"
              :key="kind"
              type="button"
              class="flex flex-col items-start flex-1 px-3 py-2 text-left border rounded-md"
              :class="
                form.kind === kind
                  ? 'border-woot-500 bg-woot-25 dark:bg-woot-900/30'
                  : 'border-slate-100 dark:border-slate-700'
              "
              @click="form.kind = kind"
            >
              <span
                class="text-sm font-medium text-slate-800 dark:text-slate-100"
              >
                {{ $t(`ORGANIZATIONS.KINDS.${kind}`) }}
              </span>
              <span class="text-xs text-slate-500 dark:text-slate-400">
                {{ $t(`ORGANIZATIONS.KIND_HINTS.${kind}`) }}
              </span>
            </button>
          </div>
        </div>

        <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-2">
          <label>
            {{
              isCompany
                ? $t('ORGANIZATIONS.FORM.NAME')
                : $t('ORGANIZATIONS.FORM.PERSON_NAME')
            }}
            <input v-model="form.name" type="text" required maxlength="200" />
          </label>
          <label v-if="!isEdit">
            {{ $t('ORGANIZATIONS.FORM.STAGE') }}
            <select v-model="stage">
              <option v-for="key in stages" :key="key" :value="key">
                {{ $t(`ORGANIZATIONS.STAGES.${key}`) }}
              </option>
            </select>
          </label>
        </div>

        <div v-if="isCompany" class="grid grid-cols-1 gap-x-4 sm:grid-cols-2">
          <label>
            {{ $t('ORGANIZATIONS.FORM.TAX_ID') }}
            <input
              v-model="form.tax_id"
              type="text"
              maxlength="20"
              class="uppercase"
            />
            <span class="text-xs text-slate-500 dark:text-slate-400">{{
              $t('ORGANIZATIONS.FORM.TAX_ID_HINT')
            }}</span>
          </label>
          <label>
            {{ $t('ORGANIZATIONS.FORM.INDUSTRY') }}
            <input v-model="form.industry" type="text" />
          </label>
          <label>
            {{ $t('ORGANIZATIONS.FORM.WEBSITE') }}
            <input v-model="form.website" type="text" />
          </label>
          <label>
            {{ $t('ORGANIZATIONS.FORM.EMAIL_DOMAIN') }}
            <input
              v-model="form.email_domain"
              type="text"
              :placeholder="$t('ORGANIZATIONS.FORM.EMAIL_DOMAIN_PLACEHOLDER')"
            />
          </label>
        </div>

        <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-2">
          <label>
            {{ $t('ORGANIZATIONS.FORM.PHONE') }}
            <input v-model="form.phone_number" type="text" />
          </label>
          <label>
            {{ $t('ORGANIZATIONS.FORM.OWNER') }}
            <select v-model="form.owner_id">
              <option :value="null">
                {{ $t('ORGANIZATIONS.FORM.OWNER_NONE') }}
              </option>
              <option v-for="agent in agents" :key="agent.id" :value="agent.id">
                {{ agent.name }}
              </option>
            </select>
          </label>
        </div>

        <label>
          {{ $t('ORGANIZATIONS.FORM.ADDRESS') }}
          <textarea v-model="form.address" rows="2" />
        </label>
        <label>
          {{ $t('ORGANIZATIONS.FORM.NOTES') }}
          <textarea v-model="form.notes" rows="2" />
        </label>

        <div
          class="sticky bottom-0 z-10 flex justify-end gap-2 px-8 py-3 mt-4 -mx-8 bg-white border-t dark:bg-slate-800 border-slate-50 dark:border-slate-700"
        >
          <button type="button" class="button clear" @click="$emit('close')">
            {{ $t('ORGANIZATIONS.FORM.CANCEL') }}
          </button>
          <woot-submit-button
            :loading="saving"
            :disabled="!canSave"
            :button-text="$t('ORGANIZATIONS.FORM.SAVE')"
          />
        </div>
      </form>
    </div>
  </woot-modal>
</template>
