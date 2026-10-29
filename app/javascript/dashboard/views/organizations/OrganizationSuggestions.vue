<!--
  Plan-Organizaciones O4 — asistente para los contactos que ya existían: muestra las
  organizaciones que propone (por empresa escrita, dominio de correo o cliente que es una
  persona) con su etapa sugerida. Nada se aplica hasta «Aplicar»; se puede quitar un
  grupo, cambiarle el nombre, la etapa o el tipo.
-->
<script>
import { useAlert } from 'dashboard/composables';
import OrganizationsAPI from 'dashboard/api/organizations';
import Spinner from 'shared/components/Spinner.vue';
import { KINDS, STAGES } from './organizationHelpers';

export default {
  name: 'OrganizationSuggestions',
  components: { Spinner },
  props: {
    show: { type: Boolean, default: false },
  },
  emits: ['close', 'applied'],
  data() {
    return { groups: [], loading: false, applying: false };
  },
  computed: {
    stages() {
      return STAGES;
    },
    kinds() {
      return KINDS;
    },
    chosen() {
      return this.groups.filter(group => group.selected);
    },
  },
  watch: {
    show: {
      immediate: true,
      handler(open) {
        if (open) this.fetch();
      },
    },
  },
  methods: {
    async fetch() {
      this.loading = true;
      try {
        const { data } = await OrganizationsAPI.suggestions();
        this.groups = (data.suggestions || []).map(group => ({
          ...group,
          selected: true,
        }));
      } catch {
        this.groups = [];
      } finally {
        this.loading = false;
      }
    },
    contactNames(group) {
      return group.contacts.map(contact => contact.name).join(', ');
    },
    async apply() {
      this.applying = true;
      try {
        const { data } = await OrganizationsAPI.applySuggestions(
          this.chosen.map(group => ({
            name: group.name,
            kind: group.kind,
            stage: group.stage,
            email_domain: group.email_domain,
            existing_organization_id: group.existing_organization_id,
            contact_ids: group.contacts.map(contact => contact.id),
          }))
        );
        useAlert(this.$t('ORGANIZATIONS.ASSISTANT.DONE', data));
        this.$emit('applied');
      } catch {
        useAlert(this.$t('ORGANIZATIONS.ERROR'));
      } finally {
        this.applying = false;
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
        :header-title="$t('ORGANIZATIONS.ASSISTANT.TITLE')"
        :header-content="$t('ORGANIZATIONS.ASSISTANT.DESCRIPTION')"
      />
      <div class="flex flex-col gap-2 px-8 pt-4 pb-0">
        <Spinner v-if="loading" />
        <p v-else-if="!groups.length" class="py-8 text-sm text-slate-500">
          {{ $t('ORGANIZATIONS.ASSISTANT.EMPTY') }}
        </p>
        <div
          v-for="group in groups"
          :key="group.key"
          class="flex gap-3 p-3 border rounded-md border-slate-100 dark:border-slate-700"
          :class="{ 'opacity-50': !group.selected }"
        >
          <input v-model="group.selected" type="checkbox" class="!m-0 mt-2" />
          <div class="flex flex-col flex-1 min-w-0 gap-1">
            <div class="flex flex-wrap items-center gap-2">
              <input
                v-model="group.name"
                type="text"
                class="!mb-0 flex-1 min-w-[10rem]"
                :disabled="!!group.existing_organization_id"
              />
              <select
                v-model="group.kind"
                class="!mb-0 w-44"
                :disabled="!!group.existing_organization_id"
              >
                <option v-for="kind in kinds" :key="kind" :value="kind">
                  {{ $t(`ORGANIZATIONS.KINDS.${kind}`) }}
                </option>
              </select>
              <select
                v-model="group.stage"
                class="!mb-0 w-36"
                :disabled="!!group.existing_organization_id"
              >
                <option v-for="stage in stages" :key="stage" :value="stage">
                  {{ $t(`ORGANIZATIONS.STAGES.${stage}`) }}
                </option>
              </select>
            </div>
            <span class="text-xs text-slate-500">
              {{ $t(`ORGANIZATIONS.ASSISTANT.SOURCES.${group.source}`) }}
              <template v-if="group.existing_organization_id">
                · {{ $t('ORGANIZATIONS.ASSISTANT.EXISTING') }}
              </template>
            </span>
            <span class="text-sm text-slate-700 dark:text-slate-200">
              {{
                $t('ORGANIZATIONS.ASSISTANT.CONTACTS', {
                  count: group.contacts.length,
                  names: contactNames(group),
                })
              }}
            </span>
          </div>
        </div>
      </div>
      <div
        class="sticky bottom-0 z-10 flex items-center justify-end gap-2 px-8 py-3 mt-4 bg-white border-t dark:bg-slate-800 border-slate-50 dark:border-slate-700"
      >
        <span class="mr-auto text-xs text-slate-500">
          {{
            $t('ORGANIZATIONS.ASSISTANT.SELECTED', {
              count: chosen.length,
            })
          }}
        </span>
        <button type="button" class="button clear" @click="$emit('close')">
          {{ $t('ORGANIZATIONS.FORM.CANCEL') }}
        </button>
        <woot-button
          :is-loading="applying"
          :disabled="!chosen.length"
          @click="apply"
        >
          {{ $t('ORGANIZATIONS.ASSISTANT.APPLY') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
