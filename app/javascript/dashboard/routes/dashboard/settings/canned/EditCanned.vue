<script>
// **Wintook** 100823
import axios from 'axios';
// **Wintook** 100823

import { useAlert } from 'dashboard/composables';
import Modal from '../../../../components/Modal.vue';
import CannedResponseForm from './CannedResponseForm.vue';

// proyecto@predefinidas_prompt — ver AddCanned.vue: los campos del bot viejo y su
// llamada al webhook del bot quedan detrás de esta bandera.
const SHOW_LEGACY_FIELDS = false;

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
      urlShortCode: this.edactiveResponse.url_short_code,
      contentFull: this.edactiveResponse.content_full,
      urlContent: this.edactiveResponse.url_content,
      opcMenu: this.edactiveResponse.menu,
      noOptionMenu: this.edactiveResponse.opcion,
      // <!-- Andrés Liverio 020822 **Wintook** -->
    };
  },
  computed: {
    pageTitle() {
      return `${this.$t('CANNED_MGMT.EDIT.TITLE')} - ${this.edshortCode}`;
    },
    showLegacyFields() {
      return SHOW_LEGACY_FIELDS;
    },
  },
  methods: {
    editCannedResponse(campos) {
      this.editCanned.showLoading = true;
      this.$store
        .dispatch('updateCannedResponse', {
          id: this.id,
          ...campos,
          ...(this.showLegacyFields ? this.legacyFields() : {}),
        })
        .then(() => {
          // <!-- Andrés Liverio 020822 **Wintook** -->
          if (this.showLegacyFields) this.setCannedReponse();
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
    async setCannedReponse() {
      const response = await axios
        .post(`${process.env.URL_WEBHOOK}/api/setCannedReponse`, {
          params: {
            id: this.id,
            account_id: this.edactiveResponse.account_id,
            url_short_code: this.urlShortCode,
            content_full: this.contentFull,
            url_content: this.urlContent,
            opcMenu: this.opcMenu,
            noOptionMenu: this.noOptionMenu,
          },
        })
        .then(resp => resp.data)
        .catch(error => error);

      if (response.status === 400) {
        useAlert(response.status.message);
      }
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
        :submit-text="$t('CANNED_MGMT.EDIT.FORM.SUBMIT')"
        :cancel-text="$t('CANNED_MGMT.EDIT.CANCEL_BUTTON_TEXT')"
        :loading="editCanned.showLoading"
        @submit="editCannedResponse"
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
