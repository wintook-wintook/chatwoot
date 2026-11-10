<script>
/**
 * This component handles parsing and sending WhatsApp message templates.
 * It works as follows:
 * 1. Displays the template text with variable placeholders.
 * 2. Generates input fields for each variable in the template.
 * 3. Validates that all variables are filled before sending.
 * 4. Replaces placeholders with user-provided values.
 * 5. Emits events to send the processed message or reset the template.
 *
 * feat/plantillas_whatsapp_mejoras F2: con `fullTemplate` (bandeja WhatsApp Cloud)
 * también pide lo que la plantilla lleve además del cuerpo: el archivo del encabezado
 * (liga y, si es documento, su nombre), las variables del encabezado de texto y los
 * botones con dato (URL con {{1}}, copiar código). Qué se pide y qué se manda lo decide
 * templateForm.js (puro, con su spec). Sin `fullTemplate` se comporta como siempre.
 *
 * El archivo del encabezado tiene tres orígenes: el guardado en la plantilla (subido en la
 * pantalla de plantillas; si existe, viene elegido y el agente solo da «Enviar»), uno que
 * el agente sube de su máquina para este envío, o una liga pública.
 */
import { ref, computed, onMounted } from 'vue';
import { resolveVariables } from 'dashboard/helper/whatsappTemplateVariables';
import TemplateExtraFields from './TemplateExtraFields.vue';
import TemplateVariableHint from './TemplateVariableHint.vue';
import {
  describeTemplate,
  buildProcessedParams,
  validateValues,
  renderPreview,
  COPY_CODE_MAX,
} from './templateForm';

export default {
  components: { TemplateExtraFields, TemplateVariableHint },
  props: {
    template: {
      type: Object,
      default: () => ({}),
    },
    // WhatsApp Cloud: se mandan encabezado, archivo y botones (F1). En 360dialog y
    // UnoAPI solo el cuerpo, como siempre.
    fullTemplate: {
      type: Boolean,
      default: false,
    },
    // La bandeja: para traer el archivo guardado de la plantilla.
    inboxId: {
      type: Number,
      default: undefined,
    },
    // F9.3: con qué llenar las variables con nombre (chatVariableContext). Se pueden cambiar.
    variableContext: {
      type: Object,
      default: () => ({}),
    },
  },
  setup(props, { emit }) {
    const processVariable = str => {
      return str.replace(/{{|}}/g, '');
    };

    const processedParams = ref({});
    // Archivo, encabezado y botones: los captura TemplateExtraFields.
    const extraValues = ref({});
    const errors = ref([]);

    const info = computed(() => describeTemplate(props.template));
    const showMedia = computed(() => props.fullTemplate && info.value.media);

    const templateString = computed(() => {
      return props.template.components.find(
        component => component.type === 'BODY'
      ).text;
    });

    const variables = computed(() => {
      return templateString.value.match(/{{([^}]+)}}/g);
    });

    const processedString = computed(() => {
      return templateString.value.replace(/{{([^}]+)}}/g, (match, variable) => {
        const variableKey = processVariable(variable);
        return processedParams.value[variableKey] || `{{${variable}}}`;
      });
    });

    const values = computed(() => ({
      ...extraValues.value,
      body: processedParams.value,
    }));

    const preview = computed(() => renderPreview(props.template, values.value));

    const generateVariables = () => {
      const matchedVariables = templateString.value.match(/{{([^}]+)}}/g);
      if (!matchedVariables) return;

      const finalVars = matchedVariables.map(i => processVariable(i));
      const { values: resueltos } = resolveVariables(
        finalVars,
        props.variableContext
      );
      processedParams.value = finalVars.reduce(
        (acc, variable) => ({ ...acc, [variable]: resueltos[variable] || '' }),
        {}
      );
    };

    const resetTemplate = () => {
      emit('resetTemplate');
    };

    const sendMessage = () => {
      const opciones = { components: props.fullTemplate };
      errors.value = validateValues(props.template, values.value, opciones);
      if (errors.value.length) return;

      const payload = {
        message: processedString.value,
        templateParams: {
          name: props.template.name,
          category: props.template.category,
          language: props.template.language,
          namespace: props.template.namespace,
          processed_params: buildProcessedParams(
            props.template,
            values.value,
            opciones
          ),
        },
      };
      emit('sendMessage', payload);
    };

    onMounted(generateVariables);

    return {
      processedParams,
      extraValues,
      errors,
      showMedia,
      preview,
      variables,
      templateString,
      processedString,
      copyCodeMax: COPY_CODE_MAX,
      resetTemplate,
      sendMessage,
    };
  },
};
</script>

<template>
  <div class="w-full">
    <div class="template__preview">
      <p v-if="showMedia" class="preview__media">
        {{
          $t(`WHATSAPP_TEMPLATES.PARSER.MEDIA_${preview.media.toUpperCase()}`)
        }}
        <span v-if="preview.mediaName"> · {{ preview.mediaName }}</span>
      </p>
      <p v-if="preview.header" class="preview__header">{{ preview.header }}</p>
      <textarea
        v-model="processedString"
        rows="4"
        readonly
        class="template-input"
      />
      <p v-if="preview.footer" class="preview__footer">{{ preview.footer }}</p>
      <div v-if="preview.buttons.length" class="preview__buttons">
        <span v-for="(boton, i) in preview.buttons" :key="`btn-${i}`">
          {{ boton }}
        </span>
      </div>
    </div>

    <TemplateExtraFields
      :template="template"
      :enabled="fullTemplate"
      :inbox-id="inboxId"
      :variable-context="variableContext"
      @change="extraValues = $event"
    >
      <div v-if="variables" class="template__variables-container">
        <p class="variables-label">
          {{ $t('WHATSAPP_TEMPLATES.PARSER.VARIABLES_LABEL') }}
        </p>
        <div
          v-for="(variable, key) in processedParams"
          :key="key"
          class="template__variable-item flex-wrap"
        >
          <span class="variable-label">
            {{ key }}
          </span>
          <woot-input
            v-model="processedParams[key]"
            type="text"
            class="variable-input"
            :styles="{ marginBottom: 0 }"
          />
          <TemplateVariableHint
            :variable="key"
            :value="processedParams[key]"
            :context="variableContext"
          />
        </div>
      </div>
    </TemplateExtraFields>

    <p v-for="error in errors" :key="error" class="error">
      {{
        $t(`WHATSAPP_TEMPLATES.PARSER.ERRORS.${error}`, { max: copyCodeMax })
      }}
    </p>
    <footer>
      <woot-button variant="smooth" @click="resetTemplate">
        {{ $t('WHATSAPP_TEMPLATES.PARSER.GO_BACK_LABEL') }}
      </woot-button>
      <woot-button type="button" @click="sendMessage">
        {{ $t('WHATSAPP_TEMPLATES.PARSER.SEND_MESSAGE_LABEL') }}
      </woot-button>
    </footer>
  </div>
</template>

<style scoped lang="scss">
.template__preview {
  @apply mb-2.5;

  .preview__media {
    @apply text-xs font-semibold text-slate-600 dark:text-slate-300 mb-1;
  }

  .preview__header {
    @apply text-sm font-semibold mb-1 text-slate-800 dark:text-slate-100;
  }

  .preview__footer {
    @apply text-xs text-slate-500 dark:text-slate-400 mt-1;
  }

  .preview__buttons {
    @apply flex flex-wrap gap-2 mt-2;

    span {
      @apply text-xs px-2 py-1 rounded-md border border-solid border-slate-200 dark:border-slate-600 text-woot-600 dark:text-woot-300;
    }
  }
}

.template__variables-container {
  @apply p-2.5;
}

.variables-label {
  @apply text-sm font-semibold mb-2.5;
}

.template__variable-item {
  @apply items-center flex mb-2.5;

  .label {
    @apply text-xs;
  }

  .variable-input {
    @apply flex-1 text-sm ml-2.5;
  }

  .variable-label {
    @apply bg-slate-75 dark:bg-slate-700 text-slate-700 dark:text-slate-100 inline-block rounded-md text-xs py-2.5 px-6;
  }
}

footer {
  @apply flex justify-end;

  button {
    @apply ml-2.5;
  }
}
.error {
  @apply bg-red-100 dark:bg-red-100 rounded-md text-red-800 dark:text-red-800 p-2.5 text-center mb-2;
}
.template-input {
  @apply bg-slate-25 dark:bg-slate-900 text-slate-700 dark:text-slate-100;
}
</style>
