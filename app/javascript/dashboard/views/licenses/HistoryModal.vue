<script>
// feat/licencias (F2b) — HISTORIAL DE LICENCIAS DE UNA CUENTA
// ============================================================================
// Todas sus licencias, la más reciente primero. Una PROGRAMADA se puede cancelar con
// «Gestionar licencias»; la vigente no (para cambiarla se asigna otra que empiece ya).
// ============================================================================
import { useAlert } from 'dashboard/composables';
import Modal from 'dashboard/components/Modal.vue';
import LicensesAPI from 'dashboard/api/licenses';

export default {
  components: { Modal },
  props: {
    account: { type: Object, required: true },
    canManage: { type: Boolean, default: false },
  },
  emits: ['close'],
  data() {
    return {
      show: true,
      licenses: [],
      loading: true,
      changed: false,
      cancelling: null,
    };
  },
  mounted() {
    this.fetch();
  },
  methods: {
    t(key, args) {
      return this.$t(`LICENSES.${key}`, args);
    },
    async fetch() {
      this.loading = true;
      try {
        const { data } = await LicensesAPI.getAccount(this.account.id);
        this.licenses = data.licenses || [];
      } catch (error) {
        useAlert(this.t('LOAD_ERROR'));
      } finally {
        this.loading = false;
      }
    },
    date(value) {
      return value
        ? new Date(value).toLocaleDateString(this.$i18n.locale)
        : '—';
    },
    statusScheme(status) {
      return {
        active: 'success',
        scheduled: 'primary',
        expired: 'alert',
        cancelled: 'secondary',
      }[status];
    },
    async cancel(license) {
      this.cancelling = license.id;
      try {
        await LicensesAPI.cancel(license.id);
        useAlert(this.t('HISTORY.CANCELLED'));
        this.changed = true;
        await this.fetch();
      } catch (error) {
        const data = error && error.response && error.response.data;
        useAlert((data && data.message) || this.t('HISTORY.CANCEL_ERROR'));
      } finally {
        this.cancelling = null;
      }
    },
    close() {
      this.$emit('close', this.changed);
    },
  },
};
</script>

<template>
  <Modal :show.sync="show" :on-close="close">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="t('HISTORY.TITLE', { name: account.name })"
      />
      <div class="flex flex-col px-8 pb-6">
        <p
          v-if="!loading && !licenses.length"
          class="text-sm text-slate-500 dark:text-slate-400"
        >
          {{ t('HISTORY.EMPTY') }}
        </p>
        <div
          v-for="license in licenses"
          :key="license.id"
          class="flex flex-wrap items-start justify-between gap-2 py-3 border-b border-slate-100 dark:border-slate-700"
        >
          <div
            class="flex flex-col gap-1 text-sm text-slate-700 dark:text-slate-200"
          >
            <span>
              <span class="font-medium">{{ license.name }}</span>
              <woot-label
                small
                class="!mb-0 ltr:ml-2 rtl:mr-2"
                :color-scheme="statusScheme(license.status)"
                :title="t(`STATUS.${license.status.toUpperCase()}`)"
              />
            </span>
            <span class="text-xs text-slate-500 dark:text-slate-400">
              {{
                t('HISTORY.FROM_TO', {
                  from: date(license.starts_at),
                  to: date(license.expires_at),
                })
              }}
              · {{ license.max_agents }} {{ t('ISSUE.AGENTS').toLowerCase() }}
              <template v-if="license.created_by">
                · {{ t('HISTORY.BY', { name: license.created_by }) }}
              </template>
            </span>
            <span
              v-if="license.notes"
              class="text-xs text-slate-500 dark:text-slate-400"
            >
              {{ license.notes }}
            </span>
          </div>
          <woot-button
            v-if="canManage && license.status === 'scheduled'"
            size="small"
            variant="smooth"
            color-scheme="alert"
            :is-loading="cancelling === license.id"
            @click="cancel(license)"
          >
            {{ t('HISTORY.CANCEL') }}
          </woot-button>
        </div>
        <div class="flex justify-end mt-4">
          <woot-button variant="clear" color-scheme="secondary" @click="close">
            {{ t('HISTORY.CLOSE') }}
          </woot-button>
        </div>
      </div>
    </div>
  </Modal>
</template>
