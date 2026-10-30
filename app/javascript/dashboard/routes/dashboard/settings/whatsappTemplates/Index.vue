<!--
  @waba_templates — Sección de Configuración: TODAS las plantillas de TODOS los canales de
  WhatsApp, con filtro por canal. Crear/editar/borrar/sincronizar contra Meta.
  Validación en vivo replicada del backend. Strings en español; commit --no-verify.

  feat/plantillas_whatsapp_mejoras F6 (docs/plantillas_whatsapp_mejoras_plan.md): subir el
  archivo de muestra del encabezado, vista previa con el archivo real, filtros por idioma y
  tipo, «se puede enviar» por plantilla, errores de sincronización por bandeja y «Ver en Meta».
  La lógica nueva vive en templateScreen.js (puro, con spec).
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import ResizableTextArea from 'shared/components/ResizableTextArea.vue';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import {
  validateTemplate,
  templateVariables,
  substituteVariables,
  COPY_CODE_MAX as copyCodeMax,
} from 'dashboard/helper/whatsappTemplateValidator';
import WhatsappTemplatesAPI from 'dashboard/api/whatsapp/templates';
import {
  KIND_OPTIONS,
  templateKinds,
  sendability,
  metaManagerUrl,
} from './templateScreen';

const emptyForm = () => ({
  inbox_id: null,
  name: '',
  language: 'es',
  category: 'UTILITY',
  header_type: 'text',
  header_content: '',
  header_media_url: '',
  // F6: el archivo subido (signed_id que se manda), su nombre y una liga para la vista previa.
  header_sample: null,
  header_sample_name: '',
  header_preview_url: '',
  body_text: '',
  footer_text: '',
  buttons: [],
  sample_values: { body: [], header: [] },
});

export default {
  components: {
    ResizableTextArea,
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
      uploadingSample: false,
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
      showForm: false,
      editingId: null,
      form: emptyForm(),
      deletePopup: false,
      deleteTarget: null,
      categories: ['UTILITY', 'MARKETING', 'AUTHENTICATION'],
      headerTypes: [
        { value: '', label: 'Ninguna' },
        { value: 'text', label: 'Texto' },
        { value: 'image', label: 'Imagen' },
        { value: 'video', label: 'Video' },
        { value: 'document', label: 'Documento' },
      ],
      buttonTypes: ['QUICK_REPLY', 'URL', 'PHONE_NUMBER', 'COPY_CODE'],
      formTabIndex: 0,
      formTabs: [
        { key: 'content', name: 'Contenido' },
        { key: 'buttons', name: 'Botones' },
        { key: 'preview', name: 'Vista previa' },
      ],
      bodyHint: 'Cuerpo (obligatorio) — usa {{1}}, {{2}}… para variables',
      headerTextHint: 'Texto de cabecera (máx 60, opcional {{1}})',
      sampleLabel: n => `Valor de {{${n}}}`,
      // En el script: Vue 2 no deja escribir {{1}} dentro de un atributo de la plantilla.
      urlButtonPlaceholder: 'https://… (puede terminar en {{1}})',
      nameHint:
        'Se formatea automáticamente (minúsculas, sin espacios ni acentos). No se puede cambiar después.',
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
    bodyVarCount() {
      return new Set(templateVariables(this.form.body_text)).size;
    },
    // N.º de variables distintas en la cabecera de texto (Meta permite {{1}}).
    headerVarCount() {
      if (this.form.header_type !== 'text') return 0;
      return new Set(templateVariables(this.form.header_content)).size;
    },
    validationErrors() {
      const errors = validateTemplate(this.form);
      if (!this.editingId && !this.form.inbox_id) {
        errors.unshift('Canal: selecciona un canal de WhatsApp');
      }
      return errors;
    },
    isFormValid() {
      return this.validationErrors.length === 0;
    },
    // Errores a MOSTRAR: se omiten los de "campo obligatorio" (ya marcados en la etiqueta);
    // solo se listan los de reglas/formato. Los obligatorios siguen contando en isFormValid.
    visibleErrors() {
      const requiredRe = /obligatorio|falta el contenido|selecciona un canal/i;
      return this.validationErrors.filter(e => !requiredRe.test(e));
    },
    // El formulario ya se empezó a llenar (para no mostrar errores en un form recién abierto).
    isDirty() {
      const f = this.form;
      return Boolean(
        f.name ||
          f.body_text ||
          f.footer_text ||
          f.header_content ||
          f.header_media_url ||
          (f.buttons && f.buttons.length)
      );
    },
    // feat/plantillas_whatsapp_mejoras: autenticación no se crea aquí (formato fijo de Meta);
    // solo aparece al editar una que ya la tenga, para que el validador diga por qué.
    formCategories() {
      const base = this.categories.filter(c => c !== 'AUTHENTICATION');
      return this.form.category === 'AUTHENTICATION'
        ? [...base, 'AUTHENTICATION']
        : base;
    },
    modalTitle() {
      return this.editingId ? 'Editar plantilla' : 'Nueva plantilla';
    },
    activeFormTab() {
      return this.formTabs[this.formTabIndex].key;
    },
    modalDescription() {
      return this.editingId
        ? 'Meta solo permite cambiar la categoría y el contenido; el nombre y el idioma quedan fijos. Al guardar, la plantilla vuelve a revisión (PENDING).'
        : 'Define el contenido y envíala a Meta para su aprobación. Usa {{1}}, {{2}}… para las variables. La cabecera puede ser texto, imagen, video o documento.';
    },
    // Códigos de idioma de Meta; incluye el actual si es uno fuera de la lista (p. ej. al editar).
    languageOptions() {
      const base = ['es', 'es_MX', 'es_AR', 'es_ES', 'en', 'en_US', 'pt_BR'];
      if (this.form.language && !base.includes(this.form.language)) {
        return [this.form.language, ...base];
      }
      return base;
    },
    // ---- vista previa (cómo verá el cliente la plantilla) ----
    previewHeaderText() {
      if (this.form.header_type !== 'text') return '';
      return substituteVariables(
        this.form.header_content,
        this.form.sample_values.header
      );
    },
    // F6: el archivo real del encabezado en la vista previa (subido o pegado).
    previewMediaUrl() {
      if (!['image', 'video', 'document'].includes(this.form.header_type))
        return '';
      return this.form.header_preview_url || this.form.header_media_url || '';
    },
    previewDocName() {
      if (this.form.header_sample_name) return this.form.header_sample_name;
      const liga = this.form.header_media_url || '';
      return liga.split('?')[0].split('/').pop() || 'Documento';
    },
    headerMediaLabel() {
      return (
        {
          image: '🖼️ Imagen',
          video: '🎬 Video',
          document: '📄 Documento',
        }[this.form.header_type] || ''
      );
    },
    previewBody() {
      return substituteVariables(
        this.form.body_text,
        this.form.sample_values.body
      );
    },
    footerCounter() {
      return `${this.form.footer_text.length} / 60`;
    },
    headerTextCounter() {
      return `${this.form.header_content.length} / 60`;
    },
  },
  watch: {
    'form.body_text'() {
      this.syncBodySamples();
    },
    'form.header_content'() {
      this.syncHeaderSamples();
    },
    'form.header_type'() {
      this.syncHeaderSamples();
    },
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
    // Enforca la regla de Meta al escribir: solo [a-z0-9_], sin espacios ni acentos.
    'form.name'(val) {
      const clean = this.sanitizeName(val);
      if (clean !== val) this.form.name = clean;
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
          DRAFT: 'Borrador local (no enviada): bórrala y créala de nuevo.',
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
    // F6: sube el archivo de muestra; el signed_id se manda al crear o editar.
    async uploadSample(event) {
      const archivo = event.target.files && event.target.files[0];
      event.target.value = '';
      if (!archivo) return;
      this.uploadingSample = true;
      try {
        const { data } = await WhatsappTemplatesAPI.uploadHeaderSample(
          this.form.header_type,
          archivo
        );
        this.form.header_sample = data.signed_id;
        this.form.header_sample_name = data.filename;
        this.form.header_preview_url = data.url;
      } catch (e) {
        useAlert(
          (e.response && e.response.data && e.response.data.error) ||
            'No se pudo subir el archivo.'
        );
      } finally {
        this.uploadingSample = false;
      }
    },
    clearSample() {
      this.form.header_sample = null;
      this.form.header_sample_name = '';
      this.form.header_preview_url = '';
    },
    // Lo que se manda: el archivo subido solo si se subió uno nuevo (un null lo borraría).
    templatePayload() {
      const payload = { ...this.form };
      ['header_sample_name', 'header_preview_url', 'header_media_link'].forEach(
        llave => delete payload[llave]
      );
      if (!payload.header_sample) delete payload.header_sample;
      return payload;
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
    onFormTabChange(index) {
      this.formTabIndex = index;
    },
    // Normaliza el nombre a la regla de Meta: minúsculas, espacios→_, sin acentos ni símbolos.
    sanitizeName(val) {
      return String(val || '')
        .toLowerCase()
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '') // quita diacríticos (á→a, ñ→n)
        .replace(/\s+/g, '_') // espacios → guion bajo
        .replace(/[^a-z0-9_]/g, '') // descarta lo demás
        .slice(0, 512);
    },
    openNew() {
      this.editingId = null;
      this.formTabIndex = 0;
      this.form = emptyForm();
      this.form.inbox_id = this.channelFilterInboxId();
      this.showForm = true;
    },
    // Deriva el inbox_id a partir del filtro (channelFilter guarda channel_whatsapp_id).
    channelFilterInboxId() {
      if (!this.channelFilter) return null;
      const inbox = this.whatsappInboxes.find(
        i => i.channel_id === Number(this.channelFilter)
      );
      return inbox ? inbox.id : null;
    },
    openEdit(template) {
      this.editingId = template.id;
      this.formTabIndex = 0;
      this.form = {
        ...emptyForm(),
        ...template,
        sample_values: {
          body: (template.sample_values && template.sample_values.body) || [],
          header:
            (template.sample_values && template.sample_values.header) || [],
        },
        buttons: [...(template.buttons || [])],
        // F6: el archivo ya guardado se muestra; solo se manda si se sube otro.
        header_sample: null,
        header_sample_name:
          (template.header_sample && template.header_sample.filename) || '',
        header_preview_url: template.header_media_link || '',
      };
      this.showForm = true;
    },
    closeForm() {
      this.showForm = false;
    },
    syncBodySamples() {
      const count = this.bodyVarCount;
      const current = this.form.sample_values.body || [];
      const next = Array.from({ length: count }, (_, i) => current[i] || '');
      this.form.sample_values = { ...this.form.sample_values, body: next };
    },
    syncHeaderSamples() {
      const count = this.headerVarCount;
      const current = this.form.sample_values.header || [];
      const next = Array.from({ length: count }, (_, i) => current[i] || '');
      this.form.sample_values = { ...this.form.sample_values, header: next };
    },
    addButton() {
      this.form.buttons.push({
        type: 'QUICK_REPLY',
        text: '',
        url: '',
        phone_number: '',
        example: [],
      });
    },
    removeButton(index) {
      this.form.buttons.splice(index, 1);
    },
    // feat/plantillas_whatsapp_mejoras: el ejemplo que Meta pide para revisar el botón de
    // código y el de liga con {{1}} (va en `example`, un arreglo de un valor).
    needsButtonExample(btn) {
      if (btn.type === 'COPY_CODE') return true;
      return btn.type === 'URL' && templateVariables(btn.url).length > 0;
    },
    buttonExample(btn) {
      return (Array.isArray(btn.example) ? btn.example[0] : btn.example) || '';
    },
    setButtonExample(btn, value) {
      this.$set(btn, 'example', [value]);
    },
    buttonExamplePlaceholder(btn) {
      return btn.type === 'COPY_CODE'
        ? `Código de ejemplo (máx ${copyCodeMax})`
        : 'Ejemplo de la liga completa (https://…/12345)';
    },
    // Etiqueta del botón en la vista previa (icono según tipo + texto).
    buttonPreviewLabel(btn) {
      const icon =
        {
          URL: '🔗',
          PHONE_NUMBER: '📞',
          COPY_CODE: '📋',
          QUICK_REPLY: '↩️',
        }[btn.type] || '';
      const text =
        btn.type === 'COPY_CODE' ? 'Copiar código' : btn.text || 'Botón';
      return `${icon} ${text}`.trim();
    },
    async submit() {
      if (!this.isFormValid) return;
      try {
        if (this.editingId) {
          await this.$store.dispatch('whatsappTemplates/update', {
            id: this.editingId,
            template: this.templatePayload(),
          });
          useAlert('Plantilla enviada a revisión (PENDING).');
        } else {
          await this.$store.dispatch('whatsappTemplates/create', {
            inboxId: this.form.inbox_id,
            template: this.templatePayload(),
          });
          useAlert('Plantilla creada.');
        }
        this.closeForm();
      } catch (e) {
        const msg =
          e?.response?.data?.error || 'No se pudo guardar la plantilla.';
        useAlert(msg);
      }
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
              <div class="font-medium text-slate-700 dark:text-slate-200">
                {{ t.name }}
              </div>
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

    <!-- Formulario crear/editar -->
    <woot-modal :show.sync="showForm" :on-close="closeForm" size="waba-wide">
      <div class="p-8">
        <h3 class="text-lg font-medium mb-1">{{ modalTitle }}</h3>
        <p class="text-sm text-slate-500 mb-4">{{ modalDescription }}</p>

        <woot-tabs
              :index="formTabIndex"
              border
              @change="onFormTabChange"
            >
              <woot-tabs-item
                v-for="tab in formTabs"
                :key="tab.key"
                :name="tab.name"
                :count="tab.key === 'buttons' ? form.buttons.length : 0"
                :show-badge="tab.key === 'buttons' && form.buttons.length > 0"
              />
            </woot-tabs>

            <!-- Las 3 pestañas se apilan en la MISMA celda del grid: el alto es el de la
                 más alta (Contenido) y no cambia al cambiar de pestaña. -->
            <div class="grid">
            <div
              class="col-start-1 row-start-1 pt-4"
              :class="{ invisible: activeFormTab !== 'content' }"
            >
        <label v-if="!editingId" class="block mb-2">
          Canal de WhatsApp (obligatorio)
          <select v-model="form.inbox_id" class="w-full">
            <option :value="null" disabled>Selecciona un canal</option>
            <option v-for="i in whatsappInboxes" :key="i.id" :value="i.id">
              {{ i.name }}
            </option>
          </select>
        </label>

        <div class="grid grid-cols-2 gap-4">
          <div class="relative">
            <woot-input
              v-model="form.name"
              label="Nombre (obligatorio)"
              placeholder="cobro_vencido"
              :readonly="!!editingId"
              class="!mb-0"
            />
            <span
              :title="nameHint"
              class="absolute top-0 ltr:right-0 rtl:left-0 flex items-center text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 cursor-pointer"
            >
              <fluent-icon icon="info" size="18" />
            </span>
          </div>
          <label class="block">
            Idioma
            <select
              v-model="form.language"
              :disabled="!!editingId"
              class="w-full"
            >
              <option v-for="l in languageOptions" :key="l" :value="l">
                {{ l }}
              </option>
            </select>
          </label>
        </div>

        <div class="grid grid-cols-2 gap-4 mt-2">
          <label class="block">
            Categoría
            <select v-model="form.category" class="w-full">
              <option v-for="c in formCategories" :key="c" :value="c">
                {{ c }}
              </option>
            </select>
          </label>
          <label class="block">
            Cabecera
            <select v-model="form.header_type" class="w-full">
              <option v-for="h in headerTypes" :key="h.value" :value="h.value">
                {{ h.label }}
              </option>
            </select>
          </label>
        </div>
        <!-- Contenido de la cabecera: SIEMPRE visible (reserva el espacio). Cambia según el
             tipo; cuando es "Ninguna" se muestra deshabilitado. -->
        <div
          v-if="form.header_type === 'text' || form.header_type === ''"
          class="relative mt-2"
          :class="{ 'opacity-60': form.header_type === '' }"
        >
          <woot-input
            v-model="form.header_content"
            label="Texto de la cabecera"
            :placeholder="
              form.header_type === '' ? 'Sin cabecera' : headerTextHint
            "
            :readonly="form.header_type === ''"
            class="!mb-0"
          />
          <span
            v-if="form.header_type === 'text'"
            class="absolute top-0 ltr:right-0 rtl:left-0 text-xs"
            :class="
              form.header_content.length > 60 ? 'text-red-500' : 'text-slate-400'
            "
          >
            {{ headerTextCounter }}
          </span>
        </div>
        <!-- F6: subir el archivo de muestra (o pegar una liga pública). El subido es el que
             se manda a Meta como muestra y el que usan los seguimientos y campañas. -->
        <div v-else class="mt-2">
          <span class="text-sm">Archivo de la cabecera</span>
          <div class="flex flex-wrap items-center gap-2 mt-1">
            <label
              class="inline-flex items-center gap-1 px-3 h-9 text-sm rounded-md cursor-pointer bg-woot-50 text-woot-700 dark:bg-woot-800 dark:text-woot-100"
              :class="{ 'opacity-60 pointer-events-none': uploadingSample }"
            >
              <fluent-icon icon="attach" size="16" />
              {{ uploadingSample ? 'Subiendo…' : 'Subir archivo' }}
              <input
                type="file"
                class="hidden"
                :accept="
                  {
                    image: 'image/jpeg,image/png',
                    video: 'video/mp4,video/3gpp',
                    document: 'application/pdf',
                  }[form.header_type]
                "
                @change="uploadSample"
              />
            </label>
            <span
              v-if="form.header_sample_name"
              class="inline-flex items-center gap-1 text-sm text-slate-700 dark:text-slate-200"
            >
              {{ form.header_sample_name }}
              <button
                v-if="form.header_sample"
                type="button"
                class="text-slate-400 hover:text-red-500"
                title="Quitar el archivo subido"
                @click="clearSample"
              >
                <fluent-icon icon="dismiss" size="12" />
              </button>
            </span>
            <span class="text-xs text-slate-400">
              {{
                {
                  image: 'JPG o PNG, hasta 5 MB',
                  video: 'MP4, hasta 16 MB',
                  document: 'PDF, hasta 100 MB',
                }[form.header_type]
              }}
            </span>
          </div>
          <woot-input
            v-model="form.header_media_url"
            placeholder="…o pega una liga pública del archivo (https://…)"
            class="mt-2 !mb-0"
          />
        </div>

        <label class="block mt-2">
          <span class="flex items-center justify-between text-sm">
            <span>{{ bodyHint }}</span>
            <span
              class="text-xs font-normal"
              :class="
                form.body_text.length > 1024 ? 'text-red-500' : 'text-slate-400'
              "
            >
              {{ form.body_text.length }} / 1024
            </span>
          </span>
          <ResizableTextArea
            v-model="form.body_text"
            :rows="4"
            class="w-full mt-1 !h-28 overflow-y-auto"
          />
        </label>

        <div class="relative mt-2">
          <woot-input
            v-model="form.footer_text"
            label="Pie (opcional, sin variables)"
            class="!mb-0"
          />
          <span
            class="absolute top-0 ltr:right-0 rtl:left-0 text-xs"
            :class="
              form.footer_text.length > 60 ? 'text-red-500' : 'text-slate-400'
            "
          >
            {{ footerCounter }}
          </span>
        </div>
            </div>

            <div
              class="col-start-1 row-start-1 pt-4"
              :class="{ invisible: activeFormTab !== 'buttons' }"
            >
        <div class="mt-1">
          <div class="flex items-center justify-between">
            <span class="text-sm text-slate-600 dark:text-slate-300">Botones</span>
            <woot-button variant="clear" size="tiny" icon="add" @click="addButton">
              Agregar
            </woot-button>
          </div>
          <p class="text-xs text-slate-400 mt-1 mb-2">
            Hasta 10 botones. Las respuestas rápidas van agrupadas al inicio; luego los de acción (URL, teléfono, código).
          </p>
          <div class="max-h-72 overflow-y-auto pr-1">
          <div
            v-for="(btn, i) in form.buttons"
            :key="i"
            class="flex gap-2 items-center mt-2"
          >
            <select v-model="btn.type" class="w-40">
              <option v-for="bt in buttonTypes" :key="bt" :value="bt">
                {{ bt }}
              </option>
            </select>
            <woot-input
              v-if="btn.type !== 'COPY_CODE'"
              v-model="btn.text"
              placeholder="Texto (máx 25)"
              class="flex-1 !mb-0"
            />
            <woot-input
              v-if="btn.type === 'URL'"
              v-model="btn.url"
              :placeholder="urlButtonPlaceholder"
              class="flex-1 !mb-0"
            />
            <woot-input
              v-if="needsButtonExample(btn)"
              :value="buttonExample(btn)"
              :placeholder="buttonExamplePlaceholder(btn)"
              class="flex-1 !mb-0"
              @input="setButtonExample(btn, $event)"
            />
            <woot-input
              v-if="btn.type === 'PHONE_NUMBER'"
              v-model="btn.phone_number"
              placeholder="+52…"
              class="flex-1 !mb-0"
            />
            <woot-button
              variant="clear"
              size="tiny"
              color-scheme="alert"
              icon="delete"
              @click="removeButton(i)"
            />
          </div>
          </div>
        </div>
            </div>

            <!-- Vista previa: cómo verá el cliente la plantilla en WhatsApp -->
            <div
              class="col-start-1 row-start-1 pt-4"
              :class="{ invisible: activeFormTab !== 'preview' }"
            >
            <div v-if="headerVarCount" class="max-w-sm mx-auto mb-4">
              <span class="text-xs text-slate-500 dark:text-slate-300">
                Ejemplos de las variables de la cabecera
              </span>
              <div class="grid grid-cols-2 gap-2 mt-1">
                <woot-input
                  v-for="i in headerVarCount"
                  :key="`h-${i}`"
                  v-model="form.sample_values.header[i - 1]"
                  :placeholder="sampleLabel(i)"
                />
              </div>
            </div>

            <div v-if="bodyVarCount" class="max-w-sm mx-auto mb-4">
              <span class="text-xs text-slate-500 dark:text-slate-300">
                Ejemplos de las variables del cuerpo
              </span>
              <div class="grid grid-cols-2 gap-2 mt-1">
                <woot-input
                  v-for="i in bodyVarCount"
                  :key="i"
                  v-model="form.sample_values.body[i - 1]"
                  :placeholder="sampleLabel(i)"
                />
              </div>
              <p class="text-xs text-slate-400 mt-1">
                Se usan en la vista previa y como example al enviarla a Meta.
              </p>
            </div>

            <p class="text-sm text-slate-500 mb-3 text-center">
              Así verá el cliente el mensaje en WhatsApp.
            </p>
            <div
              class="mt-2 max-w-sm mx-auto rounded-lg p-3 text-sm shadow-sm bg-green-50 dark:bg-green-900/30 border border-green-100 dark:border-green-800 text-slate-800 dark:text-slate-100"
            >
            <div v-if="previewHeaderText" class="font-semibold mb-1">
              {{ previewHeaderText }}
            </div>
            <!-- F6: el archivo real si ya hay uno (subido o pegado). -->
            <img
              v-else-if="previewMediaUrl && form.header_type === 'image'"
              :src="previewMediaUrl"
              alt=""
              class="mb-2 rounded max-h-48 w-full object-cover"
            />
            <video
              v-else-if="previewMediaUrl && form.header_type === 'video'"
              :src="previewMediaUrl"
              controls
              preload="metadata"
              class="mb-2 rounded max-h-48 w-full"
            />
            <div
              v-else-if="previewMediaUrl && form.header_type === 'document'"
              class="flex items-center gap-2 mb-2 rounded px-3 py-3 bg-black/5 dark:bg-white/10"
            >
              <fluent-icon icon="document" size="24" class="text-red-500" />
              <span class="truncate">{{ previewDocName }}</span>
            </div>
            <div
              v-else-if="headerMediaLabel"
              class="mb-2 rounded px-3 py-6 text-center text-slate-400 bg-black/5 dark:bg-white/10"
            >
              {{ headerMediaLabel }}
            </div>
            <div class="whitespace-pre-wrap break-words">
              {{ previewBody || 'El cuerpo aparecerá aquí…' }}
            </div>
            <div v-if="form.footer_text" class="text-xs text-slate-400 mt-1">
              {{ form.footer_text }}
            </div>
            <div
              v-if="form.buttons.length"
              class="mt-2 -mx-3 px-3 pt-1 border-t border-green-200 dark:border-green-800"
            >
              <div
                v-for="(btn, i) in form.buttons"
                :key="i"
                class="text-center py-1 text-sky-600 dark:text-sky-400"
              >
                {{ buttonPreviewLabel(btn) }}
              </div>
            </div>
          </div>
          </div>
          </div>

        <ul
          v-if="isDirty && visibleErrors.length"
          class="mt-4 text-xs text-red-500 list-disc pl-5"
        >
          <li v-for="(err, i) in visibleErrors" :key="i">{{ err }}</li>
        </ul>

        <div class="flex justify-end gap-2 mt-6">
          <woot-button variant="clear" @click="closeForm">Cancelar</woot-button>
          <woot-button
            :is-disabled="!isFormValid"
            :is-loading="uiFlags.saving"
            @click="submit"
          >
            {{ editingId ? 'Guardar y reenviar' : 'Crear y enviar' }}
          </woot-button>
        </div>
      </div>
    </woot-modal>

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

<style lang="scss">
// Ancho FIJO para el modal de plantillas: no crece ni se encoge con el contenido;
// solo se limita en pantallas muy pequeñas con el tope de viewport.
.modal-container.waba-wide {
  @apply w-[52rem] max-w-[92vw];
}
</style>
