<script>
/**
 * feat/plantillas_variables_nombre F4 — LO QUE UNA PLANTILLA PIDE ADEMÁS DEL CUERPO
 *
 * El archivo del encabezado (el guardado en la plantilla, uno subido o una liga), las
 * variables del encabezado de texto y los botones con dato (liga con {{1}}, copiar código).
 * Lo usan la conversación (TemplateParser) y los mensajes programados
 * (ScheduleMessageModal), para que pidan lo mismo. Las variables del cuerpo son de cada
 * pantalla: van en el slot, entre el encabezado y los botones.
 *
 * Avisa con `change` { header, buttons, mediaUrl, mediaName, mediaSource, templateFile,
 * uploadedFile }, los valores que entienden buildProcessedParams y validateValues
 * (templateForm.js). `initial`: lo ya capturado, al editar un programado.
 * Sin `enabled` (bandejas que no son WhatsApp Cloud) solo muestra el slot.
 */
import WhatsappTemplateHeaderAPI from 'dashboard/api/whatsappTemplateHeader';
import { resolveVariables } from 'dashboard/helper/whatsappTemplateVariables';
import TemplateVariableHint from './TemplateVariableHint.vue';
import { describeTemplate, COPY_CODE_MAX } from './templateForm';

// Lo que Meta acepta en el encabezado (Whatsapp::ResumableUploadService::LIMITS).
const ACCEPTED_TYPES = {
  image: 'image/jpeg,image/png',
  video: 'video/mp4,video/3gpp',
  document: 'application/pdf',
};

const blank = lista =>
  lista.reduce((acc, clave) => ({ ...acc, [clave]: '' }), {});

export default {
  components: { TemplateVariableHint },
  props: {
    template: {
      type: Object,
      required: true,
    },
    enabled: {
      type: Boolean,
      default: false,
    },
    inboxId: {
      type: Number,
      default: undefined,
    },
    initial: {
      type: Object,
      default: () => ({}),
    },
    // F9.3: con qué llenar las variables con nombre del encabezado (chatVariableContext).
    variableContext: {
      type: Object,
      default: () => ({}),
    },
  },
  emits: ['change'],
  data() {
    const inicial = this.initial;
    return {
      headerParams: {},
      buttonParams: {},
      mediaUrl: inicial.mediaUrl || '',
      mediaName: inicial.mediaName || '',
      // El archivo guardado de la plantilla ({ media_name, preview_url }), el subido para
      // este envío ({ signed_id, filename, preview_url }) y cuál se usa.
      templateFile: null,
      uploadedFile: inicial.uploadedFile || null,
      mediaSource: inicial.mediaSource || 'link',
      uploading: false,
      uploadError: '',
      copyCodeMax: COPY_CODE_MAX,
    };
  },
  computed: {
    extras() {
      return this.enabled
        ? describeTemplate(this.template)
        : { media: null, headerVars: [], buttons: [] };
    },
    paramButtons() {
      return this.extras.buttons.filter(b => b.needsParam);
    },
    mediaSources() {
      return (this.templateFile ? ['template'] : []).concat(['upload', 'link']);
    },
    acceptedTypes() {
      return ACCEPTED_TYPES[this.extras.media] || '';
    },
    values() {
      return {
        header: this.headerParams,
        buttons: this.buttonParams,
        mediaUrl: this.mediaUrl,
        mediaName: this.mediaName,
        mediaSource: this.mediaSource,
        templateFile:
          this.mediaSource === 'template' ? this.templateFile : null,
        uploadedFile: this.uploadedFile,
      };
    },
  },
  watch: {
    values: {
      deep: true,
      immediate: true,
      handler(valores) {
        this.$emit('change', valores);
      },
    },
  },
  created() {
    this.headerParams = {
      ...blank(this.extras.headerVars),
      ...resolveVariables(this.extras.headerVars, this.variableContext).values,
      ...(this.initial.header || {}),
    };
    this.buttonParams = {
      ...blank(this.paramButtons.map(b => b.index)),
      ...(this.initial.buttons || {}),
    };
  },
  mounted() {
    this.loadTemplateFile();
  },
  methods: {
    async loadTemplateFile() {
      if (!this.extras.media || !this.inboxId) return;
      try {
        const { data } = await WhatsappTemplateHeaderAPI.show(this.inboxId, {
          name: this.template.name,
          language: this.template.language,
        });
        if (!data.available) return;
        this.templateFile = {
          media_name: data.media_name,
          preview_url: data.preview_url,
        };
        // Al editar se respeta lo que ya se había elegido.
        if (!this.initial.mediaSource) this.mediaSource = 'template';
      } catch {
        // Sin el archivo guardado se pide la liga, como antes.
      }
    },
    chooseFile() {
      if (this.$refs.fileInput) this.$refs.fileInput.click();
    },
    async onFileChosen(event) {
      const [file] = event.target.files || [];
      event.target.value = '';
      if (!file) return;
      this.uploading = true;
      this.uploadError = '';
      try {
        const { data } = await WhatsappTemplateHeaderAPI.upload(this.inboxId, {
          mediaType: this.extras.media,
          file,
        });
        this.uploadedFile = data;
        if (this.extras.media === 'document') this.mediaName = data.filename;
      } catch (error) {
        const data = (error && error.response && error.response.data) || {};
        this.uploadError = data.error || '';
        this.uploadedFile = null;
      } finally {
        this.uploading = false;
      }
    },
  },
};
</script>

<template>
  <div class="w-full">
    <div v-if="extras.media" class="template__variables-container">
      <p class="variables-label">
        {{ $t('WHATSAPP_TEMPLATES.PARSER.HEADER_LABEL') }}
      </p>
      <div class="media-sources">
        <woot-button
          v-for="origen in mediaSources"
          :key="origen"
          size="small"
          :variant="mediaSource === origen ? 'smooth' : 'clear'"
          @click="mediaSource = origen"
        >
          {{ $t(`WHATSAPP_TEMPLATES.PARSER.SOURCE_${origen.toUpperCase()}`) }}
        </woot-button>
      </div>
      <div
        v-if="mediaSource === 'template' && templateFile"
        class="template-file"
      >
        <span>{{ $t('WHATSAPP_TEMPLATES.PARSER.TEMPLATE_FILE') }}</span>
        <a
          :href="templateFile.preview_url"
          target="_blank"
          rel="noreferrer noopener nofollow"
        >
          {{
            templateFile.media_name ||
            $t('WHATSAPP_TEMPLATES.PARSER.TEMPLATE_FILE_OPEN')
          }}
        </a>
      </div>
      <div v-else-if="mediaSource === 'upload'" class="template-file">
        <input
          ref="fileInput"
          type="file"
          class="hidden"
          :accept="acceptedTypes"
          @change="onFileChosen"
        />
        <woot-button
          size="small"
          variant="smooth"
          icon="attach"
          :is-loading="uploading"
          @click="chooseFile"
        >
          {{
            uploadedFile
              ? $t('WHATSAPP_TEMPLATES.PARSER.CHANGE_FILE')
              : $t('WHATSAPP_TEMPLATES.PARSER.CHOOSE_FILE')
          }}
        </woot-button>
        <a
          v-if="uploadedFile && uploadedFile.preview_url"
          :href="uploadedFile.preview_url"
          target="_blank"
          rel="noreferrer noopener nofollow"
        >
          {{ uploadedFile.filename }}
        </a>
        <span v-else-if="uploadedFile">{{ uploadedFile.filename }}</span>
        <span v-if="uploadError" class="error">{{ uploadError }}</span>
      </div>
      <div v-else class="template__variable-item">
        <span class="variable-label">
          {{
            $t(`WHATSAPP_TEMPLATES.PARSER.MEDIA_${extras.media.toUpperCase()}`)
          }}
        </span>
        <woot-input
          v-model="mediaUrl"
          type="url"
          class="variable-input"
          :placeholder="$t('WHATSAPP_TEMPLATES.PARSER.MEDIA_URL_PLACEHOLDER')"
          :styles="{ marginBottom: 0 }"
        />
      </div>
      <div
        v-if="extras.media === 'document' && mediaSource !== 'template'"
        class="template__variable-item"
      >
        <span class="variable-label">
          {{ $t('WHATSAPP_TEMPLATES.PARSER.MEDIA_NAME_LABEL') }}
        </span>
        <woot-input
          v-model="mediaName"
          type="text"
          class="variable-input"
          :placeholder="$t('WHATSAPP_TEMPLATES.PARSER.MEDIA_NAME_PLACEHOLDER')"
          :styles="{ marginBottom: 0 }"
        />
      </div>
    </div>

    <div v-if="extras.headerVars.length" class="template__variables-container">
      <p class="variables-label">
        {{ $t('WHATSAPP_TEMPLATES.PARSER.HEADER_LABEL') }}
      </p>
      <div
        v-for="(variable, key) in headerParams"
        :key="`h-${key}`"
        class="template__variable-item flex-wrap"
      >
        <span class="variable-label">{{ key }}</span>
        <woot-input
          v-model="headerParams[key]"
          type="text"
          class="variable-input"
          :styles="{ marginBottom: 0 }"
        />
        <TemplateVariableHint
          :variable="key"
          :value="headerParams[key]"
          :context="variableContext"
        />
      </div>
    </div>

    <slot />

    <div v-if="paramButtons.length" class="template__variables-container">
      <p class="variables-label">
        {{ $t('WHATSAPP_TEMPLATES.PARSER.BUTTONS_LABEL') }}
      </p>
      <div
        v-for="boton in paramButtons"
        :key="`b-${boton.index}`"
        class="template__variable-item"
      >
        <span class="variable-label">
          {{
            boton.type === 'COPY_CODE'
              ? $t('WHATSAPP_TEMPLATES.PARSER.BUTTON_COPY_CODE', {
                  max: copyCodeMax,
                })
              : boton.text || $t('WHATSAPP_TEMPLATES.PARSER.BUTTON_URL')
          }}
        </span>
        <woot-input
          v-model="buttonParams[boton.index]"
          type="text"
          class="variable-input"
          :placeholder="boton.url"
          :styles="{ marginBottom: 0 }"
        />
      </div>
    </div>
  </div>
</template>

<style scoped lang="scss">
.template__variables-container {
  @apply p-2.5;
}

.variables-label {
  @apply text-sm font-semibold mb-2.5;
}

.template__variable-item {
  @apply items-center flex mb-2.5;

  .variable-label {
    @apply bg-slate-75 dark:bg-slate-700 text-slate-700 dark:text-slate-100 inline-block rounded-md text-xs py-2.5 px-6;
  }

  .variable-input {
    @apply flex-1 text-sm ml-2.5;
  }
}

.media-sources {
  @apply flex flex-wrap gap-1 mb-2.5;
}

.template-file {
  @apply flex flex-wrap items-center gap-2 mb-2.5 text-sm text-slate-700 dark:text-slate-200;

  a {
    @apply text-woot-600 dark:text-woot-300 underline break-all;
  }
}

.error {
  @apply bg-red-100 dark:bg-red-100 rounded-md text-red-800 dark:text-red-800 p-2.5 text-center mb-2;
}
</style>
