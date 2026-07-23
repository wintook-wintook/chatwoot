<!--
  @tickets_cases — User Portal
  Administración de portales públicos del cliente (estilo osTicket) — Tailwind + dark mode.
-->
<script>
import { mapGetters } from 'vuex';

const LOCALES = ['es', 'en'];

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
  data() {
    return {
      showModal: false,
      editing: null,
      form: emptyForm(),
      locales: LOCALES,
      deletingId: null,
      showDeleteModal: false,
      portalToDelete: null,
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

    <!-- Loading -->
    <div
      v-if="isFetching"
      class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500"
    >
      <span>{{ $t('CASE_TICKETS.PORTALS.LOADING') }}</span>
    </div>

    <!-- Lista -->
    <div v-else class="flex flex-col flex-1 gap-2 px-6 py-4 overflow-y-auto">
      <p class="m-0 mb-2 text-sm text-slate-500 dark:text-slate-400">
        {{ $t('CASE_TICKETS.PORTALS.HELP') }}
      </p>

      <!-- Aviso: sin tipos públicos el form del portal queda vacío -->
      <div
        v-if="publicTypesCount === 0"
        class="flex items-center gap-2 p-3 mb-1 text-sm border rounded-lg text-amber-700 bg-amber-50 border-amber-100 dark:bg-amber-900/20 dark:text-amber-300 dark:border-amber-900/40"
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

      <div
        v-if="!portals.length"
        class="py-8 text-sm text-center text-slate-400 dark:text-slate-500"
      >
        {{ $t('CASE_TICKETS.PORTALS.EMPTY') }}
      </div>

      <div
        v-for="portal in portals"
        :key="portal.id"
        class="flex items-center gap-3 p-3 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <span
          class="flex-shrink-0 w-9 h-9 rounded-lg bg-woot-500 flex items-center justify-center text-white font-bold uppercase"
          >{{ portal.name.charAt(0) }}</span
        >
        <div class="flex flex-col flex-1 min-w-0">
          <div class="flex items-center gap-2">
            <span
              class="text-sm font-medium text-slate-800 dark:text-slate-100"
              >{{ portal.name }}</span
            >
            <span
              v-if="!portal.enabled"
              class="px-1.5 py-0.5 text-xs rounded bg-slate-200 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
              >{{ $t('CASE_TICKETS.PORTALS.DISABLED') }}</span
            >
            <span
              class="px-1.5 py-0.5 text-xs rounded bg-woot-100 text-woot-700 dark:bg-woot-800 dark:text-woot-100"
              >{{
                $t('CASE_TICKETS.PORTALS.TYPES_COUNT', {
                  count: portal.public_types_count,
                })
              }}</span
            >
          </div>
          <a
            :href="fullUrl(portal)"
            target="_blank"
            rel="noopener"
            class="font-mono text-xs truncate text-woot-500 hover:underline"
            >{{ fullUrl(portal) }}</a
          >
          <span class="text-xs text-slate-400 dark:text-slate-500">
            {{ $t('CASE_TICKETS.PORTALS.DESTINATION') }}:
            {{ portal.inbox_name || '—' }}
            <template v-if="portal.inbox_channel">
              · {{ channelLabel(portal.inbox_channel) }}</template
            >
          </span>
        </div>
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          icon="copy"
          @click="copyUrl(portal)"
        >
          {{ $t('CASE_TICKETS.PORTALS.COPY') }}
        </woot-button>
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          icon="edit"
          @click="openEdit(portal)"
        />
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="alert"
          icon="delete"
          :is-loading="deletingId === portal.id"
          @click="openDelete(portal)"
        />
      </div>
    </div>

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
            <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
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
            <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.PORTALS.LOCALE_LABEL') }}</span
            >
            <select v-model="form.locale" class="w-32">
              <option v-for="l in locales" :key="l" :value="l">{{ l }}</option>
            </select>
          </label>

          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
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
            <span class="text-xs font-semibold text-slate-500 dark:text-slate-400">{{
              $t('CASE_TICKETS.PORTALS.WA_TEMPLATE_TITLE')
            }}</span>
            <label class="flex flex-col gap-1">
              <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ $t('CASE_TICKETS.PORTALS.WA_TEMPLATE_NAME') }} *</span
              >
              <input
                v-model="form.acuse_template_name"
                type="text"
                class="w-full font-mono"
                :placeholder="$t('CASE_TICKETS.PORTALS.WA_TEMPLATE_PLACEHOLDER')"
              />
            </label>
            <label class="flex flex-col gap-1">
              <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ $t('CASE_TICKETS.PORTALS.WA_TEMPLATE_LANG') }}</span
              >
              <input
                v-model="form.acuse_template_language"
                type="text"
                class="w-32 font-mono"
                placeholder="es"
              />
            </label>
            <span class="text-xs text-slate-400 dark:text-slate-500">{{
              $t('CASE_TICKETS.PORTALS.WA_TEMPLATE_HELP')
            }}</span>
          </div>

          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
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
