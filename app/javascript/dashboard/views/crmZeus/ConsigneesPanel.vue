<!--
  CrmZeus O2 — pestaña «Consignatarios»: todas las direcciones de la organización
  menos el domicilio. Solo una dirección (contando el domicilio) es «para facturar».
-->
<script>
import { useAlert } from 'dashboard/composables';
import CrmOrganizations from 'dashboard/api/crmOrganizations';
import AddressFields from './AddressFields.vue';
import { blankAddress, errorMessage } from './crmHelpers';

export default {
  name: 'CrmConsigneesPanel',
  components: { AddressFields },
  props: {
    organizationId: { type: [Number, String], required: true },
    legalName: { type: String, default: '' },
    countries: { type: Array, default: () => [] },
    canEdit: { type: Boolean, default: false },
  },
  data() {
    return {
      consignees: [],
      loading: true,
      form: null,
      saving: false,
      toDelete: null,
    };
  },
  mounted() {
    this.fetch();
  },
  methods: {
    async fetch() {
      this.loading = true;
      try {
        const { data } = await CrmOrganizations.consignees(this.organizationId);
        this.consignees = data.consignees;
      } finally {
        this.loading = false;
      }
    },
    openNew() {
      this.form = { ...blankAddress(), consignee_name: this.legalName };
    },
    openEdit(consignee) {
      if (!this.canEdit) return;
      this.form = { ...blankAddress(), ...consignee };
    },
    async save() {
      this.saving = true;
      const {
        id,
        city,
        full_address: _,
        is_primary: __,
        ...payload
      } = this.form;
      try {
        if (id) {
          await CrmOrganizations.updateConsignee(
            this.organizationId,
            id,
            payload
          );
        } else {
          await CrmOrganizations.createConsignee(this.organizationId, payload);
        }
        useAlert(this.$t('CRM_ZEUS.CONSIGNEES.SAVED'));
        this.form = null;
        this.fetch();
        this.$emit('changed');
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      } finally {
        this.saving = false;
      }
    },
    async remove(consignee) {
      this.toDelete = consignee;
      const confirmed = await this.$refs.deleteDialog.showConfirmation();
      this.toDelete = null;
      if (!confirmed) return;
      try {
        await CrmOrganizations.deleteConsignee(
          this.organizationId,
          consignee.id
        );
        this.fetch();
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <div class="flex items-center justify-between">
      <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
        {{ $t('CRM_ZEUS.CONSIGNEES.HINT') }}
      </p>
      <woot-button v-if="canEdit" size="small" icon="add" @click="openNew">
        {{ $t('CRM_ZEUS.CONSIGNEES.NEW') }}
      </woot-button>
    </div>
    <p v-if="loading" class="text-sm text-slate-500">
      {{ $t('CRM_ZEUS.LOADING') }}
    </p>
    <p
      v-else-if="!consignees.length"
      class="py-6 text-sm text-center text-slate-500"
    >
      {{ $t('CRM_ZEUS.CONSIGNEES.EMPTY') }}
    </p>
    <table v-else class="w-full text-sm">
      <thead>
        <tr class="text-left border-b text-slate-500 border-slate-50">
          <th class="px-3 py-2 font-medium">
            {{ $t('CRM_ZEUS.CONSIGNEES.COLUMNS.NAME') }}
          </th>
          <th class="px-3 py-2 font-medium">
            {{ $t('CRM_ZEUS.CONSIGNEES.COLUMNS.ADDRESS') }}
          </th>
          <th class="px-3 py-2 font-medium">
            {{ $t('CRM_ZEUS.CONSIGNEES.COLUMNS.CONTACT') }}
          </th>
          <th class="px-3 py-2 font-medium" />
        </tr>
      </thead>
      <tbody class="divide-y divide-slate-50 dark:divide-slate-800">
        <tr
          v-for="consignee in consignees"
          :key="consignee.id"
          :class="{
            'cursor-pointer hover:bg-slate-25 dark:hover:bg-slate-800': canEdit,
          }"
          @click="openEdit(consignee)"
        >
          <td class="px-3 py-2 font-medium text-slate-800 dark:text-slate-100">
            {{ consignee.consignee_name }}
            <span
              v-if="consignee.for_billing"
              class="ml-1 px-2 py-0.5 text-xs rounded-full bg-woot-50 text-woot-700"
            >
              {{ $t('CRM_ZEUS.ADDRESS.BILLING_BADGE') }}
            </span>
          </td>
          <td class="px-3 py-2">{{ consignee.full_address || '—' }}</td>
          <td class="px-3 py-2">
            {{
              [consignee.contact_name, consignee.phone]
                .filter(Boolean)
                .join(' · ') || '—'
            }}
          </td>
          <td class="px-3 py-2 text-right">
            <woot-button
              v-if="canEdit"
              size="tiny"
              variant="clear"
              color-scheme="alert"
              icon="delete"
              :title="$t('CRM_ZEUS.DELETE')"
              @click.stop="remove(consignee)"
            />
          </td>
        </tr>
      </tbody>
    </table>

    <woot-modal
      :show="!!form"
      :on-close="() => (form = null)"
      modal-type="right-aligned"
      size="wide"
    >
      <div v-if="form" class="flex flex-col h-auto">
        <woot-modal-header
          :header-title="
            form.id
              ? $t('CRM_ZEUS.CONSIGNEES.EDIT_TITLE')
              : $t('CRM_ZEUS.CONSIGNEES.NEW_TITLE')
          "
        />
        <form class="flex flex-col w-full px-8 pt-4" @submit.prevent="save">
          <AddressFields v-model="form" :countries="countries" consignee />
          <div
            class="sticky bottom-0 z-10 flex justify-end gap-2 px-8 py-3 mt-4 -mx-8 bg-white border-t dark:bg-slate-800 border-slate-50 dark:border-slate-700"
          >
            <button type="button" class="button clear" @click="form = null">
              {{ $t('CRM_ZEUS.CANCEL') }}
            </button>
            <woot-submit-button
              :loading="saving"
              :button-text="$t('CRM_ZEUS.SAVE')"
            />
          </div>
        </form>
      </div>
    </woot-modal>

    <woot-confirm-modal
      ref="deleteDialog"
      :title="$t('CRM_ZEUS.CONSIGNEES.DELETE_TITLE')"
      :description="
        $t('CRM_ZEUS.CONSIGNEES.CONFIRM_DELETE', {
          name: toDelete ? toDelete.consignee_name : '',
        })
      "
      :confirm-label="$t('CRM_ZEUS.DELETE')"
      :cancel-label="$t('CRM_ZEUS.CANCEL')"
    />
  </div>
</template>
