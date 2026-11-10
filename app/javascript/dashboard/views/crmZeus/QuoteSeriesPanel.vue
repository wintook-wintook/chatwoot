<!--
  CrmZeus Q2 — series de folio de cotización por agente (CTFOLIOS_USUARIOS), dentro de
  Catálogos. Cada agente tiene una serie (letras y números, hasta 8) y su último
  consecutivo; el folio es serie + consecutivo a 9 caracteres. Sin serie el agente no
  puede cotizar. Solo el Administrador las cambia.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import CrmCatalogs from 'dashboard/api/crmCatalogs';
import Spinner from 'shared/components/Spinner.vue';
import { errorMessage } from './crmHelpers';

const RESOURCE = 'quote_series';

export default {
  name: 'CrmQuoteSeriesPanel',
  components: { Spinner },
  props: {
    isAdmin: { type: Boolean, default: false },
  },
  data() {
    return {
      items: [],
      form: null,
      toDelete: null,
      loading: true,
      saving: false,
    };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents' }),
    // Agentes que todavía no tienen serie (más el de la que se edita).
    freeAgents() {
      const taken = this.items
        .filter(item => !this.form || item.id !== this.form.id)
        .map(item => item.user_id);
      return this.agents.filter(agent => !taken.includes(agent.id));
    },
  },
  mounted() {
    this.fetch();
  },
  methods: {
    async fetch() {
      this.loading = true;
      try {
        const { data } = await CrmCatalogs.list(RESOURCE);
        this.items = data.items;
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      } finally {
        this.loading = false;
      }
    },
    openNew() {
      this.form = { user_id: '', series: '', last_number: 0 };
    },
    edit(item) {
      if (!this.isAdmin) return;
      this.form = { ...item };
    },
    async save() {
      this.saving = true;
      const {
        id,
        user_id: userId,
        series,
        last_number: lastNumber,
      } = this.form;
      const body = { user_id: userId, series, last_number: lastNumber };
      try {
        if (id) await CrmCatalogs.updateItem(RESOURCE, RESOURCE, id, body);
        else await CrmCatalogs.createItem(RESOURCE, RESOURCE, body);
        this.form = null;
        useAlert(this.$t('CRM_ZEUS.CATALOGS.SAVED'));
        this.fetch();
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      } finally {
        this.saving = false;
      }
    },
    async remove() {
      this.toDelete = this.form;
      if (!(await this.$refs.deleteDialog.showConfirmation())) return;
      try {
        await CrmCatalogs.deleteItem(RESOURCE, this.toDelete.id);
        this.form = null;
        this.fetch();
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      }
    },
  },
};
</script>

<template>
  <div>
    <div class="flex items-start justify-between gap-3 mb-3">
      <p class="max-w-xl m-0 text-sm text-slate-600 dark:text-slate-300">
        {{ $t('CRM_ZEUS.QUOTE_SERIES.DESCRIPTION') }}
      </p>
      <woot-button v-if="isAdmin" size="small" icon="add" @click="openNew">
        {{ $t('CRM_ZEUS.QUOTE_SERIES.ADD') }}
      </woot-button>
    </div>
    <Spinner v-if="loading" />
    <p
      v-else-if="!items.length"
      class="py-12 text-sm text-center text-slate-500"
    >
      {{ $t('CRM_ZEUS.QUOTE_SERIES.EMPTY') }}
    </p>
    <table v-else class="w-full text-sm">
      <thead>
        <tr
          class="text-left border-b text-slate-500 border-slate-50 dark:border-slate-800"
        >
          <th class="px-3 py-2 font-medium">
            {{ $t('CRM_ZEUS.QUOTE_SERIES.AGENT') }}
          </th>
          <th class="px-3 py-2 font-medium">
            {{ $t('CRM_ZEUS.QUOTE_SERIES.SERIES') }}
          </th>
          <th class="px-3 py-2 font-medium text-right">
            {{ $t('CRM_ZEUS.QUOTE_SERIES.LAST_NUMBER') }}
          </th>
          <th class="px-3 py-2 font-medium">
            {{ $t('CRM_ZEUS.QUOTE_SERIES.NEXT_FOLIO') }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="item in items"
          :key="item.id"
          class="border-b border-slate-50 dark:border-slate-800"
          :class="
            isAdmin
              ? 'cursor-pointer hover:bg-slate-25 dark:hover:bg-slate-800'
              : ''
          "
          @click="edit(item)"
        >
          <td class="px-3 py-2">{{ item.user_name }}</td>
          <td class="px-3 py-2 font-medium">{{ item.series }}</td>
          <td class="px-3 py-2 text-right">{{ item.last_number }}</td>
          <td class="px-3 py-2 text-slate-500">{{ item.next_folio }}</td>
        </tr>
      </tbody>
    </table>

    <woot-modal :show="!!form" :on-close="() => (form = null)">
      <div v-if="form" class="flex flex-col h-auto">
        <woot-modal-header
          :header-title="
            form.id
              ? $t('CRM_ZEUS.QUOTE_SERIES.EDIT')
              : $t('CRM_ZEUS.QUOTE_SERIES.ADD')
          "
        />
        <form
          class="flex flex-col w-full px-8 pt-4 pb-6"
          @submit.prevent="save"
        >
          <label>
            {{ $t('CRM_ZEUS.QUOTE_SERIES.AGENT') }}
            <select v-model="form.user_id" required>
              <option value="">—</option>
              <option
                v-for="agent in freeAgents"
                :key="agent.id"
                :value="agent.id"
              >
                {{ agent.name }}
              </option>
            </select>
          </label>
          <label>
            {{ $t('CRM_ZEUS.QUOTE_SERIES.SERIES') }}
            <input
              v-model="form.series"
              type="text"
              maxlength="8"
              required
              class="uppercase"
            />
          </label>
          <label>
            {{ $t('CRM_ZEUS.QUOTE_SERIES.LAST_NUMBER') }}
            <input v-model="form.last_number" type="number" min="0" step="1" />
            <span class="text-xs text-slate-500">
              {{ $t('CRM_ZEUS.QUOTE_SERIES.LAST_NUMBER_HINT') }}
            </span>
          </label>
          <div class="flex justify-between gap-2 mt-4">
            <woot-button
              v-if="form.id"
              type="button"
              variant="smooth"
              color-scheme="alert"
              icon="delete"
              @click="remove"
            >
              {{ $t('CRM_ZEUS.DELETE') }}
            </woot-button>
            <span v-else />
            <div class="flex gap-2">
              <button type="button" class="button clear" @click="form = null">
                {{ $t('CRM_ZEUS.CANCEL') }}
              </button>
              <woot-submit-button
                :loading="saving"
                :button-text="$t('CRM_ZEUS.SAVE')"
              />
            </div>
          </div>
        </form>
      </div>
    </woot-modal>
    <woot-confirm-modal
      ref="deleteDialog"
      :title="$t('CRM_ZEUS.QUOTE_SERIES.DELETE_TITLE')"
      :description="
        $t('CRM_ZEUS.QUOTE_SERIES.CONFIRM_DELETE', {
          series: toDelete ? toDelete.series : '',
        })
      "
      :confirm-label="$t('CRM_ZEUS.DELETE')"
      :cancel-label="$t('CRM_ZEUS.CANCEL')"
    />
  </div>
</template>
