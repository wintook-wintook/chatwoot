<script>

// **Wintook** 100823
import axios from "axios";
// **Wintook** 100823

/* eslint no-console: 0 */
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import WootSubmitButton from '../../../../components/buttons/FormSubmitButton.vue';
import Modal from '../../../../components/Modal.vue';

export default {
  components: {
    WootSubmitButton,
    Modal,
    WootMessageEditor,
  },
  props: {
    id: { type: Number, default: null },
    edcontent: { type: String, default: '' },
    edshortCode: { type: String, default: '' },
    edcontentPrompts: { type: String, default: "" },
    edactiveResponse: {  type: Object, default: () => ({}) },
    onClose: { type: Function, default: () => {} },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      editCanned: {
        showAlert: false,
        showLoading: false,
      },
      shortCode: this.edshortCode,
      content: this.edcontent,
      show: true,

      // <!-- Andrés Liverio 020822 **Wintook** -->
      urlShortCode: this.edactiveResponse.url_short_code,
      content_prompts: this.edactiveResponse.content_prompts,
      contentFull: this.edactiveResponse.content_full,
      urlContent: this.edactiveResponse.url_content,
      opcMenu: this.edactiveResponse.menu,
      noOptionMenu: this.edactiveResponse.opcion,
      // <!-- Andrés Liverio 020822 **Wintook** -->
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
  computed: {
    pageTitle() {
      return `${this.$t('CANNED_MGMT.EDIT.TITLE')} - ${this.edshortCode}`;
    },
  },

  mounted() {
    console.log('Active Response:', this.edactiveResponse);
    // this.getCannedReponse();
  },

  methods: {
    setPageName({ name }) {
      this.v$.content.$touch();
      this.content = name;
    },
    resetForm() {
      this.shortCode = '';
      this.content = '';
      this.v$.shortCode.$reset();
      this.v$.content.$reset();
    },
    editCannedResponse() {
      // Show loading on button
      this.editCanned.showLoading = true;
      // Make API Calls
      this.$store
        .dispatch('updateCannedResponse', {
          id: this.id,
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
          // Reset Form, Show success message
          this.setCannedReponse(); // <!-- Andrés Liverio 020822 **Wintook** -->
          this.editCanned.showLoading = false;
          useAlert(this.$t('CANNED_MGMT.EDIT.API.SUCCESS_MESSAGE'));
          this.resetForm();
          setTimeout(() => {
            this.onClose();
          }, 10);
        })
        .catch(error => {
          this.editCanned.showLoading = false;
          const errorMessage =
            error?.message || this.$t('CANNED_MGMT.EDIT.API.ERROR_MESSAGE');
          useAlert(errorMessage);
        });
    },

        // <!-- Andrés Liverio 020822 **Wintook** -->
        async setCannedReponse() {
      let id = this.id;
      let account_id = this.account_id;
      let url_short_code = this.urlShortCode;
      let content_full = this.contentFull;
      let url_content = this.urlContent;
      let opcMenu = this.opcMenu;
      let noOptionMenu = this.noOptionMenu;

      let response = await axios
        .post(process.env.URL_WEBHOOK + "/api/setCannedReponse", {
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

      if (response.status === 400) {
        useAlert(response.status.message);
      }
    },

    async getCannedReponse() {
      let id = this.id;
      let response = await axios
        .get(process.env.URL_WEBHOOK + "/api/getCannedReponse", {
          params: {
            id: id,
          },
        })
        .then(function (resp) {
          return resp.data;
        })
        .catch(function (error) {
          return error;
        });
      if (response.status == 200) {
        this.urlShortCode = response.data.url_short_code;
        this.contentFull = response.data.content_full;
        this.urlContent = response.data.url_content;
        this.opcMenu = response.data.menu;
        this.noOptionMenu = response.data.opcion;
      }
    },
  },
};
</script>

<template>
  <Modal :show.sync="show" :on-close="onClose">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header :header-title="pageTitle" />
      <form class="flex flex-col w-full" @submit.prevent="editCannedResponse()">
        <div class="w-full">
          <label :class="{ error: v$.shortCode.$error }">
            {{ $t('CANNED_MGMT.EDIT.FORM.SHORT_CODE.LABEL') }}
            <input
              v-model.trim="shortCode"
              type="text"
              :placeholder="$t('CANNED_MGMT.EDIT.FORM.SHORT_CODE.PLACEHOLDER')"
              @input="v$.shortCode.$touch"
            />
          </label>
        </div>

        <div class="w-full">
          <label :class="{ error: v$.content.$error }">
            {{ $t('CANNED_MGMT.EDIT.FORM.CONTENT.LABEL') }}
          </label>
          <div class="editor-wrap">
            <WootMessageEditor
              v-model="content"
              class="message-editor [&>div]:px-1"
              :class="{ editor_warning: v$.content.$error }"
              enable-variables
              :enable-canned-responses="false"
              :placeholder="$t('CANNED_MGMT.EDIT.FORM.CONTENT.PLACEHOLDER')"
              @blur="v$.content.$touch"
            />
          </div>
        </div>

        <div class="w-full">
          <label>
            {{'Prompts de Contenido'}}
            <textarea
              v-model.trim="content_prompts"
              type="text"
              rows="5"
              :placeholder="'Describe los prompts de contenido...'"
            />
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
          <WootSubmitButton
            :disabled="
              v$.content.$invalid ||
              v$.shortCode.$invalid ||
              editCanned.showLoading
            "
            :button-text="$t('CANNED_MGMT.EDIT.FORM.SUBMIT')"
            :loading="editCanned.showLoading"
          />
          <button class="button clear" @click.prevent="onClose">
            {{ $t('CANNED_MGMT.EDIT.CANCEL_BUTTON_TEXT') }}
          </button>
        </div>
      </form>
    </div>
  </Modal>
</template>

<style scoped lang="scss">
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
</style>
