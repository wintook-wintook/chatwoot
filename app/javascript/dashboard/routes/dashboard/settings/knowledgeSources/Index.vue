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
      saving: false,
      syncingId: null,
      activeTab: 0,
      searchQuery: '',
      currentPage: 1,
      itemsPerPage: 5,
      totalItems: 0,
      testQuery: '',
      testLimit: 5,
      testThreshold: 0.3,
      testResults: [],
      testSearching: false,
      testSearched: false,
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
      return type => (type === 'canned_response' ? 'Respuesta Predefinida' : 'Discourse');
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
    },
  },
  mounted() {
    this.fetchSources();
    this.fetchItems();
  },
  methods: {
    async fetchSources() {
      this.loadingSources = true;
      try {
        const { data } = await KnowledgeBaseAPI.getSources(this.accountId);
        this.sources = data;
      } catch {
        useAlert('Error al cargar las fuentes');
      } finally {
        this.loadingSources = false;
      }
    },
    async fetchItems() {
      this.loadingItems = true;
      try {
        const { data } = await KnowledgeBaseAPI.getItems(this.accountId, {
          page: this.currentPage,
          per_page: this.itemsPerPage,
          search: this.searchQuery || undefined,
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
        const { data } = await KnowledgeBaseAPI.createSource(this.accountId, payload);
        this.sources.push(data);
        this.showAddModal = false;
        useAlert('Fuente agregada correctamente');
      } catch {
        useAlert('Error al agregar la fuente');
      } finally {
        this.saving = false;
      }
    },
    async onSync(source) {
      this.syncingId = source.id;
      try {
        await KnowledgeBaseAPI.syncSource(this.accountId, source.id);
        useAlert('Sincronizacion iniciada — los items apareceran en unos momentos');
        await this.fetchSources();
        setTimeout(() => this.fetchItems(), 3000);
      } catch {
        useAlert('Error al sincronizar la fuente');
      } finally {
        this.syncingId = null;
      }
    },
    async onDelete(source) {
      if (!window.confirm('Eliminar la fuente "' + source.name + '"?')) return;
      try {
        await KnowledgeBaseAPI.deleteSource(this.accountId, source.id);
        this.sources = this.sources.filter(s => s.id !== source.id);
        await this.fetchItems();
        useAlert('Fuente eliminada');
      } catch {
        useAlert('Error al eliminar la fuente');
      }
    },
    onSearch() {
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
  },
};
</script>

<template>
  <div class="flex-1 overflow-auto">
    <BaseSettingsHeader title="Base de Conocimiento" feature-name="knowledge_sources">
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
        <div class="mb-4 flex gap-2">
          <input
            v-model="searchQuery"
            type="text"
            class="input flex-1"
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
            <table class="w-full">
              <thead>
                <tr class="bg-slate-50 border-b border-slate-200">
                  <th class="text-left px-4 py-3 text-sm font-semibold text-slate-500 w-8"></th>
                  <th class="text-left px-4 py-3 text-sm font-semibold text-slate-500">Título</th>
                  <th class="text-left px-4 py-3 text-sm font-semibold text-slate-500">Contenido</th>
                  <th class="text-left px-4 py-3 text-sm font-semibold text-slate-500 w-40">Tipo</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <tr
                  v-for="item in filteredItems"
                  :key="item.id"
                  class="bg-white hover:bg-slate-50 transition-colors"
                >
                  <td class="px-4 py-3">
                    <fluent-icon
                      :icon="item.source_type === 'canned_response' ? 'chat-multiple' : 'globe'"
                      size="18"
                      class="text-slate-400"
                    />
                  </td>
                  <td class="px-4 py-3 font-medium text-slate-700 text-sm max-w-[220px] truncate">
                    {{ item.title || '—' }}
                  </td>
                  <td class="px-4 py-3 text-slate-500 text-sm max-w-[420px]">
                    <span class="line-clamp-2 leading-relaxed">{{ item.content }}</span>
                  </td>
                  <td class="px-4 py-3">
                    <span class="inline-flex items-center px-2.5 py-1 rounded text-sm font-medium bg-slate-100 text-slate-600">
                      {{ sourceTypeLabel(item.source_type) }}
                    </span>
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
            @delete="onDelete"
          />
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
              class="bg-white border border-slate-200 rounded-lg p-4 flex flex-col gap-2"
            >
              <div class="flex items-center justify-between gap-3">
                <div class="flex items-center gap-2">
                  <span class="text-xs font-bold text-slate-400">#{{ idx + 1 }}</span>
                  <span class="text-sm font-semibold text-slate-700">{{ result.title || '—' }}</span>
                  <span class="text-xs text-slate-400 bg-slate-50 px-1.5 py-0.5 rounded">
                    {{ sourceTypeLabel(result.source_type) }}
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

              <p class="text-xs text-slate-500">{{ result.content }}</p>
            </div>
            </div>
          </div>

        </div>
      </div>

    </div>

    <AddSourceModal
      :show="showAddModal"
      :saving="saving"
      @close="showAddModal = false"
      @save="onSaveSource"
    />
  </div>
</template>
