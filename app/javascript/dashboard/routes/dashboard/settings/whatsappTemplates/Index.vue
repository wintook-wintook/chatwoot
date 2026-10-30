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
import DeleteTemplateModal from './DeleteTemplateModal.vue';
import {
  KIND_OPTIONS,
  templateKinds,
  sendability,
  metaManagerUrl,
  sortTemplates,
} from './templateScreen';

const PER_PAGE_OPTIONS = [10, 25, 50, 100];
const PER_PAGE_KEY = 'waba_templates_per_page';

const storedPerPage = () => {
  try {
    const guardado = Number(window.localStorage.getItem(PER_PAGE_KEY));
    return PER_PAGE_OPTIONS.includes(guardado) ? guardado : 25;
  } catch {
    return 25;
  }
};

export default {
  components: {
    TableFooter,
    SettingsLayout,
    BaseSettingsHeader,
    DeleteTemplateModal,
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
      // F10: filas por página a elegir (25 por omisión); se recuerda en este navegador.
      perPage: storedPerPage(),
      perPageOptions: PER_PAGE_OPTIONS,
      // F10: clic en la columna para ordenar; por omisión, la última actualización primero.
      sortKey: 'updated_at',
      sortDir: 'desc',
      deletePopup: false,
      deleteTarget: null,
      deleting: false,
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
      return this.sortedTemplates.slice(start, start + this.perPage);
    },
    sortedTemplates() {
      return sortTemplates(
        this.filteredTemplates,
        { key: this.sortKey, dir: this.sortDir },
        t => this.inboxNameForChannel(t.channel_whatsapp_id)
      );
    },
    columns() {
      return [
        'name',
        'actions',
        'channel',
        'language',
        'category',
        'status',
        'sendable',
        'created_at',
        'updated_at',
      ].map(key => ({
        key,
        sortable: !['sendable', 'actions'].includes(key),
        label: this.$t(`WHATSAPP_TEMPLATE_LIST.COLUMNS.${key.toUpperCase()}`),
      }));
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
    perPage(valor) {
      this.currentPage = 1;
      try {
        window.localStorage.setItem(PER_PAGE_KEY, String(valor));
      } catch {
        // Sin almacenamiento (ventana privada): solo dura esta visita.
      }
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
    onPageChange(page) {
      this.currentPage = page;
    },
    // Clic en una columna: la misma cambia el sentido; otra ordena por ella (fechas, de la
    // más reciente).
    sortBy(key) {
      if (this.sortKey === key) {
        this.sortDir = this.sortDir === 'asc' ? 'desc' : 'asc';
      } else {
        this.sortKey = key;
        this.sortDir = ['created_at', 'updated_at'].includes(key)
          ? 'desc'
          : 'asc';
      }
      this.currentPage = 1;
    },
    sortIcon(key) {
      if (this.sortKey !== key) return 'arrow-sort';
      return this.sortDir === 'asc' ? 'chevron-up' : 'chevron-down';
    },
    formatDate(fecha) {
      if (!fecha) return '—';
      return new Date(fecha).toLocaleString(this.$i18n.locale || 'es', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    creatorName(template) {
      return template.created_by
        ? template.created_by.name
        : this.$t('WHATSAPP_TEMPLATE_LIST.FROM_META');
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
    duplicate(template) {
      this.$router.push({
        name: 'whatsapp_templates_new',
        query: { from: template.id },
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
      this.deleting = true;
      try {
        await this.$store.dispatch(
          'whatsappTemplates/delete',
          this.deleteTarget.id
        );
        // Los selectores leen las plantillas de la bandeja: que ya no ofrezcan la borrada.
        this.$store.dispatch('inboxes/get');
        useAlert(this.$t('WHATSAPP_TEMPLATE_DELETE.DONE'));
        this.closeDelete();
      } catch (e) {
        const data = (e.response && e.response.data) || {};
        useAlert(data.error || this.$t('WHATSAPP_TEMPLATE_DELETE.ERROR'));
      } finally {
        this.deleting = false;
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
      <!-- F10: los filtros a la vista (Estado y Canal; Categoría, Idioma y Tipo a la
           derecha), sin modal. A alto de pantalla: filtros y paginado quedan fijos y solo
           la tabla hace scroll (con su encabezado fijo). Clic en la columna para ordenar. -->
      <div class="flex flex-col w-full h-[calc(100vh-13rem)] min-h-[20rem]">
        <div
          class="flex flex-wrap items-center gap-2 p-3 mb-4 border border-solid rounded-lg shrink-0 bg-white dark:bg-slate-800 border-slate-100 dark:border-slate-700"
        >
          <div class="relative w-56">
            <input
              v-model="searchQuery"
              type="text"
              :placeholder="$t('WHATSAPP_TEMPLATE_LIST.SEARCH')"
              class="reset-base box-border w-full h-9 m-0 text-sm rounded-md border border-solid border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 pl-8 pr-2 outline-none focus:border-woot-500 dark:focus:border-woot-600"
            />
            <fluent-icon
              icon="search"
              size="16"
              class="absolute -translate-y-1/2 left-2 top-1/2 text-slate-400"
            />
          </div>
          <select v-model="statusFilter" class="list-filter">
            <option value="">
              {{ $t('WHATSAPP_TEMPLATE_LIST.FILTERS.ALL_STATUSES') }}
            </option>
            <option
              v-for="estado in statusOptions"
              :key="estado"
              :value="estado"
            >
              {{ estado }}
            </option>
          </select>
          <select v-model="channelFilter" class="list-filter">
            <option value="">
              {{ $t('WHATSAPP_TEMPLATE_LIST.FILTERS.ALL_CHANNELS') }}
            </option>
            <option
              v-for="i in whatsappInboxes"
              :key="i.id"
              :value="i.channel_id"
            >
              {{ i.name }}
            </option>
          </select>
          <span class="flex-1" />
          <select v-model="categoryFilter" class="list-filter">
            <option value="">
              {{ $t('WHATSAPP_TEMPLATE_LIST.FILTERS.ALL_CATEGORIES') }}
            </option>
            <option v-for="c in categories" :key="c" :value="c">
              {{ $t(`WHATSAPP_TEMPLATE_EDITOR.CATEGORIES.${c}`) }}
            </option>
          </select>
          <select v-model="languageFilter" class="list-filter">
            <option value="">
              {{ $t('WHATSAPP_TEMPLATE_LIST.FILTERS.ALL_LANGUAGES') }}
            </option>
            <option v-for="l in languageFilterOptions" :key="l" :value="l">
              {{ l }}
            </option>
          </select>
          <select v-model="kindFilter" class="list-filter">
            <option value="">
              {{ $t('WHATSAPP_TEMPLATE_LIST.FILTERS.ALL_KINDS') }}
            </option>
            <option v-for="k in kindOptions" :key="k.value" :value="k.value">
              {{ k.label }}
            </option>
          </select>
          <woot-button
            v-if="hasActiveFilters"
            variant="clear"
            size="small"
            @click="clearFilters"
          >
            {{ $t('WHATSAPP_TEMPLATE_LIST.FILTERS.CLEAR') }}
          </woot-button>
        </div>

        <div class="flex-1 min-h-0 overflow-y-auto">
          <div
            v-if="!filteredTemplates.length"
            class="py-16 text-center border border-dashed rounded-lg text-slate-400 border-slate-200 dark:border-slate-700"
          >
            {{
              hasActiveFilters
                ? $t('WHATSAPP_TEMPLATE_LIST.EMPTY_FILTERED')
                : $t('WHATSAPP_TEMPLATE_LIST.EMPTY')
            }}
          </div>

          <table v-else class="w-full text-sm">
            <thead
              class="sticky top-0 z-10 text-left bg-white border-b text-slate-400 border-slate-100 dark:border-slate-700 dark:bg-slate-900"
            >
              <tr>
                <th
                  v-for="col in columns"
                  :key="col.key"
                  class="py-2 pr-3 font-medium whitespace-nowrap"
                >
                  <button
                    v-if="col.sortable"
                    type="button"
                    class="sort-header"
                    :class="{ 'sort-header--active': sortKey === col.key }"
                    @click="sortBy(col.key)"
                  >
                    {{ col.label }}
                    <fluent-icon :icon="sortIcon(col.key)" size="12" />
                  </button>
                  <span v-else>{{ col.label }}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="t in pagedTemplates"
                :key="t.id"
                class="border-b border-slate-50 dark:border-slate-800"
              >
                <td class="py-2 pr-3">
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
                  <div
                    v-if="t.rejection_reason"
                    class="text-xs text-red-500 truncate max-w-[16rem]"
                    :title="t.rejection_reason"
                  >
                    {{
                      $t('WHATSAPP_TEMPLATE_LIST.REJECTED', {
                        reason: t.rejection_reason,
                      })
                    }}
                  </div>
                </td>
                <!-- F10: acciones junto al nombre, con los botones como en Campañas. -->
                <td class="py-2 pr-3">
                  <div class="flex items-center gap-1.5 whitespace-nowrap">
                    <span
                      :title="
                        t.editable
                          ? $t('WHATSAPP_TEMPLATE_DETAIL.ACTIONS.EDIT')
                          : editableHint(t.status)
                      "
                      class="inline-block"
                    >
                      <woot-button
                        variant="smooth"
                        color-scheme="secondary"
                        size="small"
                        icon="edit"
                        :is-disabled="!t.editable"
                        @click="openEdit(t)"
                      />
                    </span>
                    <woot-button
                      variant="smooth"
                      color-scheme="secondary"
                      size="small"
                      icon="copy"
                      :title="$t('WHATSAPP_TEMPLATE_DETAIL.ACTIONS.DUPLICATE')"
                      @click="duplicate(t)"
                    />
                    <woot-button
                      v-if="hasMetaLink(t)"
                      variant="smooth"
                      color-scheme="secondary"
                      size="small"
                      icon="open"
                      :title="$t('WHATSAPP_TEMPLATE_DETAIL.ACTIONS.META')"
                      @click="openInMeta(t)"
                    />
                    <woot-button
                      variant="smooth"
                      color-scheme="alert"
                      size="small"
                      icon="delete"
                      :title="$t('WHATSAPP_TEMPLATE_LIST.DELETE')"
                      @click="confirmDelete(t)"
                    />
                  </div>
                </td>
                <td class="py-2 pr-3 text-slate-500">
                  {{ inboxNameForChannel(t.channel_whatsapp_id) }}
                </td>
                <td class="py-2 pr-3 text-slate-500">{{ t.language }}</td>
                <td class="py-2 pr-3 text-slate-500">
                  {{ $t(`WHATSAPP_TEMPLATE_EDITOR.CATEGORIES.${t.category}`) }}
                </td>
                <td class="py-2 pr-3 whitespace-nowrap">
                  <span
                    class="px-2 py-0.5 rounded-full text-xs font-medium"
                    :class="statusClass(t.status)"
                  >
                    {{ t.status }}
                  </span>
                  <span
                    v-if="t.quality_score"
                    class="inline-block w-2 h-2 ml-1 rounded-full"
                    :class="qualityDot(t.quality_score)"
                    :title="
                      $t('WHATSAPP_TEMPLATE_LIST.QUALITY', {
                        level: t.quality_score,
                      })
                    "
                  />
                </td>
                <!-- F6: dónde se puede mandar, en un renglón: conversación · seguimientos. -->
                <td class="py-2 pr-3 text-xs whitespace-nowrap">
                  <span
                    v-if="sendabilityOf(t).conversation === null"
                    class="text-slate-300"
                  >
                    —
                  </span>
                  <span v-else class="inline-flex items-center gap-2">
                    <span
                      :title="$t('WHATSAPP_TEMPLATE_DETAIL.SEND.CONVERSATION')"
                      :class="
                        sendabilityOf(t).conversation
                          ? 'text-green-700 dark:text-green-300'
                          : 'text-slate-400'
                      "
                    >
                      {{
                        $t(
                          sendabilityOf(t).conversation
                            ? 'WHATSAPP_TEMPLATE_LIST.SEND.CONV_YES'
                            : 'WHATSAPP_TEMPLATE_LIST.SEND.CONV_NO'
                        )
                      }}
                    </span>
                    <span
                      :title="
                        $t(
                          `WHATSAPP_TEMPLATE_DETAIL.SEND.TRACKINGS_${sendabilityOf(
                            t
                          ).trackings.toUpperCase()}`
                        )
                      "
                      :class="{
                        'text-green-700 dark:text-green-300':
                          sendabilityOf(t).trackings === 'ok',
                        'text-amber-700 dark:text-amber-400':
                          sendabilityOf(t).trackings === 'missing_file',
                        'text-slate-400': sendabilityOf(t).trackings === 'no',
                      }"
                    >
                      {{
                        $t(
                          `WHATSAPP_TEMPLATE_LIST.SEND.TRACK_${sendabilityOf(
                            t
                          ).trackings.toUpperCase()}`
                        )
                      }}
                    </span>
                  </span>
                </td>
                <td class="py-2 pr-3 text-xs text-slate-500 whitespace-nowrap">
                  <div>{{ formatDate(t.created_at) }}</div>
                  <div class="text-slate-400">{{ creatorName(t) }}</div>
                </td>
                <td class="py-2 pr-3 text-xs text-slate-500 whitespace-nowrap">
                  {{ formatDate(t.updated_at) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div
          v-if="filteredTemplates.length"
          class="flex items-center gap-3 border-t shrink-0 border-slate-100 dark:border-slate-700"
        >
          <label
            class="flex items-center gap-2 mb-0 text-xs whitespace-nowrap text-slate-500"
          >
            {{ $t('WHATSAPP_TEMPLATE_LIST.PER_PAGE') }}
            <select v-model.number="perPage" class="!w-auto h-8 !mb-0 text-xs">
              <option v-for="n in perPageOptions" :key="n" :value="n">
                {{ n }}
              </option>
            </select>
          </label>
          <TableFooter
            class="flex-1"
            :current-page="currentPage"
            :total-count="filteredTemplates.length"
            :page-size="perPage"
            @pageChange="onPageChange"
          />
        </div>
      </div>
    </template>

    <woot-modal :show.sync="deletePopup" :on-close="closeDelete">
      <DeleteTemplateModal
        v-if="deleteTarget"
        :template="deleteTarget"
        :deleting="deleting"
        @close="closeDelete"
        @confirm="doDelete"
      />
    </woot-modal>
  </SettingsLayout>
</template>

<style scoped lang="scss">
.list-filter {
  @apply w-auto h-9 mb-0 text-sm;
}

.sort-header {
  @apply inline-flex items-center gap-1 p-0 font-medium bg-transparent border-0 cursor-pointer text-slate-400 hover:text-slate-700 dark:hover:text-slate-200;
}

.sort-header--active {
  @apply text-slate-700 dark:text-slate-200;
}
</style>
