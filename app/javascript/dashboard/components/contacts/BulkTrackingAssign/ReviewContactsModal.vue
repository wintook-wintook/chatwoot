<!--
  ================================================================================
  proyecto@bulk_tracking_assign
  ================================================================================
  Componente: ReviewContactsModal.vue
  Descripción: Modal de revisión de contactos para asignación masiva de
               seguimientos. Lista paginada (reutiliza /contacts/filter) con
               opción de excluir/incluir contactos individuales.
  ================================================================================
-->

<script>
import contactAPI from 'dashboard/api/contacts';
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';

const PAGE_SIZE = 15;

export default {
  components: { Thumbnail, TableFooter },
  props: {
    show: { type: Boolean, default: false },
    filterPayload: { type: Array, default: () => [] },
    excludedContactIds: { type: Array, default: () => [] },
  },
  emits: ['close', 'update:excludedContactIds'],
  data() {
    return {
      contacts: [],
      totalCount: 0,
      currentPage: 1,
      pageSize: PAGE_SIZE,
      isLoading: false,
      localExcluded: [...this.excludedContactIds],
    };
  },
  computed: {
    selectedCount() {
      return Math.max(this.totalCount - this.localExcluded.length, 0);
    },
  },
  watch: {
    show(val) {
      if (val) {
        this.localExcluded = [...this.excludedContactIds];
        this.currentPage = 1;
        this.fetchContacts();
      }
    },
  },
  methods: {
    async fetchContacts() {
      this.isLoading = true;
      try {
        const { data } = await contactAPI.filter(this.currentPage, 'name', {
          payload: this.filterPayload,
        });
        this.contacts = data.payload;
        this.totalCount = data.meta.count;
      } finally {
        this.isLoading = false;
      }
    },
    onPageChange(page) {
      this.currentPage = page;
      this.fetchContacts();
    },
    isExcluded(contactId) {
      return this.localExcluded.includes(contactId);
    },
    toggleExclude(contactId) {
      this.localExcluded = this.isExcluded(contactId)
        ? this.localExcluded.filter(id => id !== contactId)
        : [...this.localExcluded, contactId];
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
          {{ $t('BULK_TRACKING_ASSIGN.REVIEW.TITLE') }}
        </h2>
        <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
          {{ selectedCount }} {{ $t('BULK_TRACKING_ASSIGN.REVIEW.OF') }}
          {{ totalCount }} {{ $t('BULK_TRACKING_ASSIGN.REVIEW.SELECTED') }}
        </p>
      </div>

      <div
        class="border border-slate-100 dark:border-slate-700 rounded-md overflow-hidden"
      >
        <table class="min-w-full text-sm">
          <thead class="bg-slate-50 dark:bg-slate-800">
            <tr>
              <th
                class="px-3 py-2 text-left font-semibold text-slate-600 dark:text-slate-300"
              >
                {{ $t('BULK_TRACKING_ASSIGN.REVIEW.COL_NAME') }}
              </th>
              <th
                class="px-3 py-2 text-left font-semibold text-slate-600 dark:text-slate-300"
              >
                {{ $t('BULK_TRACKING_ASSIGN.REVIEW.COL_PHONE') }}
              </th>
              <th
                class="px-3 py-2 text-right font-semibold text-slate-600 dark:text-slate-300 w-28"
              >
                {{ $t('BULK_TRACKING_ASSIGN.REVIEW.COL_ACTION') }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100 dark:divide-slate-700">
            <tr
              v-for="contact in contacts"
              :key="contact.id"
              :class="isExcluded(contact.id) ? 'opacity-40' : ''"
            >
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
                {{ contact.phone_number || '---' }}
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
                      ? $t('BULK_TRACKING_ASSIGN.REVIEW.UNDO')
                      : $t('BULK_TRACKING_ASSIGN.REVIEW.EXCLUDE')
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
        :total-count="totalCount"
        @page-change="onPageChange"
      />

      <div class="flex justify-end mt-4">
        <woot-button color-scheme="primary" @click="goBack">
          {{ $t('BULK_TRACKING_ASSIGN.REVIEW.BACK') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
