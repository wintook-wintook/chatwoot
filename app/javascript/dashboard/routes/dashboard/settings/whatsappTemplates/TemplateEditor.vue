<!--
  feat/plantillas_whatsapp_mejoras F10.1 — CREAR Y EDITAR UNA PLANTILLA A PÁGINA COMPLETA
  Plan: docs/plantillas_whatsapp_mejoras_plan.md §7.12–7.13. Reemplaza al modal de Index.vue
  con el mismo encabezado nativo que la lista (SettingsLayout + BaseSettingsHeader, con
  «‹ Plantillas de WhatsApp» junto a las acciones, a la derecha) y las MISMAS pestañas del modal
  (Contenido · Botones · Variables), apiladas en la misma celda para que el alto no cambie
  y no haya que bajar. La vista previa queda siempre a la derecha.

  «Guardar borrador» guarda sin llamar a Meta (D10b); un borrador se manda a revisión
  después, desde aquí. La lógica pura vive en templateEditor.js (con spec); la validación,
  en dashboard/helper/whatsappTemplateValidator.js (réplica de Whatsapp::TemplateValidator).
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import ResizableTextArea from 'shared/components/ResizableTextArea.vue';
import WhatsappTemplatesAPI from 'dashboard/api/whatsapp/templates';
import { validateTemplate } from 'dashboard/helper/whatsappTemplateValidator';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import TemplatePreview from './TemplatePreview.vue';
import TemplateButtonsEditor from './TemplateButtonsEditor.vue';
import {
  ACCEPTED_TYPES,
  HEADER_TYPES,
  MEDIA_HEADER_TYPES,
  emptyForm,
  formCategories,
  formFromTemplate,
  isLocalDraft,
  languageOptions,
  FORMAT_MARKERS,
  duplicateForm,
  errorsByTab,
  formSnapshot,
  insertAt,
  nextVariable,
  sanitizeName,
  syncSamples,
  wrapSelection,
  templatePayload,
} from './templateEditor';

const LIST_ROUTE = 'whatsapp_templates_index';

export default {
  components: {
    BaseSettingsHeader,
    ResizableTextArea,
    SettingsLayout,
    TemplateButtonsEditor,
    TemplatePreview,
  },
  // Salir con cambios sin guardar: se pregunta con el modal nativo.
  async beforeRouteLeave(to, from, next) {
    if (!this.hasUnsavedChanges) {
      next();
      return;
    }
    next(await this.$refs.leaveDialog.showConfirmation());
  },
  data() {
    return {
      form: emptyForm(),
      template: null,
      loading: false,
      notFound: false,
      uploadingSample: false,
      draggingFile: false,
      // Cómo estaba el formulario al abrirlo o al guardar: para avisar si se sale con cambios.
      savedSnapshot: '',
      formTabIndex: 0,
      // SettingsWrapper guarda la página en caché (keep-alive): al volver se recarga.
      inactive: false,
      headerTypes: HEADER_TYPES,
      // Vue 2 no deja escribir {{1}} dentro de un texto traducido ni de un atributo.
      variableSample: '{{1}}',
    };
  },
  computed: {
    ...mapGetters({
      templates: 'whatsappTemplates/getTemplates',
      uiFlags: 'whatsappTemplates/getUIFlags',
      inboxes: 'inboxes/getInboxes',
    }),
    templateId() {
      return Number(this.$route.params.templateId) || null;
    },
    isEditing() {
      return Boolean(this.templateId);
    },
    isDraft() {
      return !this.isEditing || isLocalDraft(this.template);
    },
    whatsappInboxes() {
      return this.inboxes.filter(i => i.channel_type === 'Channel::Whatsapp');
    },
    inboxName() {
      const inbox = this.template
        ? this.whatsappInboxes.find(
            i => i.channel_id === this.template.channel_whatsapp_id
          )
        : null;
      return inbox ? inbox.name : '';
    },
    title() {
      if (!this.isEditing) return this.$t('WHATSAPP_TEMPLATE_EDITOR.NEW_TITLE');
      const titulo = this.$t('WHATSAPP_TEMPLATE_EDITOR.EDIT_TITLE', {
        name: this.form.name,
      });
      return this.isDraft
        ? `${titulo} · ${this.$t('WHATSAPP_TEMPLATE_EDITOR.DRAFT_BADGE')}`
        : titulo;
    },
    description() {
      if (!this.isEditing) return this.$t('WHATSAPP_TEMPLATE_EDITOR.NEW_DESC');
      return this.isDraft
        ? this.$t('WHATSAPP_TEMPLATE_EDITOR.DRAFT_DESC')
        : this.$t('WHATSAPP_TEMPLATE_EDITOR.EDIT_DESC');
    },
    categories() {
      return formCategories(this.form.category);
    },
    languages() {
      return languageOptions(this.form.language);
    },
    isMediaHeader() {
      return MEDIA_HEADER_TYPES.includes(this.form.header_type);
    },
    acceptedTypes() {
      return ACCEPTED_TYPES[this.form.header_type] || '';
    },
    bodySampleKeys() {
      return this.form.sample_values.body.map((_, i) => `{{${i + 1}}}`);
    },
    headerSampleKeys() {
      return this.form.sample_values.header.map((_, i) => `{{${i + 1}}}`);
    },
    validationErrors() {
      const errors = validateTemplate(this.form);
      if (!this.isEditing && !this.form.inbox_id) {
        errors.unshift(this.$t('WHATSAPP_TEMPLATE_EDITOR.NO_INBOX'));
      }
      return errors;
    },
    hasUnsavedChanges() {
      return (
        Boolean(this.savedSnapshot) &&
        formSnapshot(this.form) !== this.savedSnapshot
      );
    },
    canSubmit() {
      return this.validationErrors.length === 0;
    },
    // Un borrador necesita bandeja y nombre (el resto se termina después).
    canSaveDraft() {
      return Boolean(this.form.name && (this.isEditing || this.form.inbox_id));
    },
    submitLabel() {
      return this.isDraft
        ? this.$t('WHATSAPP_TEMPLATE_EDITOR.ACTIONS.SUBMIT')
        : this.$t('WHATSAPP_TEMPLATE_EDITOR.ACTIONS.RESUBMIT');
    },
    headerTextCount() {
      return `${this.form.header_content.length} / 60`;
    },
    bodyCount() {
      return `${this.form.body_text.length} / 1024`;
    },
    formTabs() {
      return [
        { key: 'content', count: 0 },
        { key: 'buttons', count: this.form.buttons.length },
        {
          key: 'variables',
          count:
            this.form.sample_values.body.length +
            this.form.sample_values.header.length,
        },
      ].map(tab => {
        const nombre = this.$t(
          `WHATSAPP_TEMPLATE_EDITOR.TABS.${tab.key.toUpperCase()}`
        );
        const errores = this.tabErrors[tab.key];
        // La pestaña con algo pendiente lleva un punto (woot-tabs-item solo tiene nombre).
        return {
          ...tab,
          label: nombre,
          errors: errores,
          name: errores.length ? `${nombre} •` : nombre,
        };
      });
    },
    tabErrors() {
      return errorsByTab(this.validationErrors);
    },
    activeTab() {
      return this.formTabs[this.formTabIndex].key;
    },
    formatButtons() {
      return Object.keys(FORMAT_MARKERS).map(key => ({
        key,
        label: this.$t(`WHATSAPP_TEMPLATE_EDITOR.FORMAT.${key}`),
        title: this.$t('WHATSAPP_TEMPLATE_EDITOR.FORMAT.HINT', {
          marker: FORMAT_MARKERS[key],
        }),
      }));
    },
    headerHasVariable() {
      return /\{\{\s*\d+\s*\}\}/.test(this.form.header_content);
    },
    hasVariables() {
      return this.headerSampleKeys.length + this.bodySampleKeys.length > 0;
    },
    footerCount() {
      return `${this.form.footer_text.length} / 60`;
    },
  },
  watch: {
    'form.name'(val) {
      const limpio = sanitizeName(val);
      if (limpio !== val) this.form.name = limpio;
    },
    'form.body_text'(text) {
      this.form.sample_values.body = syncSamples(
        this.form.sample_values.body,
        text
      );
    },
    'form.header_content'() {
      this.syncHeaderSamples();
    },
    'form.header_type'() {
      this.syncHeaderSamples();
    },
    templateId() {
      this.load();
    },
    '$route.query.from'() {
      if (!this.isEditing) this.load();
    },
  },
  mounted() {
    this.$store.dispatch('inboxes/get');
    this.load();
    window.addEventListener('beforeunload', this.onBeforeUnload);
  },
  activated() {
    window.addEventListener('beforeunload', this.onBeforeUnload);
    if (this.inactive) this.load();
  },
  deactivated() {
    this.inactive = true;
    window.removeEventListener('beforeunload', this.onBeforeUnload);
  },
  beforeDestroy() {
    window.removeEventListener('beforeunload', this.onBeforeUnload);
  },
  methods: {
    async load() {
      this.notFound = false;
      this.inactive = false;
      this.formTabIndex = 0;
      if (!this.isEditing) {
        this.template = null;
        this.form = emptyForm();
        this.form.inbox_id = Number(this.$route.query.inbox_id) || null;
        await this.loadDuplicate();
        this.markSaved();
        return;
      }
      this.loading = true;
      try {
        if (!this.templates.length) {
          await this.$store.dispatch('whatsappTemplates/fetch');
        }
        const template = this.templates.find(t => t.id === this.templateId);
        if (!template) {
          this.notFound = true;
          return;
        }
        this.template = template;
        this.form = formFromTemplate(template);
        this.markSaved();
      } finally {
        this.loading = false;
      }
    },
    // «Duplicar» desde la ficha (F10.4): /new?from=<id> arranca con todo copiado.
    async loadDuplicate() {
      const origen = Number(this.$route.query.from);
      if (!origen) return;
      if (!this.templates.length) {
        await this.$store.dispatch('whatsappTemplates/fetch');
      }
      const template = this.templates.find(t => t.id === origen);
      if (!template) return;
      const inbox = this.whatsappInboxes.find(
        i => i.channel_id === template.channel_whatsapp_id
      );
      this.form = duplicateForm(template, inbox ? inbox.id : null);
    },
    syncHeaderSamples() {
      const texto =
        this.form.header_type === 'text' ? this.form.header_content : '';
      this.form.sample_values.header = syncSamples(
        this.form.sample_values.header,
        texto
      );
    },
    onTabChange(index) {
      this.formTabIndex = index;
    },
    goToTab(key) {
      this.formTabIndex = this.formTabs.findIndex(t => t.key === key);
    },
    // El <textarea> del mensaje (ResizableTextArea lo expone en su ref).
    bodyTextarea() {
      const area = this.$refs.bodyInput;
      return area && area.$refs.textarea;
    },
    // Cambia el mensaje y deja el cursor (o la selección) donde corresponde.
    setBody(texto, inicio, fin = inicio) {
      this.form.body_text = texto;
      this.$nextTick(() => {
        const area = this.bodyTextarea();
        if (!area) return;
        area.focus();
        area.setSelectionRange(inicio, fin);
      });
    },
    addBodyVariable() {
      const area = this.bodyTextarea();
      const largo = this.form.body_text.length;
      const inicio = area ? area.selectionStart : largo;
      const fin = area ? area.selectionEnd : largo;
      const { text, cursor } = insertAt(
        this.form.body_text,
        inicio,
        fin,
        nextVariable(this.form.body_text)
      );
      this.setBody(text, cursor);
    },
    applyFormat(key) {
      const area = this.bodyTextarea();
      const largo = this.form.body_text.length;
      const { text, selectionStart, selectionEnd } = wrapSelection(
        this.form.body_text,
        area ? area.selectionStart : largo,
        area ? area.selectionEnd : largo,
        FORMAT_MARKERS[key]
      );
      this.setBody(text, selectionStart, selectionEnd);
    },
    // Meta deja una sola variable en el encabezado: {{1}}.
    addHeaderVariable() {
      if (this.headerHasVariable) return;
      const texto = this.form.header_content.trimEnd();
      this.form.header_content = texto ? `${texto} {{1}}` : '{{1}}';
    },
    headerTypeLabel(tipo) {
      return this.$t(
        `WHATSAPP_TEMPLATE_EDITOR.HEADER_TYPES.${(
          tipo || 'none'
        ).toUpperCase()}`
      );
    },
    // Después de que corren los watchers (ejemplos, nombre), para no contar eso como cambio.
    markSaved() {
      this.$nextTick(() => {
        this.savedSnapshot = formSnapshot(this.form);
      });
    },
    // Cerrar la pestaña o recargar con cambios: el aviso del propio navegador.
    onBeforeUnload(event) {
      if (!this.hasUnsavedChanges) return;
      event.preventDefault();
      event.returnValue = '';
    },
    uploadSample(event) {
      const archivo = event.target.files && event.target.files[0];
      event.target.value = '';
      if (archivo) this.uploadFile(archivo);
    },
    onFileDrop(event) {
      this.draggingFile = false;
      const archivo = event.dataTransfer && event.dataTransfer.files[0];
      if (!archivo) return;
      if (!this.acceptedTypes.split(',').includes(archivo.type)) {
        useAlert(
          this.$t('WHATSAPP_TEMPLATE_EDITOR.ALERTS.WRONG_TYPE', {
            allowed: this.$t(
              `WHATSAPP_TEMPLATE_EDITOR.LIMITS.${this.form.header_type.toUpperCase()}`
            ),
          })
        );
        return;
      }
      this.uploadFile(archivo);
    },
    async uploadFile(archivo) {
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
            this.$t('WHATSAPP_TEMPLATE_EDITOR.ALERTS.UPLOAD_ERROR')
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
    goToList() {
      this.$router.push({ name: LIST_ROUTE });
    },
    async save({ draft }) {
      const template = { ...templatePayload(this.form) };
      try {
        const data = this.isEditing
          ? await this.$store.dispatch('whatsappTemplates/update', {
              id: this.templateId,
              template,
              draft,
            })
          : await this.$store.dispatch('whatsappTemplates/create', {
              inboxId: this.form.inbox_id,
              template,
              draft,
            });
        this.savedSnapshot = formSnapshot(this.form);
        if (draft) {
          useAlert(this.$t('WHATSAPP_TEMPLATE_EDITOR.ALERTS.DRAFT_SAVED'));
          this.openSaved(data);
          return;
        }
        useAlert(
          this.isDraft
            ? this.$t('WHATSAPP_TEMPLATE_EDITOR.ALERTS.SUBMITTED')
            : this.$t('WHATSAPP_TEMPLATE_EDITOR.ALERTS.RESUBMITTED')
        );
        this.goToList();
      } catch (e) {
        const data = (e.response && e.response.data) || {};
        useAlert(
          data.error || this.$t('WHATSAPP_TEMPLATE_EDITOR.ALERTS.SAVE_ERROR')
        );
        // Meta lo rechazó y quedó como borrador (ya guardado): se sigue editando ese.
        if (data.template) {
          this.savedSnapshot = formSnapshot(this.form);
          this.openSaved(data.template);
        }
      }
    },
    // Lo guardado sigue en el editor (una plantilla nueva pasa a su /edit).
    openSaved(template) {
      if (this.templateId === template.id) {
        this.template = template;
        return;
      }
      this.$router.replace({
        name: 'whatsapp_templates_edit',
        params: { templateId: template.id },
      });
    },
  },
};
</script>

<template>
  <SettingsLayout
    :is-loading="loading"
    :loading-message="$t('WHATSAPP_TEMPLATE_EDITOR.LOADING')"
    :no-records-found="notFound"
    :no-records-message="$t('WHATSAPP_TEMPLATE_EDITOR.NOT_FOUND')"
  >
    <template #header>
      <BaseSettingsHeader :title="title" :description="description">
        <template #actions>
          <!-- El regreso va con las acciones (no arriba del título) para ganar espacio;
               hace lo mismo que «Cancelar», así que lo reemplaza. -->
          <woot-button variant="clear" icon="chevron-left" @click="goToList">
            {{ $t('WHATSAPP_TEMPLATE_EDITOR.HEADER') }}
          </woot-button>
          <woot-button
            v-if="isDraft"
            variant="hollow"
            :is-disabled="!canSaveDraft"
            :is-loading="uiFlags.saving"
            @click="save({ draft: true })"
          >
            {{ $t('WHATSAPP_TEMPLATE_EDITOR.ACTIONS.SAVE_DRAFT') }}
          </woot-button>
          <woot-button
            :is-disabled="!canSubmit"
            :is-loading="uiFlags.saving"
            @click="save({ draft: false })"
          >
            {{ submitLabel }}
          </woot-button>
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div
        class="grid w-full grid-cols-1 gap-6 lg:grid-cols-[minmax(0,1fr)_22rem] items-start"
      >
        <div class="min-w-0">
          <woot-tabs :index="formTabIndex" border @change="onTabChange">
            <woot-tabs-item
              v-for="tab in formTabs"
              :key="tab.key"
              :name="tab.name"
              :count="tab.count"
              :show-badge="tab.count > 0"
            />
          </woot-tabs>

          <!-- Las 3 pestañas se apilan en la MISMA celda: el alto es el de la más alta
               (Contenido) y no cambia al cambiar de pestaña. -->
          <div class="grid">
            <!-- Contenido -->
            <div
              class="col-start-1 row-start-1 pt-4"
              :class="{ invisible: activeTab !== 'content' }"
            >
              <!-- Renglón 1: Bandeja · Nombre -->
              <div class="grid grid-cols-2 gap-4">
                <label class="block">
                  {{ $t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.INBOX') }}
                  <select v-model="form.inbox_id" :disabled="isEditing">
                    <option v-if="isEditing" :value="form.inbox_id">
                      {{ inboxName }}
                    </option>
                    <option v-else :value="null" disabled>
                      {{
                        $t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.INBOX_PLACEHOLDER')
                      }}
                    </option>
                    <template v-if="!isEditing">
                      <option
                        v-for="i in whatsappInboxes"
                        :key="i.id"
                        :value="i.id"
                      >
                        {{ i.name }}
                      </option>
                    </template>
                  </select>
                </label>
                <woot-input
                  v-model="form.name"
                  :label="$t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.NAME')"
                  :placeholder="
                    $t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.NAME_PLACEHOLDER')
                  "
                  :help-text="$t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.NAME_HINT')"
                  :readonly="!isDraft"
                />
              </div>

              <!-- Renglón 2: Idioma · Categoría · Encabezado -->
              <div class="grid grid-cols-3 gap-4">
                <label class="block">
                  {{ $t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.LANGUAGE') }}
                  <select v-model="form.language" :disabled="!isDraft">
                    <option v-for="l in languages" :key="l" :value="l">
                      {{ l }}
                    </option>
                  </select>
                </label>
                <label class="block">
                  {{ $t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.CATEGORY') }}
                  <select v-model="form.category">
                    <option v-for="c in categories" :key="c" :value="c">
                      {{ $t(`WHATSAPP_TEMPLATE_EDITOR.CATEGORIES.${c}`) }}
                    </option>
                  </select>
                </label>
                <label class="block">
                  {{ $t('WHATSAPP_TEMPLATE_EDITOR.SECTIONS.HEADER') }}
                  <select v-model="form.header_type">
                    <option
                      v-for="tipo in headerTypes"
                      :key="tipo || 'none'"
                      :value="tipo"
                    >
                      {{ headerTypeLabel(tipo) }}
                    </option>
                  </select>
                </label>
              </div>
              <p class="-mt-2 mb-4 help-text">
                {{
                  $t(`WHATSAPP_TEMPLATE_EDITOR.CATEGORY_HINTS.${form.category}`)
                }}
              </p>

              <div v-if="form.header_type === 'text'" class="relative">
                <woot-input
                  v-model="form.header_content"
                  :label="$t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.HEADER_TEXT')"
                  :placeholder="
                    $t(
                      'WHATSAPP_TEMPLATE_EDITOR.FIELDS.HEADER_TEXT_PLACEHOLDER',
                      { variable: variableSample }
                    )
                  "
                />
                <span
                  class="absolute top-0 text-xs ltr:right-0 rtl:left-0"
                  :class="
                    form.header_content.length > 60
                      ? 'text-red-500'
                      : 'text-slate-400'
                  "
                >
                  {{ headerTextCount }}
                </span>
                <woot-button
                  v-if="!headerHasVariable"
                  variant="clear"
                  size="tiny"
                  icon="add"
                  class="-mt-3 mb-2"
                  @click="addHeaderVariable"
                >
                  {{ $t('WHATSAPP_TEMPLATE_EDITOR.FORMAT.ADD_VARIABLE') }}
                </woot-button>
              </div>
              <div v-else-if="isMediaHeader" class="mb-4">
                <span class="text-sm">
                  {{ $t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.HEADER_FILE') }}
                </span>
                <div
                  class="drop-zone"
                  :class="{ 'drop-zone--active': draggingFile }"
                  @dragover.prevent="draggingFile = true"
                  @dragleave.prevent="draggingFile = false"
                  @drop.prevent="onFileDrop"
                >
                  <woot-button
                    variant="smooth"
                    size="small"
                    icon="attach"
                    :is-loading="uploadingSample"
                    @click="$refs.sampleInput.click()"
                  >
                    {{ $t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.UPLOAD') }}
                  </woot-button>
                  <input
                    ref="sampleInput"
                    type="file"
                    class="hidden"
                    :accept="acceptedTypes"
                    @change="uploadSample"
                  />
                  <span
                    v-if="form.header_sample_name"
                    class="inline-flex items-center gap-1 text-sm text-slate-700 dark:text-slate-200"
                  >
                    {{ form.header_sample_name }}
                    <woot-button
                      v-if="form.header_sample"
                      variant="clear"
                      size="tiny"
                      color-scheme="secondary"
                      icon="dismiss"
                      :title="$t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.REMOVE_FILE')"
                      @click="clearSample"
                    />
                  </span>
                  <span class="text-xs text-slate-400">
                    {{ $t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.OR_DROP') }} ·
                    {{
                      $t(
                        `WHATSAPP_TEMPLATE_EDITOR.LIMITS.${form.header_type.toUpperCase()}`
                      )
                    }}
                  </span>
                </div>
                <woot-input
                  v-model="form.header_media_url"
                  :placeholder="$t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.OR_LINK')"
                  class="mt-2 !mb-0"
                />
              </div>

              <div class="mb-4">
                <div class="flex flex-wrap items-center gap-1 mb-1">
                  <span class="text-sm">
                    {{ $t('WHATSAPP_TEMPLATE_EDITOR.SECTIONS.BODY') }}
                  </span>
                  <span class="flex-1" />
                  <woot-button
                    v-for="boton in formatButtons"
                    :key="boton.key"
                    variant="clear"
                    size="tiny"
                    color-scheme="secondary"
                    :title="boton.title"
                    @click="applyFormat(boton.key)"
                  >
                    {{ boton.label }}
                  </woot-button>
                  <woot-button
                    variant="smooth"
                    size="tiny"
                    icon="add"
                    @click="addBodyVariable"
                  >
                    {{ $t('WHATSAPP_TEMPLATE_EDITOR.FORMAT.ADD_VARIABLE') }}
                  </woot-button>
                  <span
                    class="ml-1 text-xs"
                    :class="
                      form.body_text.length > 1024
                        ? 'text-red-500'
                        : 'text-slate-400'
                    "
                  >
                    {{ bodyCount }}
                  </span>
                </div>
                <ResizableTextArea
                  ref="bodyInput"
                  v-model="form.body_text"
                  :rows="4"
                  :placeholder="
                    $t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.BODY_PLACEHOLDER', {
                      variable: variableSample,
                    })
                  "
                  class="!h-28 !mb-0 overflow-y-auto"
                />
              </div>

              <div class="relative">
                <woot-input
                  v-model="form.footer_text"
                  :label="$t('WHATSAPP_TEMPLATE_EDITOR.SECTIONS.FOOTER')"
                  :placeholder="
                    $t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.FOOTER_PLACEHOLDER')
                  "
                  class="!mb-0"
                />
                <span
                  class="absolute top-0 text-xs ltr:right-0 rtl:left-0"
                  :class="
                    form.footer_text.length > 60
                      ? 'text-red-500'
                      : 'text-slate-400'
                  "
                >
                  {{ footerCount }}
                </span>
              </div>
            </div>

            <!-- Botones -->
            <div
              class="col-start-1 row-start-1 pt-4"
              :class="{ invisible: activeTab !== 'buttons' }"
            >
              <TemplateButtonsEditor v-model="form.buttons" />
            </div>

            <!-- Variables: los ejemplos que revisa Meta y salen en la vista previa -->
            <div
              class="col-start-1 row-start-1 pt-4"
              :class="{ invisible: activeTab !== 'variables' }"
            >
              <p class="text-xs text-slate-400">
                {{ $t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.EXAMPLES') }}
              </p>
              <p
                v-if="!hasVariables"
                class="py-8 text-sm text-center text-slate-400"
              >
                {{
                  $t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.NO_VARIABLES', {
                    variable: variableSample,
                  })
                }}
              </p>
              <div
                v-if="headerSampleKeys.length"
                class="grid grid-cols-2 gap-x-4"
              >
                <woot-input
                  v-for="(clave, i) in headerSampleKeys"
                  :key="`h-${clave}`"
                  v-model="form.sample_values.header[i]"
                  :label="
                    $t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.EXAMPLE_OF_HEADER', {
                      variable: clave,
                    })
                  "
                />
              </div>
              <div
                v-if="bodySampleKeys.length"
                class="grid grid-cols-2 gap-x-4"
              >
                <woot-input
                  v-for="(clave, i) in bodySampleKeys"
                  :key="`b-${clave}`"
                  v-model="form.sample_values.body[i]"
                  :label="
                    $t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.EXAMPLE_OF', {
                      variable: clave,
                    })
                  "
                />
              </div>
            </div>
          </div>
        </div>

        <aside class="flex flex-col gap-3 pt-2">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
            {{ $t('WHATSAPP_TEMPLATE_EDITOR.SECTIONS.PREVIEW') }}
          </span>
          <TemplatePreview :form="form" />
          <div class="ready-list">
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
            >
              {{ $t('WHATSAPP_TEMPLATE_EDITOR.READY.TITLE') }}
            </span>
            <div v-for="tab in formTabs" :key="tab.key">
              <button
                type="button"
                class="ready-list__row"
                @click="goToTab(tab.key)"
              >
                <fluent-icon
                  :icon="
                    tab.errors.length ? 'error-circle' : 'checkmark-circle'
                  "
                  size="16"
                  :class="
                    tab.errors.length
                      ? 'text-red-500'
                      : 'text-green-600 dark:text-green-400'
                  "
                />
                <span>{{ tab.label }}</span>
              </button>
              <ul
                v-if="tab.errors.length"
                class="pl-8 m-0 mb-1 text-xs text-red-600 list-disc dark:text-red-400"
              >
                <li v-for="(error, i) in tab.errors" :key="i">{{ error }}</li>
              </ul>
            </div>
            <p
              v-if="canSubmit"
              class="mt-1 mb-0 text-xs text-green-700 dark:text-green-300"
            >
              {{ $t('WHATSAPP_TEMPLATE_EDITOR.READY.ALL_GOOD') }}
            </p>
          </div>
        </aside>
      </div>
    </template>

    <woot-confirm-modal
      ref="leaveDialog"
      :title="$t('WHATSAPP_TEMPLATE_EDITOR.LEAVE.TITLE')"
      :description="$t('WHATSAPP_TEMPLATE_EDITOR.LEAVE.DESCRIPTION')"
      :confirm-label="$t('WHATSAPP_TEMPLATE_EDITOR.LEAVE.CONFIRM')"
      :cancel-label="$t('WHATSAPP_TEMPLATE_EDITOR.LEAVE.CANCEL')"
    />
  </SettingsLayout>
</template>

<style scoped lang="scss">
.drop-zone {
  @apply flex flex-wrap items-center gap-2 p-3 mt-1 rounded-lg border border-dashed border-slate-200 dark:border-slate-600;
}

.drop-zone--active {
  @apply border-woot-500 bg-woot-25 dark:bg-woot-800;
}

.ready-list {
  @apply flex flex-col gap-1 p-3 rounded-lg border border-solid border-slate-100 dark:border-slate-700;
}

.ready-list__row {
  @apply flex items-center w-full gap-2 py-1 text-sm text-left text-slate-700 dark:text-slate-200 bg-transparent border-0 cursor-pointer;
}
</style>
