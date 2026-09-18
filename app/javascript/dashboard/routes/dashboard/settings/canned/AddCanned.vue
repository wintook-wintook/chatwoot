<script>
// **Wintook** 100823
import axios from 'axios';
// **Wintook** 100823

import { useAlert } from 'dashboard/composables';
import Modal from '../../../../components/Modal.vue';
import CannedResponseForm from './CannedResponseForm.vue';

// proyecto@predefinidas_prompt — los campos del bot viejo (menú, opción, contenido
// completo, link alternativo) quedan escondidos detrás de esta bandera: ningún código los
// lee, sus columnas no existen en todas las bases, y mandarlos hacía fallar el guardado.
// No se borra nada: ponerla en true los vuelve a mostrar y a mandar.
const SHOW_LEGACY_FIELDS = false;

export default {
  components: {
    Modal,
    CannedResponseForm,
  },
  props: {
    responseContent: {
      type: String,
      default: '',
    },
    onClose: {
      type: Function,
      default: () => {},
    },
  },
  data() {
    return {
      // <!-- Andrés Liverio 020822  **Wintook**-->
      urlShortCode: '',
      contentFull: false,
      urlContent: false,
      opcMenu: false,
      noOptionMenu: 0,
      // <!-- Andrés Liverio 020822 **Wintook**-->

      addCanned: {
        showLoading: false,
        message: '',
      },
      show: true,
    };
  },
  computed: {
    showLegacyFields() {
      return SHOW_LEGACY_FIELDS;
    },
  },
  methods: {
    addCannedResponse(campos) {
      this.addCanned.showLoading = true;
      this.$store
        .dispatch('createCannedResponse', {
          ...campos,
          ...(this.showLegacyFields ? this.legacyFields() : {}),
        })
        .then(() => {
          this.addCanned.showLoading = false;
          useAlert(this.$t('CANNED_MGMT.ADD.API.SUCCESS_MESSAGE'));
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
    legacyFields() {
      return {
        menu: this.opcMenu,
        opcion: this.noOptionMenu,
        content_full: this.contentFull,
        url_content: this.urlContent,
        url_short_code: this.urlShortCode,
      };
    },
    setCannedReponse(data) {
      return axios
        .post(`${process.env.WINTOOK_BOT}/api/setCannedReponse`, {
          params: {
            id: data.id,
            account_id: data.account_id,
            url_short_code: this.urlShortCode,
            content_full: this.contentFull,
            url_content: this.urlContent,
            opcMenu: this.opcMenu,
            noOptionMenu: this.noOptionMenu,
          },
        })
        .then(resp => resp.data)
        .catch(error => error);
    },
    // <!-- Andrés Liverio 020822 **Wintook**-->
  },
};
</script>

<template>
  <!-- size="medium": el modal grande del dashboard (900 px). El mensaje y su prompt
       son textos largos: en el ancho de siempre no se leían. -->
  <Modal :show.sync="show" :on-close="onClose" size="medium">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="$t('CANNED_MGMT.ADD.TITLE')"
        :header-content="$t('CANNED_MGMT.ADD.DESC')"
      />
      <CannedResponseForm
        class="px-8 pb-6"
        :content="responseContent"
        :submit-text="$t('CANNED_MGMT.ADD.FORM.SUBMIT')"
        :cancel-text="$t('CANNED_MGMT.ADD.CANCEL_BUTTON_TEXT')"
        :loading="addCanned.showLoading"
        @submit="addCannedResponse"
        @cancel="onClose"
      >
        <!-- Andrés Liverio 020822 **Wintook** -->
        <template v-if="showLegacyFields" #legacy>
          <div class="flex items-center w-full gap-2">
            <input v-model="opcMenu" type="checkbox" :checked="opcMenu" />
            <label>{{ $t('CANNED_MGMT.LEGACY.MENU') }}</label>
          </div>
          <div class="w-full">
            <label>{{ $t('CANNED_MGMT.LEGACY.MENU_OPTION') }}</label>
            <input
              v-model="noOptionMenu"
              type="number"
              step="1"
              min="3"
              max="99"
              class="w-36"
              :disabled="!opcMenu"
            />
          </div>
          <div class="flex items-center w-full gap-2">
            <input
              v-model="contentFull"
              type="checkbox"
              :checked="contentFull"
            />
            <label>{{ $t('CANNED_MGMT.LEGACY.CONTENT_FULL') }}</label>
          </div>
          <div class="flex items-center w-full gap-2">
            <input v-model="urlContent" type="checkbox" :checked="urlContent" />
            <label>{{ $t('CANNED_MGMT.LEGACY.URL_CONTENT') }}</label>
          </div>
          <div v-show="urlContent" class="w-full">
            <label class="w-full">
              {{ $t('CANNED_MGMT.LEGACY.URL') }}
              <input
                v-model.trim="urlShortCode"
                class="w-full"
                type="url"
                :placeholder="$t('CANNED_MGMT.LEGACY.URL_PLACEHOLDER')"
              />
            </label>
          </div>
        </template>
        <!-- Andrés Liverio 020822 **Wintook** -->
      </CannedResponseForm>
    </div>
  </Modal>
</template>
