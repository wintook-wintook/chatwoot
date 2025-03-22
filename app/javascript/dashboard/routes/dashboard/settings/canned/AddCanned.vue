<script>

// **Wintook** 100823
import axios from "axios";
import { mapGetters } from "vuex";
// **Wintook** 100823

import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';

import WootSubmitButton from '../../../../components/buttons/FormSubmitButton.vue';
import Modal from '../../../../components/Modal.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';

export default {
  components: {
    WootSubmitButton,
    Modal,
    WootMessageEditor,
  },
  props: {
    responseContent: {
      type: String,
      default: '',
    },
    onClose: {
      type: Function,
      default: () => { },
    },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      shortCode: '',
      content: this.responseContent || '',

      // <!-- Andrés Liverio 020822  **Wintook**-->
      content_prompts: "",
      urlShortCode: "",
      contentFull: false,
      urlContent: false,
      opcMenu: false,
      noOptionMenu: 0,
      existsOption: false,
      insert: {},
      // <!-- Andrés Liverio 020822 **Wintook**-->

      addCanned: {
        showLoading: false,
        message: '',
      },
      show: true,
    };
  },
  validations: {
    shortCode: {
      required,
      minLength: minLength(2),
    },
    content: {
      required,
    },
  },

  // <!-- Andrés Liverio 020822  **Wintook**-->
  computed: {
    ...mapGetters({
      currentUser: "getCurrentUser",
    }),
  },
  // <!-- Andrés Liverio 020822  **Wintook**-->

  methods: {
    resetForm() {
      this.shortCode = '';
      this.content = '';
      this.v$.shortCode.$reset();
      this.v$.content.$reset();
    },
    addCannedResponse() {
      // Show loading on button
      this.addCanned.showLoading = true;
      // Make API Calls
      this.$store
        .dispatch('createCannedResponse', {
          short_code: this.shortCode,
          content: this.content,
          content_prompts: this.content_prompts, 
          menu: this.opcMenu,
          opcion: this.noOptionMenu,
          content_full: this.contentFull,
          url_content: this.urlContent,
          url_short_code: this.urlShortCode,

        })
        .then(() => {
          this.addCanned.showLoading = false;
          useAlert(this.$t('CANNED_MGMT.ADD.API.SUCCESS_MESSAGE'));
          this.resetForm();
          this.onClose();
        })
        .catch(error => {
          this.addCanned.showLoading = false;
          const errorMessage =
            error?.message || this.$t('CANNED_MGMT.ADD.API.ERROR_MESSAGE');
          useAlert(errorMessage);
        });
    },

    // <!-- Andrés Liverio 020822 **Wintook**-->
    setCannedReponse(data) {
      let id = data.id;
      let account_id = data.account_id;
      let url_short_code = this.urlShortCode;
      let content_full = this.contentFull;
      let url_content = this.urlContent;
      let opcMenu = this.opcMenu;
      let noOptionMenu = this.noOptionMenu;

      let response = axios
        .post(process.env.WINTOOK_BOT + "/api/setCannedReponse", {
          params: {
            id: id,
            account_id: account_id,
            url_short_code: url_short_code,
            content_full: content_full,
            url_content: url_content,
            opcMenu: opcMenu,
            noOptionMenu: noOptionMenu,
          },
        })
        .then(function (resp) {
          return resp.data;
        })
        .catch(function (error) {
          return error;
        });
      return response;
    },
    // <!-- Andrés Liverio 020822 **Wintook**-->
  },
};
</script>

<template>
  <Modal :show.sync="show" :on-close="onClose">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header :header-title="$t('CANNED_MGMT.ADD.TITLE')" :header-content="$t('CANNED_MGMT.ADD.DESC')" />
      <form class="flex flex-col w-full" @submit.prevent="addCannedResponse()">
        <div class="w-full">
          <label :class="{ error: v$.shortCode.$error }">
            {{ $t('CANNED_MGMT.ADD.FORM.SHORT_CODE.LABEL') }}
            <input v-model.trim="shortCode" type="text" :placeholder="$t('CANNED_MGMT.ADD.FORM.SHORT_CODE.PLACEHOLDER')"
              @input="v$.shortCode.$touch" />
          </label>
        </div>

        <div class="w-full">
          <label :class="{ error: v$.content.$error }">
            {{ $t('CANNED_MGMT.ADD.FORM.CONTENT.LABEL') }}
          </label>
          <div class="editor-wrap">
            <WootMessageEditor v-model="content" class="message-editor [&>div]:px-1"
              :class="{ editor_warning: v$.content.$error }" enable-variables :enable-canned-responses="false"
              :placeholder="$t('CANNED_MGMT.ADD.FORM.CONTENT.PLACEHOLDER')" @blur="v$.content.$touch" />
          </div>
        </div>

        <div class="w-full">
          <label>
            {{ 'Prompts de Contenido' }}
            <textarea v-model.trim="content_prompts" type="text" rows="5"
              :placeholder="'Describe los prompts de contenido...'" />
          </label>
        </div>

        <!-- Andrés Liverio 020822 **Wintook** -->
        <div class="w-full flex items-center gap-2">
          <input v-model="opcMenu" type="checkbox" :checked="opcMenu" />
          <label>
            {{ "Mostrar como opción de Menú." }}
          </label>
        </div>

        <div class="w-full">
          <label>
            {{ "Número de opción del menú." }}
          </label>
          <input type="number" step="1" min="3" max="99" v-model="noOptionMenu" style="width: 150px"
            :disabled="!opcMenu" />
        </div>

        <div class="w-full flex items-center gap-2">
          <input v-model="contentFull" type="checkbox" :checked="contentFull" />
          <label>
            {{ "Mostrar el contenido completo en el resultado de la búsqueda" }}
          </label>
        </div>

        <div class="w-full flex items-center gap-2">
          <input v-model="urlContent" type="checkbox" :checked="urlContent" />
          <label>
            {{ "Agregar link de dirección web alternativa" }}
          </label>
        </div>

        <div class="w-full" v-show="urlContent">
          <label class="w-full">
            {{ "Link de direccón web alternativa" }}
            <input class="w-full" v-model.trim="urlShortCode" type="url" placeholder="Por favor, Introduzca una dirección web" />
          </label>
        </div>
        <!-- Andrés Liverio 020822 **Wintook** -->

        <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
          <WootSubmitButton :disabled="v$.content.$invalid ||
            v$.shortCode.$invalid ||
            addCanned.showLoading
            " :button-text="$t('CANNED_MGMT.ADD.FORM.SUBMIT')" :loading="addCanned.showLoading" />
          <button class="button clear" @click.prevent="onClose">
            {{ $t('CANNED_MGMT.ADD.CANCEL_BUTTON_TEXT') }}
          </button>
        </div>
      </form>
    </div>
  </Modal>
</template>
<!-- <style scoped lang="scss">
::v-deep {
  .ProseMirror-menubar {
    @apply hidden;
  }

  .ProseMirror-woot-style {
    @apply min-h-[12.5rem];

    p {
      @apply text-base;
    }
  }
}
</style> -->
