<!--
  ================================================================================
  @campanas_vendedor / proyecto@bulk_tracking_assign
  ================================================================================
  Componente: AudiencePreview.vue
  Descripción: Panel (no modal) que muestra la audiencia clasificada en TABS por
               bucket: Listos · Ya en seguimiento · No contactables · Excluidos.
               Es PRESENTACIONAL: recibe el resultado del preview y el set de
               excluidos por props, y emite `toggleExclude` al excluir/deshacer.
               La reclasificación se calcula en cliente con `excludedContactIds`.
  ================================================================================
-->

<script>
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';
import { sortRows, nextSort, sortArrow } from 'dashboard/helper/tableSort';

const PAGE_SIZE = 15;
const NATURAL_TABS = ['ready', 'in_tracking', 'unreachable'];
// Tabs que muestran la columna Motivo
const REASON_TABS = ['unreachable', 'in_tracking'];
const DEFAULT_SORT = { key: 'name', direction: 'asc' };

export default {
  components: { Thumbnail, TableFooter },
  props: {
    preview: { type: Object, default: null },
    isLoading: { type: Boolean, default: false },
    skipActive: { type: Boolean, default: true },
    excludedContactIds: { type: Array, default: () => [] },
  },
  emits: ['toggleExclude'],
  data() {
    return {
      activeTab: 'ready',
      currentPage: 1,
      pageSize: PAGE_SIZE,
      sort: { ...DEFAULT_SORT }, // clic en columna: ↑/↓
    };
  },
  computed: {
    contacts() {
      return this.preview?.contacts || [];
    },
    countsOnly() {
      return this.preview?.counts_only || false;
    },
    total() {
      return this.preview?.counts?.total || 0;
    },
    effectiveBucket() {
      return contact =>
        this.excludedContactIds.includes(contact.id)
          ? 'excluded'
          : contact.bucket;
    },
    countsByTab() {
      const counts = { ready: 0, in_tracking: 0, unreachable: 0, excluded: 0 };
      this.contacts.forEach(c => {
        counts[this.effectiveBucket(c)] += 1;
      });
      return counts;
    },
    tabs() {
      // Con skip_active=false el bucket "Ya en seguimiento" siempre es 0 → se oculta.
      const naturals = this.skipActive
        ? NATURAL_TABS
        : NATURAL_TABS.filter(k => k !== 'in_tracking');
      return [...naturals, 'excluded'].map(key => ({
        key,
        label: this.$t(
          `BULK_TRACKING_ASSIGN.PREVIEW.TABS.${key.toUpperCase()}`
        ),
        count: this.countsByTab[key],
      }));
    },
    // woot-tabs trabaja con índice; activeTab guarda la key del bucket.
    activeTabIndex() {
      const i = this.tabs.findIndex(t => t.key === this.activeTab);
      return i === -1 ? 0 : i;
    },
    showReason() {
      return REASON_TABS.includes(this.activeTab);
    },
    // Contactos del tab activo, ordenados por la columna elegida (sin valor, al final).
    currentTabContacts() {
      const inTab = this.contacts.filter(
        c => this.effectiveBucket(c) === this.activeTab
      );
      const sortValues = {
        name: c => c.name,
        contact: c => this.contactValue(c),
        reason: c => this.reasonFor(c),
      };
      return sortRows(inTab, sortValues[this.sort.key], this.sort.direction);
    },
    lastPage() {
      return Math.max(
        Math.ceil(this.currentTabContacts.length / this.pageSize),
        1
      );
    },
    paginatedContacts() {
      const start = (this.currentPage - 1) * this.pageSize;
      return this.currentTabContacts.slice(start, start + this.pageSize);
    },
  },
  watch: {
    // Un nuevo preview (cambió filtro/agente/skipActive) reinicia tab y página.
    preview() {
      this.activeTab = 'ready';
      this.currentPage = 1;
    },
    // Al excluir el último contacto de la última página, no quedarse en una vacía
    // (la lista se actualiza después del clic, cuando el padre cambia los excluidos).
    lastPage(page) {
      if (this.currentPage > page) this.currentPage = page;
    },
  },
  methods: {
    onTabChange(index) {
      const tab = this.tabs[index];
      if (!tab) return;
      this.activeTab = tab.key;
      this.currentPage = 1;
      // El tab nuevo no tiene columna Motivo: volver al orden por nombre.
      if (this.sort.key === 'reason' && !this.showReason) {
        this.sort = { ...DEFAULT_SORT };
      }
    },
    sortBy(key) {
      this.sort = nextSort(this.sort, key);
      this.currentPage = 1;
    },
    headerClass(key) {
      return this.sort.key === key
        ? 'text-woot-600'
        : 'text-slate-600 dark:text-slate-300';
    },
    columnHeader(key, labelKey) {
      const label = this.$t(`BULK_TRACKING_ASSIGN.PREVIEW.${labelKey}`);
      return `${label} ${sortArrow(this.sort, key)}`;
    },
    onPageChange(page) {
      this.currentPage = page;
    },
    isExcluded(contactId) {
      return this.excludedContactIds.includes(contactId);
    },
    toggleExclude(contactId) {
      this.$emit('toggleExclude', contactId);
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
  },
};
</script>

<template>
  <div>
    <div v-if="isLoading" class="py-12 text-center text-sm text-slate-400">
      {{ $t('BULK_TRACKING_ASSIGN.PREVIEW.LOADING') }}
    </div>

    <!-- Audiencia demasiado grande: solo total, sin clasificar -->
    <div
      v-else-if="countsOnly"
      class="my-2 p-4 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-md text-sm"
    >
      <p class="font-semibold text-yellow-800 dark:text-yellow-200">
        {{ $t('BULK_TRACKING_ASSIGN.PREVIEW.TOO_MANY_TITLE') }}
      </p>
      <p class="text-yellow-700 dark:text-yellow-300 mt-1">
        {{ $t('BULK_TRACKING_ASSIGN.PREVIEW.TOO_MANY_BODY', { total }) }}
      </p>
    </div>

    <template v-else>
      <!-- Tabs nativos -->
      <woot-tabs :index="activeTabIndex" class="mb-3" @change="onTabChange">
        <woot-tabs-item
          v-for="(tab, i) in tabs"
          :key="tab.key"
          :index="i"
          :name="tab.label"
          :count="tab.count"
          show-badge
        />
      </woot-tabs>

      <!-- Tabla del tab activo (overflow-x-auto: las columnas de la derecha se desplazan, no se cortan) -->
      <div
        class="border border-slate-100 dark:border-slate-700 rounded-md overflow-x-auto"
      >
        <table class="min-w-full text-sm">
          <thead class="bg-slate-50 dark:bg-slate-800">
            <tr>
              <!-- Clic: ordena ↑; otro clic: ↓ -->
              <th
                class="px-3 py-2 text-left font-semibold cursor-pointer select-none"
                :class="headerClass('name')"
                @click="sortBy('name')"
              >
                {{ columnHeader('name', 'COL_NAME') }}
              </th>
              <th
                class="px-3 py-2 text-left font-semibold cursor-pointer select-none"
                :class="headerClass('contact')"
                @click="sortBy('contact')"
              >
                {{ columnHeader('contact', 'COL_CONTACT') }}
              </th>
              <th
                v-if="showReason"
                class="px-3 py-2 text-left font-semibold cursor-pointer select-none"
                :class="headerClass('reason')"
                @click="sortBy('reason')"
              >
                {{ columnHeader('reason', 'COL_REASON') }}
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
                v-if="showReason"
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
        @pageChange="onPageChange"
      />
    </template>
  </div>
</template>
