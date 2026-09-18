<script>
// proyecto@predefinidas_prompt — EL FORMULARIO DE UNA RESPUESTA PREDEFINIDA
// ============================================================================
// Plan: docs/predefinidas_prompt_plan.md (§3.4). Lo usan Agregar y Editar, que eran
// dos copias casi iguales del mismo formulario.
//
// Dos pestañas, porque son dos cosas distintas:
//   Mensaje              lo que se busca y lo que el agente usa como información.
//   Prompt de Contenido  cómo tiene que usar el agente ESE mensaje. El cliente nunca
//                        lo ve, y se aplica solo junto con el mensaje de esta
//                        respuesta. Vacío = el agente usa el mensaje como siempre.
//
// Las pestañas no esconden nada:
//   · la del prompt lleva un punto cuando tiene texto, para saber desde "Mensaje" que
//     esta respuesta se comporta distinto;
//   · si el mensaje (obligatorio) está vacío y se guarda desde la otra pestaña, el
//     formulario vuelve a "Mensaje", que es donde está el error.
//
// Y avisa de las etiquetas que nombra el prompt: si una no existe en la cuenta, o
// lleva tildes o eñes, no dispara nada (el motor lee #[a-z0-9_]: de
// "#SolicitaCotización" lee "#SolicitaCotizaci"). Avisa, no bloquea.
// ============================================================================
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import WootSubmitButton from 'dashboard/components/buttons/FormSubmitButton.vue';

// Lo que alguien escribió después de un "#", hasta un espacio o una puntuación.
const WRITTEN_TAG_RE = /#[^\s#.,;:!?¿¡()"'«»]+/g;
// Lo que el motor lee como etiqueta (ANY_TAG_RE del motor).
const ENGINE_TAG_RE = /#[a-z0-9_]{3,}/i;

const MESSAGE_TAB = 0;
const PROMPT_TAB = 1;

export default {
  components: { WootMessageEditor, WootSubmitButton },
  props: {
    shortCode: { type: String, default: '' },
    content: { type: String, default: '' },
    contentPrompts: { type: String, default: '' },
    submitText: { type: String, default: '' },
    cancelText: { type: String, default: '' },
    loading: { type: Boolean, default: false },
  },
  emits: ['submit', 'cancel'],
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      form: {
        shortCode: this.shortCode || '',
        content: this.content || '',
        contentPrompts: this.contentPrompts || '',
      },
      activeTab: MESSAGE_TAB,
    };
  },
  validations: {
    form: {
      shortCode: { required, minLength: minLength(2) },
      content: { required },
    },
  },
  computed: {
    ...mapGetters({ labels: 'labels/getLabels' }),
    hasPrompt() {
      return Boolean(this.form.contentPrompts.trim());
    },
    promptTabName() {
      return this.hasPrompt
        ? this.$t('CANNED_MGMT.FORM_PROMPT.TAB_PROMPT_ACTIVE')
        : this.$t('CANNED_MGMT.FORM_PROMPT.TAB_PROMPT');
    },
    labelTitles() {
      return (this.labels || []).map(l => (l.title || '').toLowerCase());
    },
    // Una línea por etiqueta con problemas, sin repetir.
    tagWarnings() {
      const escritas = [
        ...new Set(this.form.contentPrompts.match(WRITTEN_TAG_RE) || []),
      ];
      // "#1", "#2": pasos numerados, no etiquetas.
      return escritas
        .filter(tag => !/^#\d+$/.test(tag))
        .flatMap(tag => {
          const leida = (tag.match(ENGINE_TAG_RE) || [''])[0];
          if (leida !== tag) {
            return [
              this.$t('CANNED_MGMT.FORM_PROMPT.TAG_UNREADABLE', {
                tag,
                read: leida || '—',
              }),
            ];
          }
          if (!this.labelTitles.includes(tag.slice(1).toLowerCase())) {
            return [this.$t('CANNED_MGMT.FORM_PROMPT.TAG_MISSING', { tag })];
          }
          return [];
        });
    },
  },
  mounted() {
    if (!this.labels || !this.labels.length) this.$store.dispatch('labels/get');
  },
  methods: {
    submit() {
      this.v$.$touch();
      if (this.v$.form.content.$invalid) {
        this.activeTab = MESSAGE_TAB;
        return;
      }
      if (this.v$.form.shortCode.$invalid) return;
      this.$emit('submit', {
        short_code: this.form.shortCode,
        content: this.form.content,
        content_prompts: this.form.contentPrompts,
      });
    },
    showTab(index) {
      this.activeTab = index;
    },
  },
  MESSAGE_TAB,
  PROMPT_TAB,
};
</script>

<template>
  <form class="flex flex-col w-full gap-3" @submit.prevent="submit">
    <!-- El nombre queda afuera de las pestañas: es de las dos, y es lo que se ve en la
         lista. -->
    <label :class="{ error: v$.form.shortCode.$error }">
      {{ $t('CANNED_MGMT.ADD.FORM.SHORT_CODE.LABEL') }}
      <input
        v-model.trim="form.shortCode"
        type="text"
        :placeholder="$t('CANNED_MGMT.ADD.FORM.SHORT_CODE.PLACEHOLDER')"
        @input="v$.form.shortCode.$touch"
      />
    </label>

    <woot-tabs :index="activeTab" @change="showTab">
      <woot-tabs-item
        :index="$options.MESSAGE_TAB"
        :name="$t('CANNED_MGMT.FORM_PROMPT.TAB_MESSAGE')"
        :show-badge="false"
      />
      <woot-tabs-item
        :index="$options.PROMPT_TAB"
        :name="promptTabName"
        :show-badge="false"
      />
    </woot-tabs>

    <!-- v-show y no v-if: el editor conserva lo escrito al cambiar de pestaña. -->
    <div
      v-show="activeTab === $options.MESSAGE_TAB"
      class="flex flex-col gap-3"
    >
      <div :class="{ error: v$.form.content.$error }">
        <div class="editor-wrap">
          <WootMessageEditor
            v-model="form.content"
            class="message-editor [&>div]:px-1"
            :class="{ editor_warning: v$.form.content.$error }"
            enable-variables
            :enable-canned-responses="false"
            :placeholder="$t('CANNED_MGMT.ADD.FORM.CONTENT.PLACEHOLDER')"
            @blur="v$.form.content.$touch"
          />
        </div>
        <span v-if="v$.form.content.$error" class="message">
          {{ $t('CANNED_MGMT.ADD.FORM.CONTENT.ERROR') }}
        </span>
      </div>
      <slot name="legacy" />
    </div>

    <div v-show="activeTab === $options.PROMPT_TAB" class="flex flex-col gap-2">
      <textarea
        v-model="form.contentPrompts"
        rows="14"
        class="w-full !mb-0 min-h-[20rem]"
        :placeholder="$t('CANNED_MGMT.FORM_PROMPT.PLACEHOLDER')"
      />
      <p class="!m-0 text-xs text-slate-500 dark:text-slate-400">
        {{ $t('CANNED_MGMT.FORM_PROMPT.HELP') }}
      </p>
      <p
        v-for="aviso in tagWarnings"
        :key="aviso"
        class="!m-0 text-xs text-amber-600 dark:text-amber-400"
      >
        {{ aviso }}
      </p>
    </div>

    <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
      <WootSubmitButton
        :disabled="loading"
        :button-text="submitText"
        :loading="loading"
      />
      <button class="button clear" @click.prevent="$emit('cancel')">
        {{ cancelText }}
      </button>
    </div>
  </form>
</template>

<style scoped lang="scss">
::v-deep {
  .ProseMirror-menubar {
    @apply hidden;
  }

  .ProseMirror-woot-style {
    @apply min-h-[16rem];

    p {
      @apply text-base;
    }
  }
}
</style>
