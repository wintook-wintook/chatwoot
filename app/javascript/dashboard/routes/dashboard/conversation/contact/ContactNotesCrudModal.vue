<!--
  ============================================================
  proyecto@contacts_notes
  ============================================================
  Archivo: ContactNotesCrudModal.vue
  Descripción: Modal CRUD completo de notas del contacto.
               Muestra tabla con filtro, agregar, editar y borrar notas.
  Uso: ContactInfo.vue
  ============================================================
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { dateFormat } from 'shared/helpers/timeHelper';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';

export default {
  name: 'ContactNotesCrudModal',

  components: {
    WootMessageEditor,
    Thumbnail,
  },

  props: {
    show: { type: Boolean, default: false },
    contactId: { type: Number, required: true },
    contactName: { type: String, default: '' },
  },

  emits: ['close'],

  data() {
    return {
      filterText: '',
      filterOnlyIA: false,
      // Formulario de agregar
      showAddForm: false,
      addContent: '',
      isSaving: false,
      // Fila en edición
      editingNoteId: null,
      editContent: '',
      originalEditContent: '',
      editEditorKey: 0,
      isUpdating: false,
      // Confirm delete
      deletingNoteId: null,
      showDeleteConfirm: false,
      isDeleting: false,
      // Nota especial para IA
      isProcessingIA: false,
      // Paginación
      currentPage: 1,
      perPage: 5,
    };
  },

  computed: {
    ...mapGetters({ uiFlags: 'contactNotes/getUIFlags' }),

    notes() {
      const records = this.$store.state.contactNotes.records[this.contactId] || [];
      return [...records].sort((r1, r2) => r2.id - r1.id);
    },

    filteredNotes() {
      let notes = this.notes;
      if (this.filterOnlyIA) notes = notes.filter(n => n.is_for_ia);
      if (!this.filterText.trim()) return notes;
      const lower = this.filterText.toLowerCase();
      return notes.filter(n => {
        const inContent = (n.content || '').toLowerCase().includes(lower);
        const inUser = (n.user?.name || '').toLowerCase().includes(lower);
        return inContent || inUser;
      });
    },

    totalPages() {
      return Math.max(1, Math.ceil(this.filteredNotes.length / this.perPage));
    },

    pagedNotes() {
      const start = (this.currentPage - 1) * this.perPage;
      return this.filteredNotes.slice(start, start + this.perPage);
    },

    canPrevPage() {
      return this.currentPage > 1;
    },

    canNextPage() {
      return this.currentPage < this.totalPages;
    },

    canSaveNew() {
      return this.addContent.trim().length > 0;
    },
    fillerRows() {
      return Math.max(0, this.perPage - this.pagedNotes.length);
    },
    isFormOpen() {
      return this.showAddForm || this.editingNoteId !== null;
    },
    canEditSave() {
      const content = this.editContent || this.originalEditContent;
      return !!(content && content.trim());
    },
    iaNote() {
      return this.notes.find(n => n.is_for_ia) || null;
    },
    canProcessIA() {
      const text = this.stripHtml(this.editContent || this.originalEditContent);
      return text.split(/\s+/).filter(Boolean).length >= 50;
    },
  },

  watch: {
    show: {
      immediate: true,
      handler(val) {
        if (val) {
          this.resetForm();
          this.fetchNotes();
        }
      },
    },
    filterText() {
      this.currentPage = 1;
    },
  },

  methods: {
    dateFormat,

    fetchNotes() {
      this.$store.dispatch('contactNotes/get', { contactId: this.contactId });
    },

    resetForm() {
      this.filterText = '';
      this.filterOnlyIA = false;
      this.showAddForm = false;
      this.addContent = '';
      this.editingNoteId = null;
      this.editContent = '';
      this.originalEditContent = '';
      this.deletingNoteId = null;
      this.showDeleteConfirm = false;
      this.currentPage = 1;
    },

    // ── Agregar ────────────────────────────────────────────────
    openAddForm() {
      this.cancelEdit();
      this.showAddForm = true;
    },

    cancelAdd() {
      this.showAddForm = false;
      this.addContent = '';
    },

    async saveAdd() {
      if (!this.canSaveNew) return;
      this.isSaving = true;
      try {
        await this.$store.dispatch('contactNotes/create', {
          contactId: this.contactId,
          content: this.addContent,
        });
        await this.fetchNotes();
        useAlert(this.$t('NOTES.MODAL.CREATE_SUCCESS'));
        this.cancelAdd();
      } catch {
        useAlert(this.$t('NOTES.MODAL.ERROR'));
      } finally {
        this.isSaving = false;
      }
    },

    // ── Editar ─────────────────────────────────────────────────
    startEdit(note) {
      this.cancelAdd();
      this.originalEditContent = note.content || '';
      this.editContent = note.content || '';
      this.editingNoteId = note.id;
      this.editEditorKey += 1; // fuerza remontaje limpio del editor
    },

    cancelEdit() {
      this.editingNoteId = null;
      this.editContent = '';
      this.originalEditContent = '';
    },

    // El editor puede emitir un string vacío al montarse antes de tener el contenido.
    // Ignoramos esa emisión vacía y preservamos el contenido original como fallback.
    handleEditInput(value) {
      if (value && value.trim()) {
        this.editContent = value;
      }
    },

    async saveEdit() {
      const content = this.editContent || this.originalEditContent;
      if (!content || !content.trim()) return;
      this.isUpdating = true;
      try {
        const isIaNoteBeingEdited = this.iaNote && this.iaNote.id === this.editingNoteId;
        await this.$store.dispatch('contactNotes/update', {
          contactId: this.contactId,
          noteId: this.editingNoteId,
          content,
          isForIa: isIaNoteBeingEdited ? true : undefined,
        });
        await this.fetchNotes();
        useAlert(this.$t('NOTES.MODAL.UPDATE_SUCCESS'));
        this.cancelEdit();
      } catch (error) {
        useAlert(this.$t('NOTES.MODAL.ERROR'));
      } finally {
        this.isUpdating = false;
      }
    },

    // ── Nota especial para IA ──────────────────────────────────
    async toggleSpecial(note) {
      const newValue = !note.is_for_ia;
      try {
        await this.$store.dispatch('contactNotes/toggleSpecial', {
          contactId: this.contactId,
          noteId: note.id,
          isForIa: newValue,
        });
        await this.fetchNotes();
      } catch {
        useAlert(this.$t('NOTES.MODAL.ERROR'));
      }
    },

    async processForIA() {
      if (!this.editingNoteId || this.isProcessingIA) return;
      this.isProcessingIA = true;
      try {
        const text = this.editContent || this.originalEditContent;
        const response = await this.$store.dispatch('contactTrackings/improveText', {
          contactId: this.contactId,
          text,
          mode: 'process_contact_context',
        });
        if (response?.improved_text) {
          this.editContent = response.improved_text;
          this.editEditorKey += 1;
        }
      } catch {
        useAlert(this.$t('NOTES.MODAL.ERROR'));
      } finally {
        this.isProcessingIA = false;
      }
    },

    // ── Borrar ─────────────────────────────────────────────────
    askDelete(noteId) {
      this.deletingNoteId = noteId;
      this.showDeleteConfirm = true;
    },

    cancelDelete() {
      this.deletingNoteId = null;
      this.showDeleteConfirm = false;
    },

    async confirmDelete() {
      this.isDeleting = true;
      try {
        await this.$store.dispatch('contactNotes/delete', {
          contactId: this.contactId,
          noteId: this.deletingNoteId,
        });
        useAlert(this.$t('DELETE_NOTE.CONFIRM.SUCCESS'));
        this.cancelDelete();
        // Si la página actual queda vacía tras el borrado, retroceder
        if (this.currentPage > this.totalPages) {
          this.currentPage = this.totalPages;
        }
      } catch {
        useAlert(this.$t('NOTES.MODAL.ERROR'));
      } finally {
        this.isDeleting = false;
      }
    },

    onClose() {
      this.resetForm();
      this.$emit('close');
    },

    stripHtml(text) {
      if (!text) return '';
      return text.replace(/<[^>]+>/g, '').replace(/&[^;]+;/g, ' ').trim();
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="onClose" size="medium">
    <div class="flex flex-col p-6 gap-4">
      <!-- Header -->
      <woot-modal-header
        :header-title="$t('NOTES.CRUD_MODAL.TITLE', { name: contactName })"
        :header-content="$t('NOTES.CRUD_MODAL.SUBTITLE')"
      />

      <!-- Área principal: tabla / agregar / editar con transición sin parpadeo -->
      <!-- notes-area fija el alto mínimo para que todas las vistas tengan el mismo tamaño -->
      <div class="notes-area">
      <transition name="view-switch" mode="out-in">

        <!-- VISTA: Tabla -->
        <div v-if="!isFormOpen" key="table" class="flex flex-col">
          <!-- Barra: filtro + botón agregar -->
          <div class="flex items-center gap-2 mb-0">
            <div class="relative flex-1">
              <fluent-icon
                icon="search"
                size="16"
                class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none"
              />
              <input
                v-model="filterText"
                type="text"
                :placeholder="$t('NOTES.CRUD_MODAL.FILTER_PLACEHOLDER')"
                class="w-full pl-9 pr-3 py-2 text-sm border border-slate-200 dark:border-slate-700 rounded-md bg-white dark:bg-slate-900 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-woot-500"
              />
            </div>
            <div class="flex items-center gap-2 shrink-0 self-start">
              <woot-button
                v-tooltip="$t('NOTES.CRUD_MODAL.FILTER_IA_TOOLTIP')"
                icon="chatwoot-ai"
                variant="smooth"
                :color-scheme="filterOnlyIA ? 'success' : 'alert'"
                @click="filterOnlyIA = !filterOnlyIA"
              />
              <woot-button
                v-tooltip="$t('NOTES.CRUD_MODAL.REFRESH_TOOLTIP')"
                icon="arrow-clockwise"
                variant="smooth"
                color-scheme="secondary"
                :is-loading="uiFlags.isFetching"
                @click="fetchNotes"
              />
              <woot-button
                icon="add"
                color-scheme="primary"
                @click="openAddForm"
              >
                {{ $t('NOTES.CRUD_MODAL.ADD_BUTTON') }}
              </woot-button>
            </div>
          </div>

          <!-- Tabla -->
          <table class="min-w-full divide-y divide-slate-75 dark:divide-slate-700">
            <thead>
              <tr class="bg-slate-50 dark:bg-slate-800 text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wide">
                <th class="px-4 py-2 text-left">{{ $t('NOTES.CRUD_MODAL.COL_CONTENT') }}</th>
                <th class="px-4 py-2 text-left w-36">{{ $t('NOTES.CRUD_MODAL.COL_USER') }}</th>
                <th class="px-4 py-2 text-left w-28">{{ $t('NOTES.CRUD_MODAL.COL_DATE') }}</th>
                <th class="px-4 py-2 text-center w-8">IA</th>
                <th class="px-4 py-2 text-center w-20">{{ $t('NOTES.CRUD_MODAL.COL_ACTIONS') }}</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-50 dark:divide-slate-800">
              <tr v-if="!uiFlags.isFetching && !filteredNotes.length">
                <td colspan="4" class="py-10 text-center">
                  <div class="flex flex-col items-center gap-2 text-slate-400 dark:text-slate-500">
                    <fluent-icon icon="document" size="32" />
                    <span class="text-sm">
                      {{ filterText ? $t('NOTES.CRUD_MODAL.NO_RESULTS') : $t('NOTES.NOT_AVAILABLE') }}
                    </span>
                  </div>
                </td>
              </tr>

              <template v-else>
                <tr
                  v-for="note in pagedNotes"
                  :key="note.id"
                  class="hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors"
                >
                  <td class="px-4 py-3 text-sm text-slate-700 dark:text-slate-200 max-w-0">
                    <div class="truncate" :title="stripHtml(note.content)">
                      {{ stripHtml(note.content) }}
                    </div>
                  </td>
                  <td class="px-4 py-3">
                    <div class="flex items-center gap-1.5">
                      <Thumbnail
                        v-if="note.user"
                        :src="note.user.thumbnail"
                        :username="note.user.name || $t('APP_GLOBAL.DELETED_USER')"
                        size="20px"
                      />
                      <span class="text-xs text-slate-600 dark:text-slate-300 truncate">
                        {{ (note.user && note.user.name) || $t('APP_GLOBAL.DELETED_USER') }}
                      </span>
                    </div>
                  </td>
                  <td class="px-4 py-3 text-xs text-slate-500 dark:text-slate-400">
                    {{ dateFormat(note.created_at, 'dd/MM/yyyy') }}
                  </td>
                  <td class="px-4 py-3 text-center">
                    <woot-button
                      v-tooltip="note.is_for_ia ? $t('NOTES.CRUD_MODAL.UNMARK_IA') : $t('NOTES.CRUD_MODAL.MARK_IA')"
                      variant="clear"
                      size="small"
                      icon="chatwoot-ai"
                      :color-scheme="note.is_for_ia ? 'success' : 'alert'"
                      @click="toggleSpecial(note)"
                    />
                  </td>
                  <td class="px-4 py-3">
                    <div class="flex items-center justify-center gap-1">
                      <woot-button
                        v-tooltip="$t('NOTES.CONTENT_HEADER.EDIT')"
                        variant="smooth"
                        size="tiny"
                        icon="edit"
                        color-scheme="secondary"
                        @click="startEdit(note)"
                      />
                      <woot-button
                        v-tooltip="$t('NOTES.CONTENT_HEADER.DELETE')"
                        variant="smooth"
                        size="tiny"
                        icon="delete"
                        color-scheme="alert"
                        @click="askDelete(note.id)"
                      />
                    </div>
                  </td>
                </tr>

                <!-- Filas vacías para mantener el alto fijo de 5 filas -->
                <tr
                  v-for="i in fillerRows"
                  :key="'filler-' + i"
                >
                  <td class="px-4 py-3" colspan="4">&nbsp;</td>
                </tr>
              </template>
            </tbody>
          </table>

          <!-- Paginación -->
          <div
            v-if="!uiFlags.isFetching && filteredNotes.length > 0"
            class="flex items-center justify-between mt-3"
          >
            <span class="text-xs text-slate-400 dark:text-slate-500">
              {{ $t('NOTES.CRUD_MODAL.COUNT', { count: filteredNotes.length, total: notes.length }) }}
            </span>
            <div class="flex items-center gap-1">
              <woot-button
                variant="smooth"
                size="tiny"
                icon="chevron-left"
                color-scheme="secondary"
                :is-disabled="!canPrevPage"
                @click="currentPage -= 1"
              />
              <span class="text-xs text-slate-600 dark:text-slate-300 px-2">
                {{ currentPage }} / {{ totalPages }}
              </span>
              <woot-button
                variant="smooth"
                size="tiny"
                icon="chevron-right"
                color-scheme="secondary"
                :is-disabled="!canNextPage"
                @click="currentPage += 1"
              />
            </div>
          </div>
        </div>

        <!-- VISTA: Agregar nota -->
        <div
          v-else-if="showAddForm"
          key="add"
          class="rounded-md border border-solid border-woot-200 dark:border-woot-700 bg-woot-25 dark:bg-slate-800 p-4 flex flex-col gap-3"
        >
          <p class="text-sm font-semibold text-woot-700 dark:text-woot-300 m-0">
            {{ $t('NOTES.CRUD_MODAL.NEW_NOTE_LABEL') }}
          </p>
          <div class="flex-1 rounded-md border border-solid border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 overflow-hidden">
            <WootMessageEditor
              v-model="addContent"
              class="input--note"
              :placeholder="$t('NOTES.ADD.PLACEHOLDER')"
              :enable-suggestions="false"
            />
          </div>
          <div class="flex justify-end gap-2">
            <woot-button variant="clear" color-scheme="secondary" size="small" @click="cancelAdd">
              Regresar
            </woot-button>
            <woot-button
              size="small"
              color-scheme="primary"
              :is-loading="isSaving"
              :is-disabled="!canSaveNew"
              @click="saveAdd"
            >
              Guardar Nota
            </woot-button>
          </div>
        </div>

        <!-- VISTA: Editar nota -->
        <div
          v-else
          key="edit"
          class="rounded-md border border-solid border-yellow-300 dark:border-yellow-700 bg-yellow-50 dark:bg-slate-800 p-4 flex flex-col gap-3"
        >
          <p class="text-sm font-semibold text-yellow-700 dark:text-yellow-400 m-0">
            {{ $t('NOTES.CONTENT_HEADER.EDIT') }}
          </p>
          <div class="flex-1 rounded-md border border-solid border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 overflow-hidden">
            <WootMessageEditor
              :key="editEditorKey"
              :value="editContent"
              class="input--note"
              :enable-suggestions="false"
              :focus-on-mount="false"
              @input="handleEditInput"
            />
          </div>
          <div class="flex items-center justify-between gap-2">
            <woot-button
              v-if="iaNote && iaNote.id === editingNoteId"
              v-tooltip="$t('NOTES.CRUD_MODAL.PROCESS_IA_TOOLTIP')"
              size="small"
              icon="chatwoot-ai"
              variant="smooth"
              color-scheme="warning"
              :is-loading="isProcessingIA"
              :is-disabled="!canProcessIA"
              @click="processForIA"
            >
              {{ $t('NOTES.CRUD_MODAL.PROCESS_IA_BUTTON') }}
            </woot-button>
            <div v-else />
            <div class="flex items-center gap-2">
              <woot-button variant="clear" color-scheme="secondary" size="small" @click="cancelEdit">
                Regresar
              </woot-button>
              <woot-button
                size="small"
                color-scheme="warning"
                :is-loading="isUpdating"
                :is-disabled="!canEditSave"
                @click="saveEdit"
              >
                Guardar Cambios
              </woot-button>
            </div>
          </div>
        </div>

      </transition>
      </div>

      <!-- Footer -->
      <div class="flex justify-end pt-2 border-t border-slate-200 dark:border-slate-700">
        <woot-button variant="clear" color-scheme="secondary" @click="onClose">
          {{ $t('NOTES.MODAL.CANCEL') }}
        </woot-button>
      </div>
    </div>

    <!-- Modal confirmación borrar -->
    <woot-delete-modal
      v-if="showDeleteConfirm"
      :show.sync="showDeleteConfirm"
      :on-close="cancelDelete"
      :on-confirm="confirmDelete"
      :title="$t('DELETE_NOTE.CONFIRM.TITLE')"
      :message="$t('DELETE_NOTE.CONFIRM.MESSAGE')"
      :confirm-text="$t('DELETE_NOTE.CONFIRM.YES')"
      :reject-text="$t('DELETE_NOTE.CONFIRM.NO')"
    />
  </woot-modal>
</template>

<style lang="scss" scoped>
// Wrapper que fija la altura mínima del área de contenido del modal.
// Todas las vistas (tabla, agregar, editar) ocupan el mismo espacio.
.notes-area {
  display: flex;
  flex-direction: column;
  height: 25rem; // altura fija para que el modal no salte al recargar

  // <transition> no renderiza un elemento DOM en Vue 2,
  // así que los hijos directos son los paneles de vista.
  // flex: 1 hace que cada panel llene el espacio disponible.
  > div {
    flex: 1;
    display: flex;
    flex-direction: column;
  }
}

.input--note {
  height: 100%;

  &::v-deep .ProseMirror-menubar {
    padding: var(--space-small) var(--space-normal);
    border-bottom: 1px solid var(--color-border-light);
  }

  &::v-deep .ProseMirror-woot-style {
    min-height: 10rem;
    max-height: none; // sin límite: el editor crece hasta llenar el panel
    padding: var(--space-normal);
  }
}

// Vue 2: clases de transición correctas (enter, no enter-from)
.view-switch-enter-active {
  transition: opacity 0.18s ease-out, transform 0.18s ease-out;
}

.view-switch-leave-active {
  transition: opacity 0.12s ease-in, transform 0.12s ease-in;
}

.view-switch-enter,
.view-switch-leave-to {
  opacity: 0;
  transform: translateY(6px);
}
</style>
