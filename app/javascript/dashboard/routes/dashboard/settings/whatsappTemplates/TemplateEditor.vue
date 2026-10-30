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
import {
  validateTemplate,
  COPY_CODE_MAX,
} from 'dashboard/helper/whatsappTemplateValidator';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import TemplatePreview from './TemplatePreview.vue';
import {
  ACCEPTED_TYPES,
  BUTTON_TYPES,
  HEADER_TYPES,
  MEDIA_HEADER_TYPES,
  buttonExample,
  emptyButton,
  emptyForm,
  formCategories,
  formFromTemplate,
  isLocalDraft,
  languageOptions,
  needsButtonExample,
  sanitizeName,
  syncSamples,
  templatePayload,
} from './templateEditor';

const LIST_ROUTE = 'whatsapp_templates_index';

export default {
  components: {
    BaseSettingsHeader,
    ResizableTextArea,
    SettingsLayout,
    TemplatePreview,
  },
  data() {
    return {
      form: emptyForm(),
      template: null,
      loading: false,
      notFound: false,
      uploadingSample: false,
      formTabIndex: 0,
      // SettingsWrapper guarda la página en caché (keep-alive): al volver se recarga.
      inactive: false,
      headerTypes: HEADER_TYPES,
      buttonTypes: BUTTON_TYPES,
      copyCodeMax: COPY_CODE_MAX,
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
      ].map(tab => ({
        ...tab,
        name: this.$t(`WHATSAPP_TEMPLATE_EDITOR.TABS.${tab.key.toUpperCase()}`),
      }));
    },
    activeTab() {
      return this.formTabs[this.formTabIndex].key;
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
  },
  mounted() {
    this.$store.dispatch('inboxes/get');
    this.load();
  },
  activated() {
    if (this.inactive) this.load();
  },
  deactivated() {
    this.inactive = true;
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
      } finally {
        this.loading = false;
      }
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
    headerTypeLabel(tipo) {
      return this.$t(
        `WHATSAPP_TEMPLATE_EDITOR.HEADER_TYPES.${(
          tipo || 'none'
        ).toUpperCase()}`
      );
    },
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
    addButton() {
      this.form.buttons.push(emptyButton());
    },
    removeButton(index) {
      this.form.buttons.splice(index, 1);
    },
    needsButtonExample,
    buttonExample,
    setButtonExample(boton, value) {
      this.$set(boton, 'example', [value]);
    },
    buttonExamplePlaceholder(boton) {
      return boton.type === 'COPY_CODE'
        ? this.$t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.EXAMPLE_CODE', {
            max: this.copyCodeMax,
          })
        : this.$t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.EXAMPLE_URL');
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
        // Meta lo rechazó y quedó como borrador: se sigue editando ese.
        if (data.template) this.openSaved(data.template);
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
              <label v-if="!isEditing" class="block">
                {{ $t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.INBOX') }}
                <select v-model="form.inbox_id">
                  <option :value="null" disabled>
                    {{
                      $t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.INBOX_PLACEHOLDER')
                    }}
                  </option>
                  <option
                    v-for="i in whatsappInboxes"
                    :key="i.id"
                    :value="i.id"
                  >
                    {{ i.name }}
                  </option>
                </select>
              </label>
              <p v-else class="mb-4 text-sm text-slate-600 dark:text-slate-300">
                {{ $t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.INBOX') }}:
                <strong>{{ inboxName }}</strong>
              </p>

              <div class="grid grid-cols-2 gap-4">
                <woot-input
                  v-model="form.name"
                  :label="$t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.NAME')"
                  :placeholder="
                    $t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.NAME_PLACEHOLDER')
                  "
                  :help-text="$t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.NAME_HINT')"
                  :readonly="!isDraft"
                />
                <label class="block">
                  {{ $t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.LANGUAGE') }}
                  <select v-model="form.language" :disabled="!isDraft">
                    <option v-for="l in languages" :key="l" :value="l">
                      {{ l }}
                    </option>
                  </select>
                </label>
              </div>

              <div class="grid grid-cols-2 gap-4">
                <label class="block">
                  {{ $t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.CATEGORY') }}
                  <select v-model="form.category">
                    <option v-for="c in categories" :key="c" :value="c">
                      {{ $t(`WHATSAPP_TEMPLATE_EDITOR.CATEGORIES.${c}`) }}
                    </option>
                  </select>
                  <span class="help-text">
                    {{
                      $t(
                        `WHATSAPP_TEMPLATE_EDITOR.CATEGORY_HINTS.${form.category}`
                      )
                    }}
                  </span>
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
              </div>
              <div v-else-if="isMediaHeader" class="mb-4">
                <span class="text-sm">
                  {{ $t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.HEADER_FILE') }}
                </span>
                <div class="flex flex-wrap items-center gap-2 mt-1">
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

              <label class="block">
                <span class="flex items-center justify-between">
                  <span>{{
                    $t('WHATSAPP_TEMPLATE_EDITOR.SECTIONS.BODY')
                  }}</span>
                  <span
                    class="text-xs"
                    :class="
                      form.body_text.length > 1024
                        ? 'text-red-500'
                        : 'text-slate-400'
                    "
                  >
                    {{ bodyCount }}
                  </span>
                </span>
                <ResizableTextArea
                  v-model="form.body_text"
                  :rows="4"
                  :placeholder="
                    $t('WHATSAPP_TEMPLATE_EDITOR.FIELDS.BODY_PLACEHOLDER', {
                      variable: variableSample,
                    })
                  "
                  class="!h-28 overflow-y-auto"
                />
              </label>

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
              <div class="flex items-center justify-between">
                <p class="mb-0 text-xs text-slate-400">
                  {{ $t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.HINT') }}
                </p>
                <woot-button
                  variant="clear"
                  size="small"
                  icon="add"
                  :is-disabled="form.buttons.length >= 10"
                  @click="addButton"
                >
                  {{ $t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.ADD') }}
                </woot-button>
              </div>
              <p
                v-if="!form.buttons.length"
                class="py-8 text-sm text-center text-slate-400"
              >
                {{ $t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.EMPTY') }}
              </p>
              <div
                v-for="(boton, i) in form.buttons"
                :key="i"
                class="flex items-center gap-2 mt-2"
              >
                <select v-model="boton.type" class="w-40 !mb-0 shrink-0">
                  <option v-for="tipo in buttonTypes" :key="tipo" :value="tipo">
                    {{ $t(`WHATSAPP_TEMPLATE_EDITOR.BUTTONS.TYPES.${tipo}`) }}
                  </option>
                </select>
                <woot-input
                  v-if="boton.type !== 'COPY_CODE'"
                  v-model="boton.text"
                  :placeholder="
                    $t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.TEXT_PLACEHOLDER')
                  "
                  class="flex-1 !mb-0"
                />
                <woot-input
                  v-if="boton.type === 'URL'"
                  v-model="boton.url"
                  :placeholder="
                    $t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.URL_PLACEHOLDER', {
                      variable: variableSample,
                    })
                  "
                  class="flex-1 !mb-0"
                />
                <woot-input
                  v-if="boton.type === 'PHONE_NUMBER'"
                  v-model="boton.phone_number"
                  :placeholder="
                    $t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.PHONE_PLACEHOLDER')
                  "
                  class="flex-1 !mb-0"
                />
                <woot-input
                  v-if="needsButtonExample(boton)"
                  :value="buttonExample(boton)"
                  :placeholder="buttonExamplePlaceholder(boton)"
                  class="flex-1 !mb-0"
                  @input="setButtonExample(boton, $event)"
                />
                <woot-button
                  variant="clear"
                  size="small"
                  color-scheme="alert"
                  icon="delete"
                  :title="$t('WHATSAPP_TEMPLATE_EDITOR.BUTTONS.REMOVE')"
                  @click="removeButton(i)"
                />
              </div>
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
          <ul
            v-if="validationErrors.length"
            class="pl-4 m-0 text-xs text-red-600 list-disc dark:text-red-400"
          >
            <li v-for="(error, i) in validationErrors" :key="i">
              {{ error }}
            </li>
          </ul>
        </aside>
      </div>
    </template>
  </SettingsLayout>
</template>
