<!--
  @waba_templates — Sección de Configuración: TODAS las plantillas de TODOS los canales de
  WhatsApp, con filtro por canal. Crear/editar/borrar/sincronizar contra Meta.
  Validación en vivo replicada del backend. Strings en español; commit --no-verify.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import ResizableTextArea from 'shared/components/ResizableTextArea.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import {
  validateTemplate,
  templateVariables,
  substituteVariables,
} from 'dashboard/helper/whatsappTemplateValidator';

const emptyForm = () => ({
  inbox_id: null,
  name: '',
  language: 'es',
  category: 'UTILITY',
  header_type: 'text',
  header_content: '',
  header_media_url: '',
  body_text: '',
  footer_text: '',
  buttons: [],
  sample_values: { body: [], header: [] },
});

export default {
  components: { ResizableTextArea, SettingsLayout, BaseSettingsHeader },
  data() {
    return {
      channelFilter: '',
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
    filteredTemplates() {
      if (!this.channelFilter) return this.templates;
      return this.templates.filter(
        t => t.channel_whatsapp_id === Number(this.channelFilter)
      );
    },
    bodyVarCount() {
      return new Set(templateVariables(this.form.body_text)).size;
    },
    headerHasVar() {
      return (
        this.form.header_type === 'text' &&
        templateVariables(this.form.header_content).length > 0
      );
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
    // Enforca la regla de Meta al escribir: solo [a-z0-9_], sin espacios ni acentos.
    'form.name'(val) {
      const clean = this.sanitizeName(val);
      if (clean !== val) this.form.name = clean;
    },
  },
  mounted() {
    this.$store.dispatch('inboxes/get');
    this.fetchAll();
  },
  methods: {
    fetchAll() {
      this.$store.dispatch('whatsappTemplates/fetch');
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
      try {
        let created = 0;
        let updated = 0;
        // eslint-disable-next-line no-restricted-syntax
        const results = await Promise.all(
          targets.map(id => this.$store.dispatch('whatsappTemplates/sync', id))
        );
        results.forEach(r => {
          created += r.created;
          updated += r.updated;
        });
        await this.fetchAll();
        useAlert(`Sincronizado: ${created} nuevas, ${updated} actualizadas.`);
      } catch (e) {
        useAlert('No se pudo sincronizar con Meta.');
      }
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
            template: this.form,
          });
          useAlert('Plantilla enviada a revisión (PENDING).');
        } else {
          await this.$store.dispatch('whatsappTemplates/create', {
            inboxId: this.form.inbox_id,
            template: this.form,
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
      <div class="flex items-center gap-3 mb-4">
        <span class="text-sm text-slate-500">Filtrar por canal:</span>
        <select v-model="channelFilter" class="!mb-0 !w-64">
          <option value="">Todos los canales</option>
          <option
            v-for="i in whatsappInboxes"
            :key="i.id"
            :value="i.channel_id"
          >
            {{ i.name }}
          </option>
        </select>
      </div>

      <div
        v-if="!filteredTemplates.length"
        class="text-center text-slate-400 py-16 border border-dashed border-slate-200 dark:border-slate-700 rounded-lg"
      >
        No hay plantillas para mostrar. Crea una o sincroniza desde Meta.
      </div>

      <table v-else class="w-full text-sm">
        <thead
          class="text-left text-slate-400 border-b border-slate-100 dark:border-slate-700"
        >
          <tr>
            <th class="py-2 font-medium">Nombre</th>
            <th class="py-2 font-medium">Canal</th>
            <th class="py-2 font-medium">Idioma</th>
            <th class="py-2 font-medium">Categoría</th>
            <th class="py-2 font-medium">Estado</th>
            <th class="py-2 font-medium">Calidad</th>
            <th class="py-2 font-medium text-right">Acciones</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="t in filteredTemplates"
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
            <td class="py-3 text-right">
              <woot-button
                v-if="t.editable"
                variant="clear"
                size="small"
                icon="edit"
                @click="openEdit(t)"
              />
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
              <option v-for="c in categories" :key="c" :value="c">{{ c }}</option>
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
        <woot-input
          v-else
          v-model="form.header_media_url"
          label="Archivo de la cabecera"
          placeholder="URL del archivo de cabecera"
          class="mt-2"
        />
        <woot-input
          v-if="headerHasVar"
          v-model="form.sample_values.header[0]"
          label="Ejemplo de la variable de la cabecera"
          placeholder="Ejemplo para la variable de la cabecera"
          class="mt-2"
        />

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
              placeholder="https://…"
              class="flex-1 !mb-0"
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
