<script>
import { useAlert } from 'dashboard/composables';
import Modal from '../../../../components/Modal.vue';
import CannedResponseForm from './CannedResponseForm.vue';

// proyecto@predefinidas_prompt — los campos del bot viejo (menú, opción, contenido
// completo, link alternativo) los guarda ahora la API de Chatwoot, en su propia tabla,
// igual que el nombre, el mensaje y el prompt. Antes se mandaban además al bot viejo
// (setCannedReponse), por una URL que no estaba definida: ya no hace falta.

export default {
  components: {
    Modal,
    CannedResponseForm,
  },
  props: {
    id: { type: Number, default: null },
    edcontent: { type: String, default: '' },
    edshortCode: { type: String, default: '' },
    edactiveResponse: { type: Object, default: () => ({}) },
    onClose: { type: Function, default: () => {} },
  },
  data() {
    return {
      editCanned: {
        showAlert: false,
        showLoading: false,
      },
      show: true,

      // <!-- Andrés Liverio 020822 **Wintook** -->
      urlShortCode: this.edactiveResponse.url_short_code || '',
      contentFull: Boolean(this.edactiveResponse.content_full),
      urlContent: Boolean(this.edactiveResponse.url_content),
      opcMenu: Boolean(this.edactiveResponse.menu),
      noOptionMenu: this.edactiveResponse.opcion || 0,
      // <!-- Andrés Liverio 020822 **Wintook** -->
    };
  },
  computed: {
    pageTitle() {
      return `${this.$t('CANNED_MGMT.EDIT.TITLE')} - ${this.edshortCode}`;
    },
  },
  methods: {
    editCannedResponse(campos) {
      this.editCanned.showLoading = true;
      this.$store
        .dispatch('updateCannedResponse', {
          id: this.id,
          ...campos,
          ...this.legacyFields(),
        })
        .then(() => {
          this.editCanned.showLoading = false;
          useAlert(this.$t('CANNED_MGMT.EDIT.API.SUCCESS_MESSAGE'));
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
    legacyFields() {
      return {
        menu: this.opcMenu,
        opcion: this.noOptionMenu,
        content_full: this.contentFull,
        url_content: this.urlContent,
        url_short_code: this.urlShortCode,
      };
    },
    // <!-- Andrés Liverio 020822 **Wintook** -->
  },
};
</script>

<template>
  <!-- size="medium": el modal grande del dashboard (900 px), como el de agregar. -->
  <Modal :show.sync="show" :on-close="onClose" size="medium">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header :header-title="pageTitle" />
      <CannedResponseForm
        class="px-8 pb-6"
        :short-code="edshortCode"
        :content="edcontent"
        :content-prompts="edactiveResponse.content_prompts || ''"
        :content-is-prompt="Boolean(edactiveResponse.content_is_prompt)"
        :submit-text="$t('CANNED_MGMT.EDIT.FORM.SUBMIT')"
        :cancel-text="$t('CANNED_MGMT.EDIT.CANCEL_BUTTON_TEXT')"
        :loading="editCanned.showLoading"
        @submit="editCannedResponse"
        @cancel="onClose"
      >
        <!-- Andrés Liverio 020822 **Wintook** -->
        <template #legacy>
          <!-- Dos columnas, 40 % y 50 %: el menú a la izquierda; el contenido completo y el link a la
               derecha. En pantallas angostas quedan una debajo de la otra. -->
          <div
            class="grid grid-cols-1 md:grid-cols-[40%_50%] md:justify-between gap-y-2"
          >
            <div class="flex flex-col gap-2">
              <div class="flex items-center w-full gap-2">
                <input v-model="opcMenu" type="checkbox" :checked="opcMenu" />
                <label>{{ $t('CANNED_MGMT.LEGACY.MENU') }}</label>
              </div>
              <div class="w-full">
                <label>{{ $t('CANNED_MGMT.LEGACY.MENU_OPTION') }}</label>
                <input
                  v-model.number="noOptionMenu"
                  type="number"
                  step="1"
                  min="3"
                  max="99"
                  class="!w-36"
                  :disabled="!opcMenu"
                />
              </div>
            </div>
            <div class="flex flex-col gap-2">
              <div class="flex items-center w-full gap-2">
                <input
                  v-model="contentFull"
                  type="checkbox"
                  :checked="contentFull"
                />
                <label>{{ $t('CANNED_MGMT.LEGACY.CONTENT_FULL') }}</label>
              </div>
              <div class="flex items-center w-full gap-2">
                <input
                  v-model="urlContent"
                  type="checkbox"
                  :checked="urlContent"
                />
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
            </div>
          </div>
        </template>
        <!-- Andrés Liverio 020822 **Wintook** -->
      </CannedResponseForm>
    </div>
  </Modal>
</template>
