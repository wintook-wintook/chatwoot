<!--
  @tickets_cases — User Portal
  Administración de portales públicos del cliente. Ahora con tabla nativa de
  Chatwoot (vue-easytable) + paginado inferior y estado como toggle, en lugar de
  la lista de tarjetas. El modal de alta/edición se conserva íntegro.
-->
<script>
import { mapGetters } from 'vuex';
import { VeTable } from 'vue-easytable';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';

const LOCALES = ['es', 'en'];
const PER_PAGE_OPTIONS = [25, 50, 100];

const emptyForm = () => ({
  name: '',
  slug: '',
  locale: 'es',
  enabled: true,
  intro: '',
  inbox_id: null,
  acuse_template_name: '',
  acuse_template_language: 'es',
});

// Canales que permiten una conversación nueva iniciada por el negocio.
// R1: API/Email. R2: WhatsApp (requiere plantilla de acuse aprobada).
const COMPATIBLE_CHANNELS = [
  'Channel::Api',
  'Channel::Email',
  'Channel::Whatsapp',
];

export default {
  name: 'Portals',
  components: { VeTable, TableFooter },
  data() {
    return {
      showModal: false,
      editing: null,
      form: emptyForm(),
      locales: LOCALES,
      deletingId: null,
      showDeleteModal: false,
      portalToDelete: null,
      currentPage: 1,
      perPage: 25,
      perPageOptions: PER_PAGE_OPTIONS,
    };
  },
  computed: {
    ...mapGetters({
      portals: 'caseTickets/getPortals',
      uiFlags: 'caseTickets/getPortalsUIFlags',
      types: 'caseTickets/getTypes',
      inboxes: 'inboxes/getInboxes',
    }),
    // Inboxes que pueden recibir tickets del portal (conversación nueva): API/Email/WhatsApp.
    compatibleInboxes() {
      return this.inboxes.filter(i =>
        COMPATIBLE_CHANNELS.includes(i.channel_type)
      );
    },
    // ¿El inbox destino elegido es WhatsApp? → requiere plantilla de acuse.
    isWhatsappDestination() {
      const sel = this.inboxes.find(i => i.id === this.form.inbox_id);
      return sel?.channel_type === 'Channel::Whatsapp';
    },
    isFetching() {
      return this.uiFlags.isFetching;
    },
    isSaving() {
      return this.uiFlags.isSaving;
    },
    publicTypesCount() {
      return this.types.filter(t => t.public).length;
    },
    deleteMessageValue() {
      return this.portalToDelete ? ` "${this.portalToDelete.name}"?` : '';
    },
    pagedPortals() {
      const start = (this.currentPage - 1) * this.perPage;
      return this.portals.slice(start, start + this.perPage);
    },
    columns() {
      return [
        {
          field: 'name',
          key: 'name',
          title: this.$t('CASE_TICKETS.PORTALS.TABLE_NAME'),
          align: 'left',
          renderBodyCell: ({ row }) => (
            <div class="flex items-center gap-3 min-w-0">
              <span class="flex items-center justify-center flex-shrink-0 w-8 h-8 font-bold text-white uppercase rounded-lg bg-woot-500">
                {row.name.charAt(0)}
              </span>
              <div class="flex items-center gap-2 min-w-0">
                <span class="text-sm font-medium truncate text-slate-800 dark:text-slate-100">
                  {row.name}
                </span>
                {!row.enabled ? (
                  <span class="px-1.5 py-0.5 text-xs rounded bg-slate-200 text-slate-600 dark:bg-slate-700 dark:text-slate-300">
                    {this.$t('CASE_TICKETS.PORTALS.DISABLED')}
                  </span>
                ) : null}
              </div>
            </div>
          ),
        },
        {
          field: 'url',
          key: 'url',
          title: this.$t('CASE_TICKETS.PORTALS.TABLE_URL'),
          align: 'left',
          renderBodyCell: ({ row }) => (
            <div class="flex items-center gap-1 min-w-0">
              <a
                href={this.fullUrl(row)}
                target="_blank"
                rel="noopener"
                class="font-mono text-xs truncate text-woot-500 hover:underline"
              >
                {this.fullUrl(row)}
              </a>
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="secondary"
                icon="copy"
                title={this.$t('CASE_TICKETS.PORTALS.COPY')}
                onClick={() => this.copyUrl(row)}
              />
            </div>
          ),
        },
        {
          field: 'destination',
          key: 'destination',
          title: this.$t('CASE_TICKETS.PORTALS.DESTINATION'),
          align: 'left',
          width: 180,
          renderBodyCell: ({ row }) => (
            <span class="text-sm text-slate-600 dark:text-slate-300">
              {row.inbox_name || '—'}
              {row.inbox_channel
                ? ` · ${this.channelLabel(row.inbox_channel)}`
                : ''}
            </span>
          ),
        },
        {
          field: 'types',
          key: 'types',
          title: this.$t('CASE_TICKETS.PORTALS.TABLE_TYPES'),
          align: 'center',
          width: 90,
          renderBodyCell: ({ row }) => (
            <span class="px-2 py-0.5 text-xs font-medium rounded-full bg-woot-100 text-woot-700 dark:bg-woot-800 dark:text-woot-100">
              {row.public_types_count}
            </span>
          ),
        },
        {
          field: 'status',
          key: 'status',
          title: this.$t('CASE_TICKETS.PORTALS.TABLE_STATUS'),
          align: 'left',
          width: 120,
          renderBodyCell: ({ row }) => (
            <woot-button
              size="tiny"
              variant={row.enabled ? 'smooth' : 'clear'}
              color-scheme={row.enabled ? 'success' : 'secondary'}
              icon={row.enabled ? 'checkmark-circle' : 'dismiss-circle'}
              onClick={() => this.toggleEnabled(row)}
            >
              {row.enabled
                ? this.$t('CASE_TICKETS.PORTALS.ENABLED_BADGE')
                : this.$t('CASE_TICKETS.PORTALS.DISABLED')}
            </woot-button>
          ),
        },
        {
          field: 'actions',
          key: 'actions',
          title: '',
          align: 'right',
          width: 100,
          renderBodyCell: ({ row }) => (
            <div class="flex items-center justify-end gap-1">
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="secondary"
                icon="edit"
                onClick={() => this.openEdit(row)}
              />
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="alert"
                icon="delete"
                isLoading={this.deletingId === row.id}
                onClick={() => this.openDelete(row)}
              />
            </div>
          ),
        },
      ];
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchPortals');
    this.$store.dispatch('caseTickets/fetchTypes');
    this.$store.dispatch('inboxes/get');
  },
  methods: {
    fullUrl(portal) {
      return `${window.location.origin}${portal.public_path}`;
    },
    channelLabel(channelType) {
      if (channelType === 'Channel::Email') return 'Email';
      if (channelType === 'Channel::Api') return 'API';
      if (channelType === 'Channel::Whatsapp') return 'WhatsApp';
      return channelType;
    },
    openCreate() {
      this.editing = null;
      this.form = emptyForm();
      this.showModal = true;
    },
    openEdit(portal) {
      this.editing = portal;
      this.form = {
        name: portal.name,
        slug: portal.slug,
        locale: portal.locale,
        enabled: portal.enabled,
        intro: portal.intro || '',
        inbox_id: portal.inbox_id || null,
        acuse_template_name: portal.acuse_template_name || '',
        acuse_template_language: portal.acuse_template_language || 'es',
      };
      this.showModal = true;
    },
    onSlugInput() {
      this.form.slug = (this.form.slug || '')
        .toLowerCase()
        .replace(/[^a-z0-9-]/g, '');
    },
    async save() {
      try {
        if (this.editing) {
          await this.$store.dispatch('caseTickets/updatePortal', {
            id: this.editing.id,
            ...this.form,
          });
        } else {
          await this.$store.dispatch('caseTickets/createPortal', this.form);
        }
        this.showModal = false;
      } catch (e) {
        const msg =
          e?.response?.data?.error?.[0] ||
          this.$t('CASE_TICKETS.PORTALS.SAVE_ERROR');
        this.$emitter.emit('newToastMessage', { message: msg });
      }
    },
    async toggleEnabled(portal) {
      try {
        await this.$store.dispatch('caseTickets/updatePortal', {
          id: portal.id,
          enabled: !portal.enabled,
        });
      } catch (_e) {
        /* silent */
      }
    },
    copyUrl(portal) {
      navigator.clipboard?.writeText(this.fullUrl(portal));
      this.$emitter.emit('newToastMessage', {
        message: this.$t('CASE_TICKETS.PORTALS.COPIED'),
      });
    },
    openDelete(portal) {
      this.portalToDelete = portal;
      this.showDeleteModal = true;
    },
    closeDelete() {
      this.showDeleteModal = false;
      this.portalToDelete = null;
    },
    async confirmDelete() {
      const portal = this.portalToDelete;
      if (!portal) return;
      this.showDeleteModal = false;
      this.deletingId = portal.id;
      try {
        await this.$store.dispatch('caseTickets/deletePortal', portal.id);
      } finally {
        this.deletingId = null;
        this.portalToDelete = null;
      }
    },
    changePage(page) {
      this.currentPage = page;
    },
    changePerPage() {
      this.currentPage = 1;
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <!-- Header -->
    <div
      class="flex items-center justify-between flex-shrink-0 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div class="flex items-center gap-4">
        <woot-button
          size="small"
          variant="clear"
          color-scheme="secondary"
          icon="chevron-left"
          @click="$router.push({ name: 'gestorTickets_index' })"
        >
          {{ $t('CASE_TICKETS.PORTALS.BACK') }}
        </woot-button>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('CASE_TICKETS.PORTALS.TITLE') }}
        </h1>
      </div>
      <woot-button size="small" icon="add-circle" @click="openCreate">
        {{ $t('CASE_TICKETS.PORTALS.CREATE_BUTTON') }}
      </woot-button>
    </div>

    <!-- Ayuda + aviso -->
    <div class="flex flex-col flex-shrink-0 gap-2 px-6 pt-4">
      <p class="m-0 text-sm text-slate-500 dark:text-slate-400">
        {{ $t('CASE_TICKETS.PORTALS.HELP') }}
      </p>
      <div
        v-if="publicTypesCount === 0"
        class="flex items-center gap-2 p-3 text-sm border rounded-lg text-amber-700 bg-amber-50 border-amber-100 dark:bg-amber-900/20 dark:text-amber-300 dark:border-amber-900/40"
      >
        <fluent-icon icon="warning" size="16" />
        <span>{{ $t('CASE_TICKETS.PORTALS.NO_PUBLIC_TYPES') }}</span>
        <woot-button
          size="tiny"
          variant="link"
          @click="$router.push({ name: 'gestorTickets_types' })"
        >
          {{ $t('CASE_TICKETS.PORTALS.GO_TO_TYPES') }}
        </woot-button>
      </div>
    </div>

    <!-- Loading -->
    <div
      v-if="isFetching && !portals.length"
      class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500"
    >
      <span>{{ $t('CASE_TICKETS.PORTALS.LOADING') }}</span>
    </div>

    <!-- Empty -->
    <div
      v-else-if="!portals.length"
      class="flex flex-col items-center justify-center flex-1 gap-3 text-slate-400 dark:text-slate-500"
    >
      <fluent-icon icon="globe" size="36" />
      <p>{{ $t('CASE_TICKETS.PORTALS.EMPTY') }}</p>
    </div>

    <!-- Tabla + paginado -->
    <template v-else>
      <div class="flex-1 min-h-0 px-6 py-4 portals-table-wrap">
        <VeTable
          fixed-header
          max-height="100%"
          row-key-field-name="id"
          :columns="columns"
          :table-data="pagedPortals"
          :border-around="false"
        />
      </div>
      <div
        class="flex items-center justify-between flex-shrink-0 bg-white border-t dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
      >
        <label
          class="flex items-center gap-1 pl-6 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('CASE_TICKETS.PORTALS.PER_PAGE') }}
          <select
            v-model.number="perPage"
            class="!mb-0 w-20 text-sm"
            @change="changePerPage"
          >
            <option v-for="n in perPageOptions" :key="n" :value="n">
              {{ n }}
            </option>
          </select>
        </label>
        <TableFooter
          :current-page="currentPage"
          :total-count="portals.length"
          :page-size="perPage"
          @pageChange="changePage"
        />
      </div>
    </template>

    <!-- Modal crear/editar -->
    <woot-modal
      v-if="showModal"
      :show="showModal"
      :on-close="() => (showModal = false)"
      size="small"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="
            editing
              ? $t('CASE_TICKETS.PORTALS.EDIT_TITLE')
              : $t('CASE_TICKETS.PORTALS.CREATE_TITLE')
          "
        />
        <form
          class="flex flex-col self-stretch w-full gap-4 pb-8"
          @submit.prevent="save"
        >
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.PORTALS.NAME_LABEL') }} *</span
            >
            <input
              v-model="form.name"
              type="text"
              class="w-full"
              required
              maxlength="100"
              :placeholder="$t('CASE_TICKETS.PORTALS.NAME_PLACEHOLDER')"
            />
          </label>

          <label class="flex flex-col gap-1">
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.PORTALS.SLUG_LABEL') }}</span
            >
            <input
              v-model="form.slug"
              type="text"
              class="w-full font-mono"
              maxlength="100"
              :placeholder="$t('CASE_TICKETS.PORTALS.SLUG_PLACEHOLDER')"
              @input="onSlugInput"
            />
            <span class="text-xs text-slate-400 dark:text-slate-500">{{
              $t('CASE_TICKETS.PORTALS.SLUG_HELP')
            }}</span>
          </label>

          <label class="flex flex-col gap-1">
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.PORTALS.LOCALE_LABEL') }}</span
            >
            <select v-model="form.locale" class="w-32">
              <option v-for="l in locales" :key="l" :value="l">{{ l }}</option>
            </select>
          </label>

          <label class="flex flex-col gap-1">
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.PORTALS.INBOX_LABEL') }}</span
            >
            <select v-model="form.inbox_id" class="w-full">
              <option :value="null">
                {{ $t('CASE_TICKETS.PORTALS.INBOX_DEFAULT') }}
              </option>
              <option v-for="i in compatibleInboxes" :key="i.id" :value="i.id">
                {{ i.name }} · {{ channelLabel(i.channel_type) }}
              </option>
            </select>
            <span class="text-xs text-slate-400 dark:text-slate-500">{{
              $t('CASE_TICKETS.PORTALS.INBOX_HELP')
            }}</span>
          </label>

          <!-- R2: si el destino es WhatsApp, la plantilla del acuse es obligatoria -->
          <div
            v-if="isWhatsappDestination"
            class="flex flex-col gap-3 p-3 border border-dashed rounded-lg border-slate-300 dark:border-slate-600 bg-slate-25 dark:bg-slate-800/40"
          >
            <span
              class="text-xs font-semibold text-slate-500 dark:text-slate-400"
              >{{ $t('CASE_TICKETS.PORTALS.WA_TEMPLATE_TITLE') }}</span
            >
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ $t('CASE_TICKETS.PORTALS.WA_TEMPLATE_NAME') }} *</span
              >
              <input
                v-model="form.acuse_template_name"
                type="text"
                class="w-full font-mono"
                :placeholder="
                  $t('CASE_TICKETS.PORTALS.WA_TEMPLATE_PLACEHOLDER')
                "
              />
            </label>
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ $t('CASE_TICKETS.PORTALS.WA_TEMPLATE_LANG') }}</span
              >
              <input
                v-model="form.acuse_template_language"
                type="text"
                class="w-32 font-mono"
                :placeholder="$t('CASE_TICKETS.PORTALS.WA_LANG_PLACEHOLDER')"
              />
            </label>
            <span class="text-xs text-slate-400 dark:text-slate-500">{{
              $t('CASE_TICKETS.PORTALS.WA_TEMPLATE_HELP')
            }}</span>
          </div>

          <label class="flex flex-col gap-1">
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.PORTALS.INTRO_LABEL') }}</span
            >
            <textarea
              v-model="form.intro"
              rows="2"
              class="w-full"
              :placeholder="$t('CASE_TICKETS.PORTALS.INTRO_PLACEHOLDER')"
            />
          </label>

          <label class="flex items-center gap-2">
            <input v-model="form.enabled" type="checkbox" />
            <span class="text-sm text-slate-700 dark:text-slate-200">{{
              $t('CASE_TICKETS.PORTALS.ENABLED_LABEL')
            }}</span>
          </label>

          <div class="flex justify-end gap-2 mt-2">
            <woot-button
              variant="clear"
              color-scheme="secondary"
              type="button"
              @click="showModal = false"
            >
              {{ $t('CASE_TICKETS.PORTALS.CANCEL') }}
            </woot-button>
            <woot-button
              type="submit"
              :is-loading="isSaving"
              :disabled="
                !form.name.trim() ||
                (isWhatsappDestination && !form.acuse_template_name.trim())
              "
            >
              {{
                editing
                  ? $t('CASE_TICKETS.PORTALS.SAVE')
                  : $t('CASE_TICKETS.PORTALS.CREATE')
              }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>

    <!-- Confirmación de borrado -->
    <woot-delete-modal
      :show.sync="showDeleteModal"
      :on-close="closeDelete"
      :on-confirm="confirmDelete"
      :title="$t('CASE_TICKETS.PORTALS.DELETE.TITLE')"
      :message="$t('CASE_TICKETS.PORTALS.DELETE.MESSAGE')"
      :message-value="deleteMessageValue"
      :confirm-text="$t('CASE_TICKETS.PORTALS.DELETE.YES')"
      :reject-text="$t('CASE_TICKETS.PORTALS.DELETE.NO')"
    />
  </div>
</template>

<style lang="scss" scoped>
.portals-table-wrap {
  overflow: hidden;
}

.portals-table-wrap::v-deep {
  .ve-table {
    height: 100%;
  }
  .ve-table-header-th {
    padding: var(--space-small) var(--space-one) !important;
    font-size: var(--font-size-mini) !important;
  }
  .ve-table-body-td {
    padding: var(--space-small) var(--space-one) !important;
    vertical-align: middle;
  }
}
</style>
