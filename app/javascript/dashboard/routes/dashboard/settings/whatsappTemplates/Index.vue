<!--
  @waba_templates — Sección de Configuración: TODAS las plantillas de TODOS los canales de
  WhatsApp, con filtro por canal. Crear/editar/borrar/sincronizar contra Meta.
  Validación en vivo replicada del backend. Strings en español; commit --no-verify.

  feat/plantillas_whatsapp_mejoras F6 (docs/plantillas_whatsapp_mejoras_plan.md): subir el
  archivo de muestra del encabezado, vista previa con el archivo real, filtros por idioma y
  tipo, «se puede enviar» por plantilla, errores de sincronización por bandeja y «Ver en Meta».
  La lógica nueva vive en templateScreen.js (puro, con spec).

  F10: crear y editar ya no es un modal: «Nueva plantilla» y el lápiz llevan a
  TemplateEditor.vue (/new y /:templateId/edit). Aquí quedan la tabla, los filtros,
  sincronizar y borrar.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import {
  KIND_OPTIONS,
  templateKinds,
  sendability,
  metaManagerUrl,
} from './templateScreen';

export default {
  components: {
    TableFooter,
    SettingsLayout,
    BaseSettingsHeader,
  },
  data() {
    return {
      channelFilter: '',
      statusFilter: '',
      categoryFilter: '',
      languageFilter: '',
      kindFilter: '',
      kindOptions: KIND_OPTIONS,
      searchQuery: '',
      currentPage: 1,
      perPage: 10,
      showFiltersModal: false,
      draftFilters: {
        channel: '',
        status: '',
        category: '',
        language: '',
        kind: '',
      },
      deletePopup: false,
      deleteTarget: null,
      categories: ['UTILITY', 'MARKETING', 'AUTHENTICATION'],
    };
  },
  computed: {
    ...mapGetters({
      templates: 'whatsappTemplates/getTemplates',
      uiFlags: 'whatsappTemplates/getUIFlags',
      inboxes: 'inboxes/getInboxes',
    }),
    // Canales de WhatsApp de la cuenta (para filtro y selector del form).
    whatsappInboxes() {
      return this.inboxes.filter(i => i.channel_type === 'Channel::Whatsapp');
    },
    // Estados realmente presentes en los datos (para no ofrecer filtros vacíos).
    statusOptions() {
      return [
        ...new Set(this.templates.map(t => t.status).filter(Boolean)),
      ].sort();
    },
    // F6: los idiomas que de verdad hay en las plantillas.
    languageFilterOptions() {
      return [
        ...new Set(this.templates.map(t => t.language).filter(Boolean)),
      ].sort();
    },
    hasActiveFilters() {
      return Boolean(
        this.channelFilter ||
          this.statusFilter ||
          this.categoryFilter ||
          this.languageFilter ||
          this.kindFilter ||
          this.searchQuery.trim()
      );
    },
    // Chips de los filtros activos (sin la búsqueda, que tiene su propio input).
    activeFilterChips() {
      const chips = [];
      if (this.channelFilter) {
        const ib = this.whatsappInboxes.find(
          i => i.channel_id === Number(this.channelFilter)
        );
        chips.push({
          key: 'channel',
          label: `Canal: ${ib ? ib.name : this.channelFilter}`,
        });
      }
      if (this.statusFilter) {
        chips.push({ key: 'status', label: `Estado: ${this.statusFilter}` });
      }
      if (this.categoryFilter) {
        chips.push({
          key: 'category',
          label: `Categoría: ${this.categoryFilter}`,
        });
      }
      if (this.languageFilter) {
        chips.push({ key: 'language', label: `Idioma: ${this.languageFilter}` });
      }
      if (this.kindFilter) {
        const tipo = KIND_OPTIONS.find(k => k.value === this.kindFilter);
        chips.push({
          key: 'kind',
          label: `Tipo: ${tipo ? tipo.label : this.kindFilter}`,
        });
      }
      return chips;
    },
    activeFilterCount() {
      return this.activeFilterChips.length;
    },
    filteredTemplates() {
      const q = this.searchQuery.trim().toLowerCase();
      return this.templates.filter(t => {
        if (
          this.channelFilter &&
          t.channel_whatsapp_id !== Number(this.channelFilter)
        ) {
          return false;
        }
        if (this.statusFilter && t.status !== this.statusFilter) return false;
        if (this.categoryFilter && t.category !== this.categoryFilter) {
          return false;
        }
        if (this.languageFilter && t.language !== this.languageFilter) {
          return false;
        }
        if (this.kindFilter && !templateKinds(t).includes(this.kindFilter)) {
          return false;
        }
        if (q && !(t.name || '').toLowerCase().includes(q)) return false;
        return true;
      });
    },
    // Recorte de la página actual (paginación en cliente sobre lo ya filtrado).
    pagedTemplates() {
      const start = (this.currentPage - 1) * this.perPage;
      return this.filteredTemplates.slice(start, start + this.perPage);
    },
  },
  watch: {
    // Al cambiar cualquier filtro o la búsqueda, volvemos a la primera página.
    searchQuery() {
      this.currentPage = 1;
    },
    channelFilter() {
      this.currentPage = 1;
    },
    statusFilter() {
      this.currentPage = 1;
    },
    categoryFilter() {
      this.currentPage = 1;
    },
    languageFilter() {
      this.currentPage = 1;
    },
    kindFilter() {
      this.currentPage = 1;
    },
  },
  async mounted() {
    this.$store.dispatch('inboxes/get');
    // Al abrir: importa lo que los canales YA tienen en cache (sin llamar a Meta) y luego lista.
    await this.importFromCache();
    this.fetchAll();
  },
  methods: {
    fetchAll() {
      this.$store.dispatch('whatsappTemplates/fetch');
    },
    async importFromCache() {
      try {
        await this.$store.dispatch('whatsappTemplates/import');
      } catch (e) {
        // No bloquea: si falla el import local, igual mostramos lo que haya en la tabla.
      }
    },
    clearFilters() {
      this.channelFilter = '';
      this.statusFilter = '';
      this.categoryFilter = '';
      this.languageFilter = '';
      this.kindFilter = '';
      this.searchQuery = '';
    },
    openFiltersModal() {
      this.draftFilters = {
        channel: this.channelFilter,
        status: this.statusFilter,
        category: this.categoryFilter,
        language: this.languageFilter,
        kind: this.kindFilter,
      };
      this.showFiltersModal = true;
    },
    closeFiltersModal() {
      this.showFiltersModal = false;
    },
    clearDraftFilters() {
      this.draftFilters = {
        channel: '',
        status: '',
        category: '',
        language: '',
        kind: '',
      };
    },
    applyFiltersFromModal() {
      this.channelFilter = this.draftFilters.channel;
      this.statusFilter = this.draftFilters.status;
      this.categoryFilter = this.draftFilters.category;
      this.languageFilter = this.draftFilters.language;
      this.kindFilter = this.draftFilters.kind;
      this.showFiltersModal = false;
    },
    removeFilter(key) {
      if (key === 'channel') this.channelFilter = '';
      if (key === 'status') this.statusFilter = '';
      if (key === 'category') this.categoryFilter = '';
      if (key === 'language') this.languageFilter = '';
      if (key === 'kind') this.kindFilter = '';
    },
    onPageChange(page) {
      this.currentPage = page;
    },
    // Motivo por el que una plantilla no es editable (tooltip del icono deshabilitado).
    editableHint(status) {
      return (
        {
          PENDING: 'En revisión por Meta: no se puede editar hasta que resuelva.',
          DRAFT: 'Falló el último envío a Meta: sincroniza para recuperarla.',
          IN_APPEAL: 'En apelación ante Meta: no se puede editar.',
          DISABLED: 'Deshabilitada por Meta: no se puede editar.',
          PENDING_DELETION: 'En proceso de borrado: no se puede editar.',
        }[status] || 'No editable en su estado actual.'
      );
    },
    inboxForChannel(channelWhatsappId) {
      return (
        this.whatsappInboxes.find(i => i.channel_id === channelWhatsappId) ||
        null
      );
    },
    // F6: ¿se puede mandar en la conversación y en seguimientos/campañas?
    sendabilityOf(template) {
      return sendability(
        template,
        this.inboxForChannel(template.channel_whatsapp_id)
      );
    },
    openInMeta(template) {
      const liga = metaManagerUrl(
        this.inboxForChannel(template.channel_whatsapp_id)
      );
      if (liga) window.open(liga, '_blank', 'noopener');
    },
    hasMetaLink(template) {
      return Boolean(
        metaManagerUrl(this.inboxForChannel(template.channel_whatsapp_id))
      );
    },
    inboxNameForChannel(channelWhatsappId) {
      const inbox = this.whatsappInboxes.find(
        i => i.channel_id === channelWhatsappId
      );
      return inbox ? inbox.name : '—';
    },
    async sync() {
      const targets = this.channelFilter
        ? [Number(this.channelFilter)]
        : this.whatsappInboxes.map(i => i.id);
      if (!targets.length) {
        useAlert('No hay canales de WhatsApp configurados.');
        return;
      }
      let created = 0;
      let updated = 0;
      // allSettled: un canal con token vencido no debe tumbar la sync de los demás.
      const results = await Promise.allSettled(
        targets.map(id => this.$store.dispatch('whatsappTemplates/sync', id))
      );
      results.forEach(r => {
        if (r.status === 'fulfilled') {
          created += r.value.created;
          updated += r.value.updated;
        }
      });
      await this.fetchAll();

      // F6: qué bandeja falló y por qué (antes solo el primer motivo, sin decir cuál).
      const failed = results
        .map((r, i) => ({ r, id: targets[i] }))
        .filter(({ r }) => r.status === 'rejected');
      if (failed.length) {
        const detalle = failed
          .map(({ r, id }) => {
            const inbox = this.whatsappInboxes.find(i => i.id === id);
            const motivo =
              (r.reason &&
                r.reason.response &&
                r.reason.response.data &&
                r.reason.response.data.error) ||
              'No se pudo sincronizar con Meta.';
            return `«${inbox ? inbox.name : id}»: ${motivo}`;
          })
          .join(' · ');
        useAlert(
          `Se sincronizaron ${targets.length - failed.length} de ${targets.length} bandejas. Falló ${detalle}`
        );
        return;
      }
      useAlert(`Sincronizado: ${created} nuevas, ${updated} actualizadas.`);
    },
    statusClass(status) {
      return (
        {
          APPROVED:
            'bg-green-100 text-green-700 dark:bg-green-800 dark:text-green-100',
          PENDING:
            'bg-amber-100 text-amber-700 dark:bg-amber-800 dark:text-amber-100',
          REJECTED: 'bg-red-100 text-red-700 dark:bg-red-800 dark:text-red-100',
        }[status] ||
        'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-200'
      );
    },
    qualityDot(score) {
      return (
        {
          GREEN: 'bg-green-500',
          YELLOW: 'bg-amber-500',
          RED: 'bg-red-500',
        }[score] || 'bg-slate-300'
      );
    },
    // Deriva el inbox_id a partir del filtro (channelFilter guarda channel_whatsapp_id).
    channelFilterInboxId() {
      if (!this.channelFilter) return null;
      const inbox = this.whatsappInboxes.find(
        i => i.channel_id === Number(this.channelFilter)
      );
      return inbox ? inbox.id : null;
    },
    // F10: crear y editar en su propia página.
    openNew() {
      const inboxId = this.channelFilterInboxId();
      this.$router.push({
        name: 'whatsapp_templates_new',
        query: inboxId ? { inbox_id: inboxId } : {},
      });
    },
    openEdit(template) {
      this.$router.push({
        name: 'whatsapp_templates_edit',
        params: { templateId: template.id },
      });
    },
    confirmDelete(template) {
      this.deleteTarget = template;
      this.deletePopup = true;
    },
    closeDelete() {
      this.deletePopup = false;
      this.deleteTarget = null;
    },
    async doDelete() {
      try {
        await this.$store.dispatch(
          'whatsappTemplates/delete',
          this.deleteTarget.id
        );
        useAlert('Plantilla eliminada.');
      } catch (e) {
        useAlert('No se pudo eliminar.');
      } finally {
        this.closeDelete();
      }
    },
  },
};
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.fetching"
    loading-message="Cargando plantillas…"
    :no-records-found="false"
  >
    <template #header>
      <BaseSettingsHeader
        title="Plantillas de WhatsApp"
        description="Crea, envía a aprobación y gestiona las plantillas de todos tus canales de WhatsApp sin entrar a Meta."
      >
        <template #actions>
          <woot-button
            variant="clear"
            icon="arrow-swap"
            :is-loading="uiFlags.syncing"
            @click="sync"
          >
            Sincronizar
          </woot-button>
          <woot-button icon="add-circle" @click="openNew">
            Nueva plantilla
          </woot-button>
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <!-- Cuerpo a altura fija: solo la tabla scrollea por dentro y el paginado queda fijo
           abajo (mismo comportamiento que el tracking-dashboard). -->
      <div class="flex flex-col h-[calc(100vh-13rem)] min-h-[20rem]">
      <!-- Barra de filtros: búsqueda + botón modal + chips activos (patrón del tracking-dashboard) -->
      <div
        class="shrink-0 flex flex-col gap-3 p-3 mb-4 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
      >
        <div class="flex items-center gap-3">
          <div class="relative flex-1 min-w-[120px]">
            <input
              v-model="searchQuery"
              type="text"
              placeholder="Nombre de la plantilla…"
              class="reset-base box-border w-full h-9 m-0 text-sm rounded-md border border-solid border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 pl-8 pr-2 outline-none focus:border-woot-500 dark:focus:border-woot-600"
            />
            <fluent-icon
              icon="search"
              size="16"
              class="absolute -translate-y-1/2 left-2 top-1/2 text-slate-400"
            />
          </div>
          <div class="flex items-center gap-2 shrink-0">
            <woot-button
              variant="smooth"
              size="small"
              class="!h-9"
              icon="filter"
              @click="openFiltersModal"
            >
              Filtros<span v-if="activeFilterCount"> ({{ activeFilterCount }})</span>
            </woot-button>
            <woot-button
              v-if="hasActiveFilters"
              variant="clear"
              size="small"
              class="!h-9"
              @click="clearFilters"
            >
              Limpiar
            </woot-button>
          </div>
        </div>

        <!-- Chips de filtros activos -->
        <div
          v-if="activeFilterChips.length"
          class="flex flex-wrap items-center gap-2"
        >
          <span
            v-for="chip in activeFilterChips"
            :key="chip.key"
            class="inline-flex items-center gap-1 px-2 py-1 text-xs font-medium rounded-full bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-200"
          >
            {{ chip.label }}
            <button
              class="flex items-center text-slate-400 hover:text-red-500"
              title="Quitar filtro"
              @click="removeFilter(chip.key)"
            >
              <fluent-icon icon="dismiss" size="12" />
            </button>
          </span>
        </div>
      </div>

      <!-- Modal de filtros -->
      <woot-modal
        :show.sync="showFiltersModal"
        :on-close="closeFiltersModal"
      >
        <div class="flex flex-col h-auto overflow-auto">
          <woot-modal-header header-title="Filtrar plantillas" />
          <div class="flex flex-col gap-4 p-8">
            <label
              class="flex flex-col gap-1 text-sm font-medium text-slate-600 dark:text-slate-300"
            >
              Canal
              <select
                v-model="draftFilters.channel"
                class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 h-9 px-2"
              >
                <option value="">Todos</option>
                <option
                  v-for="i in whatsappInboxes"
                  :key="i.id"
                  :value="i.channel_id"
                >
                  {{ i.name }}
                </option>
              </select>
            </label>
            <label
              class="flex flex-col gap-1 text-sm font-medium text-slate-600 dark:text-slate-300"
            >
              Estado
              <select
                v-model="draftFilters.status"
                class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 h-9 px-2"
              >
                <option value="">Todos</option>
                <option v-for="s in statusOptions" :key="s" :value="s">
                  {{ s }}
                </option>
              </select>
            </label>
            <label
              class="flex flex-col gap-1 text-sm font-medium text-slate-600 dark:text-slate-300"
            >
              Categoría
              <select
                v-model="draftFilters.category"
                class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 h-9 px-2"
              >
                <option value="">Todas</option>
                <option v-for="c in categories" :key="c" :value="c">
                  {{ c }}
                </option>
              </select>
            </label>
            <label
              class="flex flex-col gap-1 text-sm font-medium text-slate-600 dark:text-slate-300"
            >
              Idioma
              <select
                v-model="draftFilters.language"
                class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 h-9 px-2"
              >
                <option value="">Todos</option>
                <option v-for="l in languageFilterOptions" :key="l" :value="l">
                  {{ l }}
                </option>
              </select>
            </label>
            <label
              class="flex flex-col gap-1 text-sm font-medium text-slate-600 dark:text-slate-300"
            >
              Tipo
              <select
                v-model="draftFilters.kind"
                class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 h-9 px-2"
              >
                <option value="">Todos</option>
                <option v-for="k in kindOptions" :key="k.value" :value="k.value">
                  {{ k.label }}
                </option>
              </select>
            </label>
            <div class="flex items-center justify-end gap-2 mt-2">
              <woot-button variant="clear" @click="clearDraftFilters">
                Limpiar
              </woot-button>
              <woot-button @click="applyFiltersFromModal">
                Aplicar filtros
              </woot-button>
            </div>
          </div>
        </div>
      </woot-modal>

      <!-- Zona scrollable: SOLO la tabla scrollea; filtros y paginado quedan fijos. -->
      <div class="flex-1 min-h-0 overflow-y-auto">
      <div
        v-if="!filteredTemplates.length"
        class="text-center text-slate-400 py-16 border border-dashed border-slate-200 dark:border-slate-700 rounded-lg"
      >
        <template v-if="hasActiveFilters">
          Ninguna plantilla coincide con los filtros.
        </template>
        <template v-else>
          No hay plantillas para mostrar. Crea una o sincroniza desde Meta.
        </template>
      </div>

      <table v-else class="w-full text-sm">
        <thead
          class="sticky top-0 z-10 text-left text-slate-400 bg-white dark:bg-slate-900 border-b border-slate-100 dark:border-slate-700"
        >
          <tr>
            <th class="py-2 font-medium">Nombre</th>
            <th class="py-2 font-medium">Canal</th>
            <th class="py-2 font-medium">Idioma</th>
            <th class="py-2 font-medium">Categoría</th>
            <th class="py-2 font-medium">Estado</th>
            <th class="py-2 font-medium">Calidad</th>
            <th class="py-2 font-medium">Se puede enviar</th>
            <th class="py-2 font-medium text-right">Acciones</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="t in pagedTemplates"
            :key="t.id"
            class="border-b border-slate-50 dark:border-slate-800"
          >
            <td class="py-3">
              <!-- F10.4: el nombre abre la ficha (estado en Meta, duplicar, editar). -->
              <router-link
                :to="{
                  name: 'whatsapp_templates_show',
                  params: { templateId: t.id },
                }"
                class="font-medium text-slate-700 dark:text-slate-200 hover:text-woot-600 hover:underline"
              >
                {{ t.name }}
              </router-link>
              <div v-if="t.rejection_reason" class="text-xs text-red-500">
                Rechazo: {{ t.rejection_reason }}
              </div>
              <div v-if="t.submission_error" class="text-xs text-amber-600">
                {{ t.submission_error }}
              </div>
            </td>
            <td class="py-3 text-slate-500">
              {{ inboxNameForChannel(t.channel_whatsapp_id) }}
            </td>
            <td class="py-3 text-slate-500">{{ t.language }}</td>
            <td class="py-3 text-slate-500">{{ t.category }}</td>
            <td class="py-3">
              <span
                class="px-2 py-0.5 rounded-full text-xs font-medium"
                :class="statusClass(t.status)"
              >
                {{ t.status }}
              </span>
            </td>
            <td class="py-3">
              <span
                v-if="t.quality_score"
                class="inline-flex items-center gap-1"
              >
                <span
                  class="w-2 h-2 rounded-full"
                  :class="qualityDot(t.quality_score)"
                />
                <span class="text-xs text-slate-500">{{ t.quality_score }}</span>
              </span>
              <span v-else class="text-slate-300">—</span>
            </td>
            <!-- F6: dónde se puede mandar. Las de archivo: conversación solo en WhatsApp
                 Cloud; seguimientos y campañas además necesitan el archivo guardado. -->
            <td class="py-3 text-xs">
              <template v-if="sendabilityOf(t).conversation === null">
                <span class="text-slate-300">—</span>
              </template>
              <div v-else class="flex flex-col gap-0.5">
                <span
                  :class="
                    sendabilityOf(t).conversation
                      ? 'text-green-700 dark:text-green-300'
                      : 'text-slate-400'
                  "
                >
                  {{ sendabilityOf(t).conversation ? '✓' : '✗' }} Conversación
                </span>
                <span
                  :class="{
                    'text-green-700 dark:text-green-300':
                      sendabilityOf(t).trackings === 'ok',
                    'text-amber-700 dark:text-amber-400':
                      sendabilityOf(t).trackings === 'missing_file',
                    'text-slate-400': sendabilityOf(t).trackings === 'no',
                  }"
                  :title="
                    sendabilityOf(t).trackings === 'missing_file'
                      ? 'Sube el archivo de muestra en Editar: los seguimientos y campañas lo mandan.'
                      : ''
                  "
                >
                  {{
                    sendabilityOf(t).trackings === 'ok'
                      ? '✓ Seguimientos'
                      : sendabilityOf(t).trackings === 'missing_file'
                      ? '⚠ Seguimientos: falta archivo'
                      : '✗ Seguimientos'
                  }}
                </span>
              </div>
            </td>
            <td class="py-3 text-right">
              <woot-button
                v-if="hasMetaLink(t)"
                variant="clear"
                size="small"
                icon="open"
                title="Ver en Meta (WhatsApp Manager)"
                @click="openInMeta(t)"
              />
              <!-- El editar SIEMPRE se ve; si no aplica, va deshabilitado con el motivo
                   en el tooltip (Meta solo permite editar APPROVED/REJECTED/PAUSED). -->
              <span
                :title="t.editable ? 'Editar' : editableHint(t.status)"
                class="inline-block"
              >
                <woot-button
                  variant="clear"
                  size="small"
                  icon="edit"
                  :is-disabled="!t.editable"
                  @click="openEdit(t)"
                />
              </span>
              <woot-button
                variant="clear"
                size="small"
                color-scheme="alert"
                icon="delete"
                @click="confirmDelete(t)"
              />
            </td>
          </tr>
        </tbody>
      </table>
      </div>

      <TableFooter
        :current-page="currentPage"
        :total-count="filteredTemplates.length"
        :page-size="perPage"
        class="shrink-0 border-t border-slate-100 dark:border-slate-700"
        @pageChange="onPageChange"
      />
      </div>
    </template>

    <woot-delete-modal
      :show.sync="deletePopup"
      :on-close="closeDelete"
      :on-confirm="doDelete"
      title="Eliminar plantilla"
      :message="`¿Eliminar la plantilla &quot;${deleteTarget && deleteTarget.name}&quot;? También se borra en Meta.`"
      confirm-text="Eliminar"
      reject-text="Cancelar"
    />
  </SettingsLayout>
</template>
