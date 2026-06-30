<!--
  ================================================================================
  @campanas_vendedor / proyecto@bulk_tracking_assign
  ================================================================================
  Componente: PreviewContactsModal.vue
  Descripción: Revisión de la audiencia del bulk assign en TABS por bucket. Llama
               al endpoint /preview (dry-run) y agrupa los contactos en:
               Listos · Ya en seguimiento · No contactables · Excluidos.
               La exclusión/deshacer se recalcula EN CLIENTE (el preview devuelve el
               bucket natural + flag excluded), sin re-pegarle al backend.
  ================================================================================
-->

<script>
import contactTrackingBulkAssignsAPI from 'dashboard/api/contactTrackingBulkAssigns';
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';

const PAGE_SIZE = 15;
const NATURAL_TABS = ['ready', 'in_tracking', 'unreachable'];

export default {
  components: { Thumbnail, TableFooter },
  props: {
    show: { type: Boolean, default: false },
    filterPayload: { type: Array, default: () => [] },
    templateId: { type: [String, Number], default: '' },
    skipActive: { type: Boolean, default: true },
    excludedContactIds: { type: Array, default: () => [] },
  },
  emits: ['close', 'update:excludedContactIds'],
  data() {
    return {
      preview: null,
      isLoading: false,
      localExcluded: [...this.excludedContactIds],
      activeTab: 'ready',
      currentPage: 1,
      pageSize: PAGE_SIZE,
    };
  },
  computed: {
    contacts() {
      return this.preview?.contacts || [];
    },
    channel() {
      return this.preview?.channel || {};
    },
    total() {
      return this.preview?.counts?.total || 0;
    },
    // Bucket efectivo: si está excluido manualmente, va a "excluded";
    // si no, su bucket natural del preview.
    effectiveBucket() {
      return contact =>
        this.localExcluded.includes(contact.id) ? 'excluded' : contact.bucket;
    },
    countsByTab() {
      const counts = { ready: 0, in_tracking: 0, unreachable: 0, excluded: 0 };
      this.contacts.forEach(c => {
        counts[this.effectiveBucket(c)] += 1;
      });
      return counts;
    },
    tabs() {
      return [...NATURAL_TABS, 'excluded'].map(key => ({
        key,
        label: this.$t(
          `BULK_TRACKING_ASSIGN.PREVIEW.TABS.${key.toUpperCase()}`
        ),
        count: this.countsByTab[key],
      }));
    },
    currentTabContacts() {
      return this.contacts.filter(
        c => this.effectiveBucket(c) === this.activeTab
      );
    },
    paginatedContacts() {
      const start = (this.currentPage - 1) * this.pageSize;
      return this.currentTabContacts.slice(start, start + this.pageSize);
    },
    readyCount() {
      return this.countsByTab.ready;
    },
  },
  watch: {
    show(val) {
      if (val) this.init();
    },
    templateId() {
      if (this.show) this.fetchPreview();
    },
    skipActive() {
      if (this.show) this.fetchPreview();
    },
  },
  methods: {
    init() {
      this.localExcluded = [...this.excludedContactIds];
      this.activeTab = 'ready';
      this.currentPage = 1;
      this.fetchPreview();
    },
    async fetchPreview() {
      if (!this.templateId) return;
      this.isLoading = true;
      try {
        const { data } = await contactTrackingBulkAssignsAPI.preview({
          payload: this.filterPayload,
          templateId: this.templateId,
          skipActive: this.skipActive,
          excludedContactIds: this.localExcluded,
        });
        this.preview = data;
      } catch (error) {
        this.preview = null;
      } finally {
        this.isLoading = false;
      }
    },
    onTabChange(key) {
      this.activeTab = key;
      this.currentPage = 1;
    },
    onPageChange(page) {
      this.currentPage = page;
    },
    isExcluded(contactId) {
      return this.localExcluded.includes(contactId);
    },
    toggleExclude(contactId) {
      this.localExcluded = this.isExcluded(contactId)
        ? this.localExcluded.filter(id => id !== contactId)
        : [...this.localExcluded, contactId];
      // Si el tab actual se vacía por la última página, retrocede.
      const lastPage = Math.max(
        Math.ceil(this.currentTabContacts.length / this.pageSize),
        1
      );
      if (this.currentPage > lastPage) this.currentPage = lastPage;
    },
    reasonFor(contact) {
      if (this.activeTab === 'in_tracking') {
        return this.$t('BULK_TRACKING_ASSIGN.PREVIEW.REASON.IN_TRACKING');
      }
      if (contact.reason) {
        return this.$t(`BULK_TRACKING_ASSIGN.PREVIEW.REASON.${contact.reason}`);
      }
      return '';
    },
    contactValue(contact) {
      return contact.phone_number || contact.email || '—';
    },
    goBack() {
      this.$emit('update:excludedContactIds', this.localExcluded);
      this.$emit('close');
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="goBack">
    <div class="p-6 w-full max-w-2xl">
      <div class="mb-4">
        <h2 class="text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('BULK_TRACKING_ASSIGN.PREVIEW.TITLE') }}
        </h2>
        <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
          {{ $t('BULK_TRACKING_ASSIGN.PREVIEW.AUDIENCE') }}: {{ total }}
          <template v-if="channel.inbox_name">
            · {{ $t('BULK_TRACKING_ASSIGN.PREVIEW.CHANNEL') }}:
            {{ channel.inbox_name }}
          </template>
        </p>
      </div>

      <div v-if="isLoading" class="py-12 text-center text-sm text-slate-400">
        {{ $t('BULK_TRACKING_ASSIGN.PREVIEW.LOADING') }}
      </div>

      <template v-else>
        <!-- Tabs -->
        <div
          class="flex gap-1 border-b border-slate-100 dark:border-slate-700 mb-3"
        >
          <button
            v-for="tab in tabs"
            :key="tab.key"
            type="button"
            class="px-3 py-2 text-sm font-medium border-b-2 -mb-px transition-colors"
            :class="
              activeTab === tab.key
                ? 'border-woot-500 text-woot-600 dark:text-woot-400'
                : 'border-transparent text-slate-500 hover:text-slate-700 dark:hover:text-slate-300'
            "
            @click="onTabChange(tab.key)"
          >
            {{ tab.label }}
            <span
              class="ml-1 px-1.5 py-0.5 rounded-full text-xs bg-slate-100 dark:bg-slate-700"
            >
              {{ tab.count }}
            </span>
          </button>
        </div>

        <!-- Tabla del tab activo -->
        <div
          class="border border-slate-100 dark:border-slate-700 rounded-md overflow-hidden"
        >
          <table class="min-w-full text-sm">
            <thead class="bg-slate-50 dark:bg-slate-800">
              <tr>
                <th
                  class="px-3 py-2 text-left font-semibold text-slate-600 dark:text-slate-300"
                >
                  {{ $t('BULK_TRACKING_ASSIGN.PREVIEW.COL_NAME') }}
                </th>
                <th
                  class="px-3 py-2 text-left font-semibold text-slate-600 dark:text-slate-300"
                >
                  {{ $t('BULK_TRACKING_ASSIGN.PREVIEW.COL_CONTACT') }}
                </th>
                <th
                  v-if="
                    activeTab === 'unreachable' || activeTab === 'in_tracking'
                  "
                  class="px-3 py-2 text-left font-semibold text-slate-600 dark:text-slate-300"
                >
                  {{ $t('BULK_TRACKING_ASSIGN.PREVIEW.COL_REASON') }}
                </th>
                <th
                  class="px-3 py-2 text-right font-semibold text-slate-600 dark:text-slate-300 w-28"
                >
                  {{ $t('BULK_TRACKING_ASSIGN.PREVIEW.COL_ACTION') }}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100 dark:divide-slate-700">
              <tr v-if="!currentTabContacts.length">
                <td colspan="4" class="px-3 py-8 text-center text-slate-400">
                  {{ $t('BULK_TRACKING_ASSIGN.PREVIEW.EMPTY_TAB') }}
                </td>
              </tr>
              <tr v-for="contact in paginatedContacts" :key="contact.id">
                <td class="px-3 py-2">
                  <div class="flex items-center gap-2">
                    <Thumbnail
                      :src="contact.thumbnail"
                      :username="contact.name"
                      size="24px"
                    />
                    <span class="text-slate-700 dark:text-slate-200">{{
                      contact.name
                    }}</span>
                  </div>
                </td>
                <td class="px-3 py-2 text-slate-500 dark:text-slate-400">
                  {{ contactValue(contact) }}
                </td>
                <td
                  v-if="
                    activeTab === 'unreachable' || activeTab === 'in_tracking'
                  "
                  class="px-3 py-2 text-slate-500 dark:text-slate-400"
                >
                  {{ reasonFor(contact) }}
                </td>
                <td class="px-3 py-2 text-right">
                  <woot-button
                    size="tiny"
                    :variant="isExcluded(contact.id) ? 'smooth' : 'clear'"
                    :color-scheme="isExcluded(contact.id) ? 'success' : 'alert'"
                    @click="toggleExclude(contact.id)"
                  >
                    {{
                      isExcluded(contact.id)
                        ? $t('BULK_TRACKING_ASSIGN.PREVIEW.UNDO')
                        : $t('BULK_TRACKING_ASSIGN.PREVIEW.EXCLUDE')
                    }}
                  </woot-button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <TableFooter
          :current-page="currentPage"
          :page-size="pageSize"
          :total-count="currentTabContacts.length"
          @page-change="onPageChange"
        />

        <p
          v-if="preview && preview.truncated"
          class="text-xs text-yellow-700 dark:text-yellow-300 mt-2"
        >
          {{
            $t('BULK_TRACKING_ASSIGN.PREVIEW.TRUNCATED', {
              limit: contacts.length,
              total,
            })
          }}
        </p>

        <div class="flex items-center justify-between mt-4">
          <span class="text-sm text-slate-600 dark:text-slate-300">
            {{
              $t('BULK_TRACKING_ASSIGN.PREVIEW.WILL_CREATE', {
                count: readyCount,
              })
            }}
          </span>
          <woot-button color-scheme="primary" @click="goBack">
            {{ $t('BULK_TRACKING_ASSIGN.PREVIEW.BACK') }}
          </woot-button>
        </div>
      </template>
    </div>
  </woot-modal>
</template>
