<!-- @knowledge_sources -->
<!-- Pagina principal del modulo Base de Conocimiento. -->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SourceCard from './SourceCard.vue';
import AddSourceModal from './AddSourceModal.vue';
import KnowledgeBaseAPI from './api';

export default {
  name: 'KnowledgeSourcesIndex',
  components: { BaseSettingsHeader, SourceCard, AddSourceModal },
  data() {
    return {
      sources: [],
      items: [],
      loadingSources: false,
      loadingItems: false,
      showAddModal: false,
      editingSource: null,
      saving: false,
      showDeleteModal: false,
      deletingSource: null,
      syncPollTimer: null,
      syncingId: null,
      activeTab: 0,
      searchQuery: '',
      filterSourceId: '',
      filterCategoryId: '',
      filterCategories: [],
      currentPage: 1,
      itemsPerPage: 5,
      totalItems: 0,
      testQuery: '',
      testLimit: 5,
      testThreshold: 0.3,
      testResults: [],
      testSearching: false,
      testSearched: false,
      viewingResult: null,
      kbaseSettings: {
        similarity_threshold: 0.60,
        max_results: 5,
        max_context_chars: 2000,
      },
      kbaseSettingsSaving: false,
      kbaseSettingsLoading: false,
    };
  },
  computed: {
    ...mapGetters({ currentUser: 'getCurrentUser' }),
    accountId() {
      return this.currentUser.account_id;
    },
    tabs() {
      return [
        { name: 'Contenido indexado' },
        { name: `Fuentes (${this.sources.length})` },
        { name: 'Prueba de búsqueda' },
        { name: 'Configuración' },
      ];
    },
    filteredItems() {
      return this.items;
    },
    totalPages() {
      return Math.max(1, Math.ceil(this.totalItems / this.itemsPerPage));
    },
    paginationFrom() {
      return this.totalItems === 0 ? 0 : (this.currentPage - 1) * this.itemsPerPage + 1;
    },
    paginationTo() {
      return Math.min(this.currentPage * this.itemsPerPage, this.totalItems);
    },
    sourceTypeLabel() {
      return type =>
        ({
          canned_response: 'Respuesta predefinida',
          article: 'Centro de Ayuda',
        }[type] || 'Discourse');
    },
    sourceTypeIcon() {
      return type =>
        ({
          canned_response: 'chat-multiple',
          article: 'library',
        }[type] || 'globe');
    },
    sourceById() {
      return Object.fromEntries(this.sources.map(s => [s.id, s]));
    },
    selectedSourceIsDiscourse() {
      if (!this.filterSourceId) return false;
      const src = this.sources.find(s => s.id === Number(this.filterSourceId));
      return src?.source_type === 'discourse';
    },
    formatDate() {
      return iso => {
        if (!iso) return '—';
        return new Date(iso).toLocaleString('es-MX', {
          day: '2-digit', month: '2-digit', year: '2-digit',
          hour: '2-digit', minute: '2-digit',
        });
      };
    },
    similarityColor() {
      return score => {
        if (score >= 0.6) return 'text-green-600 bg-green-50';
        if (score >= 0.4) return 'text-yellow-600 bg-yellow-50';
        return 'text-slate-500 bg-slate-50';
      };
    },
    similarityBar() {
      return score => Math.round(score * 100);
    },
  },
  watch: {
    activeTab(val) {
      if (val === 2) this.clearTest();
      if (val === 3) this.fetchSearchSettings();
    },
  },
  mounted() {
    this.fetchSources();
    this.fetchItems();
  },
  beforeUnmount() {
    this.stopSyncPolling();
  },
  methods: {
    async fetchSources() {
      this.loadingSources = true;
      try {
        const { data } = await KnowledgeBaseAPI.getSources(this.accountId);
        this.sources = data;
        this.manageSyncPolling();
      } catch {
        useAlert('Error al cargar las fuentes');
      } finally {
        this.loadingSources = false;
      }
    },
    manageSyncPolling() {
      const anySyncing = this.sources.some(s => s.sync_status === 'syncing');
      if (anySyncing && !this.syncPollTimer) {
        this.syncPollTimer = setInterval(async () => {
          const { data } = await KnowledgeBaseAPI.getSources(this.accountId);
          this.sources = data;
          if (!data.some(s => s.sync_status === 'syncing')) {
            this.stopSyncPolling();
          }
        }, 4000);
      } else if (!anySyncing) {
        this.stopSyncPolling();
      }
    },
    stopSyncPolling() {
      if (this.syncPollTimer) {
        clearInterval(this.syncPollTimer);
        this.syncPollTimer = null;
      }
    },
    async fetchItems() {
      this.loadingItems = true;
      try {
        const { data } = await KnowledgeBaseAPI.getItems(this.accountId, {
          page: this.currentPage,
          per_page: this.itemsPerPage,
          search: this.searchQuery || undefined,
          knowledge_source_id: this.filterSourceId || undefined,
          category_id: this.filterCategoryId || undefined,
        });
        this.items = data.items || data;
        this.totalItems = data.total || this.items.length;
      } catch {
        useAlert('Error al cargar el contenido indexado');
      } finally {
        this.loadingItems = false;
      }
    },
    async onSaveSource(payload) {
      this.saving = true;
      try {
        if (this.editingSource) {
          const { data } = await KnowledgeBaseAPI.updateSource(this.accountId, this.editingSource.id, payload);
          const idx = this.sources.findIndex(s => s.id === this.editingSource.id);
          if (idx !== -1) this.sources.splice(idx, 1, data);
          useAlert('Fuente actualizada correctamente');
        } else {
          const { data } = await KnowledgeBaseAPI.createSource(this.accountId, payload);
          this.sources.push(data);
          useAlert('Fuente agregada correctamente');
        }
        this.showAddModal = false;
        this.editingSource = null;
      } catch {
        useAlert(this.editingSource ? 'Error al actualizar la fuente' : 'Error al agregar la fuente');
      } finally {
        this.saving = false;
      }
    },
    onEditSource(source) {
      this.editingSource = source;
      this.showAddModal = true;
    },
    async onSync(source) {
      this.syncingId = source.id;
      try {
        await KnowledgeBaseAPI.syncSource(this.accountId, source.id);
        useAlert('Sincronizacion iniciada — los items apareceran en unos momentos');
        await this.fetchSources();
        setTimeout(() => this.fetchItems(), 3000);
      } catch (error) {
        useAlert(
          error?.response?.data?.error || 'Error al sincronizar la fuente'
        );
      } finally {
        this.syncingId = null;
      }
    },
    onDelete(source) {
      this.deletingSource = source;
      this.showDeleteModal = true;
    },
    closeDeleteModal() {
      this.showDeleteModal = false;
      this.deletingSource = null;
    },
    async confirmDelete() {
      if (!this.deletingSource) return;
      try {
        await KnowledgeBaseAPI.deleteSource(this.accountId, this.deletingSource.id);
        this.sources = this.sources.filter(s => s.id !== this.deletingSource.id);
        await this.fetchItems();
        useAlert('Fuente eliminada correctamente');
      } catch {
        useAlert('Error al eliminar la fuente');
      } finally {
        this.closeDeleteModal();
      }
    },
    onSearch() {
      this.currentPage = 1;
      this.fetchItems();
    },
    async onFilterSource() {
      this.filterCategoryId = '';
      this.filterCategories = [];
      this.currentPage = 1;
      this.fetchItems();
      if (this.filterSourceId) {
        const { data } = await KnowledgeBaseAPI.getItemCategories(this.accountId, this.filterSourceId);
        this.filterCategories = data.categories || [];
      }
    },
    onFilterCategory() {
      this.currentPage = 1;
      this.fetchItems();
    },
    goToPage(page) {
      if (page < 1 || page > this.totalPages) return;
      this.currentPage = page;
      this.fetchItems();
    },
    pageNumbers() {
      const total = this.totalPages;
      const current = this.currentPage;
      const max = 5;
      const count = Math.min(max, total);
      const start = Math.max(1, Math.min(current - Math.floor(max / 2), total - count + 1));
      return Array.from({ length: count }, (_, i) => start + i);
    },
    async runTestSearch() {
      if (!this.testQuery.trim()) return;
      this.testSearching = true;
      this.testResults = [];
      try {
        const { data } = await KnowledgeBaseAPI.search(
          this.accountId,
          this.testQuery,
          { limit: this.testLimit, threshold: this.testThreshold }
        );
        this.testResults = data.results || [];
        this.testSearched = true;
      } catch {
        useAlert('Error al realizar la búsqueda semántica');
      } finally {
        this.testSearching = false;
      }
    },
    clearTest() {
      this.testQuery = '';
      this.testResults = [];
      this.testSearched = false;
    },
    async fetchSearchSettings() {
      this.kbaseSettingsLoading = true;
      try {
        const { data } = await KnowledgeBaseAPI.getSearchSettings(this.accountId);
        this.kbaseSettings = { ...data };
      } catch {
        useAlert('Error al cargar la configuración');
      } finally {
        this.kbaseSettingsLoading = false;
      }
    },
    async saveSearchSettings() {
      this.kbaseSettingsSaving = true;
      try {
        await KnowledgeBaseAPI.updateSearchSettings(this.accountId, this.kbaseSettings);
        useAlert('Configuración guardada correctamente');
      } catch {
        useAlert('Error al guardar la configuración');
      } finally {
        this.kbaseSettingsSaving = false;
      }
    },
  },
};
</script>

<template>
  <div class="flex-1 overflow-auto">
    <BaseSettingsHeader
      :title="$t('KNOWLEDGE_SOURCES.TITLE')"
      :description="$t('KNOWLEDGE_SOURCES.DESCRIPTION')"
      feature-name="knowledge_sources"
    >
      <template #actions>
        <woot-button icon="add-circle" @click="showAddModal = true">
          Agregar Fuente
        </woot-button>
      </template>
    </BaseSettingsHeader>

    <div class="p-6 flex flex-col gap-6">

      <!-- Tabs -->
      <woot-tabs :index="activeTab" @change="activeTab = $event">
        <woot-tabs-item
          v-for="tab in tabs"
          :key="tab.name"
          :name="tab.name"
          :show-badge="false"
        />
      </woot-tabs>

      <!-- Tab: Contenido indexado -->
      <div v-if="activeTab === 0">
        <div class="mb-4 flex gap-2 flex-wrap">
          <select
            v-model="filterSourceId"
            class="input w-52"
            @change="onFilterSource"
          >
            <option value="">Todas las fuentes</option>
            <option v-for="s in sources" :key="s.id" :value="s.id">
              {{ s.name }}
            </option>
          </select>

          <select
            v-model="filterCategoryId"
            class="input w-48"
            @change="onFilterCategory"
          >
            <option value="">Todas las categorías</option>
            <option v-for="cat in filterCategories" :key="cat.id" :value="cat.id">
              {{ cat.name }}
            </option>
          </select>
          <input
            v-model="searchQuery"
            type="text"
            class="input flex-1 min-w-[160px]"
            placeholder="Buscar en el contenido indexado..."
            @keydown.enter="onSearch"
          />
          <woot-button icon="search" @click="onSearch">
            Buscar
          </woot-button>
        </div>

        <!-- Loading -->
        <div v-if="loadingItems" class="flex justify-center py-12">
          <span class="text-slate-400">Cargando contenido...</span>
        </div>

        <!-- Empty -->
        <div
          v-else-if="items.length === 0"
          class="flex flex-col items-center justify-center py-16 gap-3"
        >
          <fluent-icon icon="library" size="40" class="text-slate-300" />
          <p class="text-slate-500 text-sm">No hay contenido indexado aun</p>
          <p class="text-slate-400 text-xs">Agrega una fuente y sincroniza, o crea una Respuesta Predefinida</p>
        </div>

        <!-- Tabla -->
        <template v-else>
          <div class="overflow-x-auto rounded-lg border border-slate-200">
            <table class="w-full min-w-[860px]">
              <thead>
                <tr class="bg-slate-50 border-b border-slate-200">
                  <th class="text-left px-3 py-3 text-sm font-semibold text-slate-500 w-8"></th>
                  <th class="text-left px-3 py-3 text-sm font-semibold text-slate-500">Título</th>
                  <th class="text-left px-3 py-3 text-sm font-semibold text-slate-500">Contenido</th>
                  <th class="text-left px-3 py-3 text-sm font-semibold text-slate-500 w-24">Categoría</th>
                  <th class="text-left px-3 py-3 text-sm font-semibold text-slate-500 w-36">Tipo</th>
                  <th class="text-left px-3 py-3 text-sm font-semibold text-slate-500 w-32">Creado</th>
                  <th class="text-left px-3 py-3 text-sm font-semibold text-slate-500 w-32">Actualizado</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <tr
                  v-for="item in filteredItems"
                  :key="item.id"
                  class="bg-white hover:bg-slate-50 transition-colors cursor-pointer"
                  @click="viewingResult = item"
                >
                  <td class="px-3 py-3">
                    <fluent-icon
                      :icon="sourceTypeIcon(item.source_type)"
                      size="16"
                      class="text-slate-400"
                    />
                  </td>
                  <td class="px-3 py-3 font-medium text-slate-700 text-sm max-w-[180px] truncate">
                    {{ item.title || '—' }}
                  </td>
                  <td class="px-3 py-3 text-slate-500 text-sm max-w-[260px]">
                    <span class="line-clamp-2 leading-relaxed">{{ item.content }}</span>
                  </td>
                  <td class="px-3 py-3">
                    <span
                      v-if="item.metadata && item.metadata.category"
                      class="inline-flex items-center gap-1 text-sm text-slate-500"
                    >
                      <fluent-icon icon="folder" size="12" />
                      {{ item.metadata.category_name || item.metadata.category }}
                    </span>
                    <span v-else class="text-sm text-slate-300">—</span>
                  </td>
                  <td class="px-3 py-3">
                    <span class="inline-flex items-center px-2 py-0.5 rounded text-sm font-medium bg-slate-100 text-slate-600">
                      {{ sourceTypeLabel(item.source_type) }}
                    </span>
                  </td>
                  <td class="px-3 py-3 text-sm text-slate-400">
                    {{ formatDate(item.created_at) }}
                  </td>
                  <td class="px-3 py-3 text-sm text-slate-400">
                    {{ formatDate(item.updated_at) }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <!-- Paginación -->
          <div class="flex items-center justify-between mt-4 px-1">
            <p class="text-sm text-slate-400">
              {{ paginationFrom }}–{{ paginationTo }} de {{ totalItems }} registros
            </p>
            <div class="flex items-center gap-2">
              <button
                class="px-3 py-1.5 rounded border border-slate-200 text-sm text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
                :disabled="currentPage === 1"
                @click="goToPage(currentPage - 1)"
              >
                Anterior
              </button>
              <span class="text-sm text-slate-500">
                Página {{ currentPage }} de {{ totalPages }}
              </span>
              <button
                class="px-3 py-1.5 rounded border border-slate-200 text-sm text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
                :disabled="currentPage === totalPages"
                @click="goToPage(currentPage + 1)"
              >
                Siguiente
              </button>
            </div>
          </div>
        </template>
      </div>

      <!-- Tab: Fuentes -->
      <div v-if="activeTab === 1">
        <div v-if="loadingSources" class="flex justify-center py-12">
          <span class="text-slate-400">Cargando fuentes...</span>
        </div>

        <div
          v-else-if="sources.length === 0"
          class="flex flex-col items-center justify-center py-16 gap-3"
        >
          <fluent-icon icon="library" size="40" class="text-slate-300" />
          <p class="text-slate-500 text-sm">No hay fuentes configuradas manualmente</p>
          <p class="text-slate-400 text-xs">Las fuentes de Respuestas Predefinidas se crean automaticamente al sincronizar</p>
        </div>

        <div v-else class="grid gap-4" style="grid-template-columns: repeat(auto-fill, minmax(280px, 1fr))">
          <SourceCard
            v-for="source in sources"
            :key="source.id"
            :source="source"
            :syncing="syncingId === source.id"
            @sync="onSync"
            @edit="onEditSource"
            @delete="onDelete"
          />
        </div>
      </div>

      <!-- Tab: Configuración -->
      <div v-if="activeTab === 3">
        <div v-if="kbaseSettingsLoading" class="flex justify-center py-12">
          <span class="text-slate-400 text-sm">Cargando configuración...</span>
        </div>

        <div v-else class="max-w-lg flex flex-col gap-6">
          <p class="text-sm text-slate-500">
            Estos valores se aplican a todas las búsquedas semánticas de esta cuenta al responder mensajes automáticamente.
          </p>

          <!-- Umbral de similitud -->
          <div class="bg-white border border-slate-200 rounded-xl p-5 flex flex-col gap-3">
            <div>
              <h3 class="text-sm font-semibold text-slate-700">Umbral de similitud</h3>
              <p class="text-xs text-slate-400 mt-0.5">
                Similitud mínima para que un resultado se considere relevante. Valores bajos incluyen más resultados; valores altos solo los más exactos.
              </p>
            </div>
            <div class="flex items-center gap-4">
              <input
                v-model.number="kbaseSettings.similarity_threshold"
                type="range"
                min="0.1"
                max="0.99"
                step="0.01"
                class="flex-1"
              />
              <span class="text-sm font-mono font-semibold text-woot-600 w-10 text-right">
                {{ kbaseSettings.similarity_threshold }}
              </span>
            </div>
            <div class="flex justify-between text-xs text-slate-400">
              <span>0.1 — más resultados</span>
              <span>0.99 — solo exactos</span>
            </div>
          </div>

          <!-- Resultados máximos -->
          <div class="bg-white border border-slate-200 rounded-xl p-5 flex flex-col gap-3">
            <div>
              <h3 class="text-sm font-semibold text-slate-700">Resultados máximos</h3>
              <p class="text-xs text-slate-400 mt-0.5">
                Cantidad máxima de fragmentos relevantes que se envían al modelo para generar la respuesta.
              </p>
            </div>
            <input
              v-model.number="kbaseSettings.max_results"
              type="number"
              min="1"
              max="20"
              class="input w-28"
            />
          </div>

          <!-- Caracteres de contexto -->
          <div class="bg-white border border-slate-200 rounded-xl p-5 flex flex-col gap-3">
            <div>
              <h3 class="text-sm font-semibold text-slate-700">Caracteres de contexto</h3>
              <p class="text-xs text-slate-400 mt-0.5">
                Límite de caracteres del contexto combinado que se entrega al modelo. Valores más altos permiten respuestas más ricas pero consumen más tokens.
              </p>
            </div>
            <input
              v-model.number="kbaseSettings.max_context_chars"
              type="number"
              min="500"
              max="10000"
              step="100"
              class="input w-36"
            />
          </div>

          <woot-button
            :loading="kbaseSettingsSaving"
            @click="saveSearchSettings"
          >
            Guardar configuración
          </woot-button>
        </div>
      </div>

      <!-- Tab: Prueba de búsqueda -->
      <div v-if="activeTab === 2">
        <div>

          <!-- Formulario -->
          <div class="bg-white border border-slate-200 rounded-xl px-4 py-3 flex flex-col gap-2">
            <div>
              <label class="block text-xs font-semibold text-slate-600 mb-1">Consulta</label>
              <div class="flex gap-2">
                <input
                  v-model="testQuery"
                  type="text"
                  class="input flex-1"
                  placeholder="Ej: problemas con impresora..."
                  @keydown.enter="runTestSearch"
                />
                <woot-button
                  icon="search"
                  :loading="testSearching"
                  :disabled="!testQuery.trim()"
                  @click="runTestSearch"
                >
                  Buscar
                </woot-button>
                <woot-button
                  v-if="testSearched"
                  variant="clear"
                  color-scheme="secondary"
                  @click="clearTest"
                >
                  Limpiar
                </woot-button>
              </div>
            </div>

            <div class="flex gap-4">
              <div class="flex-1">
                <label class="block text-xs font-semibold text-slate-600 mb-1">Resultados máximos</label>
                <input
                  v-model.number="testLimit"
                  type="number"
                  min="1"
                  max="20"
                  class="input"
                />
              </div>
              <div class="flex-1">
                <label class="block text-xs font-semibold text-slate-600 mb-1">
                  Umbral de similitud ({{ testThreshold }})
                </label>
                <input
                  v-model.number="testThreshold"
                  type="range"
                  min="0"
                  max="1"
                  step="0.05"
                  class="w-full mt-1"
                />
                <div class="flex justify-between text-xs text-slate-400 mt-0.5">
                  <span>0 — todo</span>
                  <span>1 — exacto</span>
                </div>
              </div>
            </div>
          </div>

          <!-- Estado: buscando -->
          <div v-if="testSearching" class="flex justify-center py-12">
            <span class="text-slate-400 text-sm">Generando embedding y buscando...</span>
          </div>

          <!-- Sin resultados -->
          <div
            v-else-if="testSearched && testResults.length === 0"
            class="flex flex-col items-center justify-center py-12 gap-2"
          >
            <fluent-icon icon="search" size="32" class="text-slate-300" />
            <p class="text-slate-500 text-sm">Sin resultados para ese umbral</p>
            <p class="text-slate-400 text-xs">Prueba bajando el umbral de similitud</p>
          </div>

          <!-- Resultados -->
          <div v-else-if="testResults.length > 0" class="mt-4 flex flex-col gap-3">
            <p class="text-xs text-slate-400">
              {{ testResults.length }} resultado(s) para "<strong>{{ testQuery }}</strong>"
            </p>
            <div class="overflow-y-auto flex flex-col gap-3 pr-1" style="max-height: 380px">
            <div
              v-for="(result, idx) in testResults"
              :key="result.id"
              class="bg-white border border-slate-200 rounded-lg p-4 flex flex-col gap-2 cursor-pointer hover:border-woot-300 hover:shadow-sm transition-all"
              @click="viewingResult = result"
            >
              <div class="flex items-center justify-between gap-3">
                <div class="flex items-center gap-2 flex-wrap">
                  <span class="text-xs font-bold text-slate-400">#{{ idx + 1 }}</span>
                  <span class="text-sm font-semibold text-slate-700">{{ result.title || '—' }}</span>
                  <span class="text-xs text-slate-400 bg-slate-50 px-1.5 py-0.5 rounded">
                    {{ sourceTypeLabel(result.source_type) }}
                  </span>
                  <span
                    v-if="result.metadata && result.metadata.chunk_total > 1"
                    class="text-xs text-woot-600 bg-woot-50 px-1.5 py-0.5 rounded font-medium"
                  >
                    chunk {{ result.metadata.chunk_index + 1 }}/{{ result.metadata.chunk_total }}
                  </span>
                </div>
                <span
                  class="text-xs font-bold px-2 py-0.5 rounded-full flex-shrink-0"
                  :class="similarityColor(result.similarity)"
                >
                  {{ (result.similarity * 100).toFixed(1) }}%
                </span>
              </div>

              <!-- Barra de similitud -->
              <div class="w-full bg-slate-100 rounded-full h-1.5">
                <div
                  class="h-1.5 rounded-full transition-all"
                  :class="result.similarity >= 0.6 ? 'bg-green-500' : result.similarity >= 0.4 ? 'bg-yellow-400' : 'bg-slate-300'"
                  :style="{ width: similarityBar(result.similarity) + '%' }"
                />
              </div>

              <p class="text-xs text-slate-500 line-clamp-3">{{ result.content }}</p>

              <a
                v-if="result.metadata && result.metadata.url"
                :href="result.metadata.url"
                target="_blank"
                rel="noopener noreferrer"
                class="text-xs text-woot-500 hover:underline truncate"
              >
                {{ result.metadata.url }}
              </a>
            </div>
            </div>
          </div>

        </div>
      </div>

    </div>

    <AddSourceModal
      :show="showAddModal"
      :saving="saving"
      :source="editingSource"
      @close="showAddModal = false; editingSource = null"
      @save="onSaveSource"
    />

    <!-- Modal visor de contenido completo -->
    <woot-modal
      v-if="viewingResult"
      :show="!!viewingResult"
      :on-close="() => viewingResult = null"
    >
      <div class="flex flex-col gap-4 p-6 w-full max-w-2xl">
        <div class="flex items-start justify-between gap-3">
          <div class="flex flex-col gap-1">
            <h3 class="text-base font-semibold text-slate-800">
              {{ viewingResult.title }}
            </h3>
            <div class="flex items-center gap-2">
              <span class="text-xs text-slate-400 bg-slate-50 px-1.5 py-0.5 rounded">
                {{ sourceTypeLabel(viewingResult.source_type) }}
              </span>
              <span
                v-if="viewingResult.metadata && viewingResult.metadata.chunk_total > 1"
                class="text-xs text-woot-600 bg-woot-50 px-1.5 py-0.5 rounded font-medium"
              >
                chunk {{ viewingResult.metadata.chunk_index + 1 }}/{{ viewingResult.metadata.chunk_total }}
              </span>
              <span
                v-if="viewingResult.similarity != null"
                class="text-xs font-bold px-2 py-0.5 rounded-full"
                :class="similarityColor(viewingResult.similarity)"
              >
                {{ (viewingResult.similarity * 100).toFixed(1) }}% similitud
              </span>
            </div>
          </div>
        </div>

        <div class="bg-slate-50 rounded-lg p-4 max-h-[60vh] overflow-y-auto">
          <p class="text-sm text-slate-700 whitespace-pre-wrap leading-relaxed">{{ viewingResult.content }}</p>
        </div>

        <a
          v-if="viewingResult.metadata && viewingResult.metadata.url"
          :href="viewingResult.metadata.url"
          target="_blank"
          rel="noopener noreferrer"
          class="text-xs text-woot-500 hover:underline truncate"
        >
          {{ viewingResult.metadata.url }}
        </a>
      </div>
    </woot-modal>

    <woot-delete-modal
      :show.sync="showDeleteModal"
      :on-close="closeDeleteModal"
      :on-confirm="confirmDelete"
      title="Eliminar fuente de conocimiento"
      message="Esta acción eliminará permanentemente la fuente y todo el contenido indexado asociado (embeddings). No se puede deshacer."
      :message-value="deletingSource ? deletingSource.name : ''"
      confirm-text="Sí, eliminar"
      reject-text="Cancelar"
    />
  </div>
</template>
