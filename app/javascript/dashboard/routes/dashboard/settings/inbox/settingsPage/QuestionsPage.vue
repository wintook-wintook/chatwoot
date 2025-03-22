<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import inboxMixin from 'shared/mixins/inboxMixin';
import SettingsSection from '../../../../../components/SettingsSection.vue';
import ImapSettings from '../ImapSettings.vue';
import SmtpSettings from '../SmtpSettings.vue';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';

import QuestionsTable from './QuestionsTable.vue';
import QuestionsHeader from './QuestionsHeader.vue';

export default {
  components: {
    SettingsSection,
    ImapSettings,
    SmtpSettings,
    QuestionsTable,
    QuestionsHeader,
  },
  mixins: [inboxMixin],
  props: {
    inbox: {
      type: Object,
      default: () => ({}),
    },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      hmacMandatory: false,
      whatsAppInboxAPIKey: '',
      dataQuestions: [],
      showAnswer: false,

      showDeleteConfirmationQuestion: false,
      showDeleteConfirmationAnswer: false,
      showModalQuestion: false,
      showModalAnswer: false,
      dataQuestion: {
        question_id: 0,
        question: ''
      },
      dataAnswer: {
        answer_id: 0,
        question_id: 0,
        answer: ''
      },
      dataActiveQuestions: {}
    };
  },
  validations: {
    whatsAppInboxAPIKey: { required },
  },
  watch: {
    inbox() {
      this.setDefaults();
    },
  },
  mounted() {
    this.setDefaults()
    this.getInboxQuestions()
    this.getQuestions()
  },
  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
    }),
    deleteMessageQuestion() {
      return `${this.$t('LABEL_MGMT.DELETE.CONFIRM.MESSAGE')} "${this.dataQuestion.question
        }"  ?`;
    },
    deleteMessageAnswer() {
      return `${this.$t('LABEL_MGMT.DELETE.CONFIRM.MESSAGE')} "${this.dataAnswer.answer
        }"  ?`;
    },
    deleteConfirmTextQuestion() {
      return `${this.$t('LABEL_MGMT.DELETE.CONFIRM.YES')} ${this.dataQuestion.question
        }`;
    },
    deleteConfirmTextAnswer() {
      return `${this.$t('LABEL_MGMT.DELETE.CONFIRM.YES')} ${this.dataAnswer.answer
        }`;
    },
    deleteRejectTextQuestion() {
      return `${this.$t('LABEL_MGMT.DELETE.CONFIRM.NO')} ${this.dataQuestion.question
        }`;
    },
    deleteRejectTextAnswer() {
      return `${this.$t('LABEL_MGMT.DELETE.CONFIRM.NO')} ${this.dataAnswer.answer
        }`;
    },
    headerTitleQuestion() {
      const str = this.dataQuestion.question_id ? 'Editar' : 'Nueva'
      return (`${str} pregunta para calificación de contactos...`)
    },
    headerTitleAnswer() {
      const str = this.dataAnswer.answer_id ? 'Editar' : 'Nueva'
      return (`${str} respuesta para calificación de contactos...`)
    }
  },
  methods: {
    setDefaults() {
      this.hmacMandatory = this.inbox.hmac_mandatory || false;
    },
    handleHmacFlag() {
      this.updateInbox();
    },
    async updateInbox() {
      try {
        const payload = {
          id: this.inbox.id,
          formData: false,
          channel: {
            hmac_mandatory: this.hmacMandatory,
          },
        };
        await this.$store.dispatch('inboxes/updateInbox', payload);
        useAlert(this.$t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      }
    },
    async updateWhatsAppInboxAPIKey() {
      try {
        const payload = {
          id: this.inbox.id,
          formData: false,
          channel: {},
        };

        payload.channel.provider_config = {
          ...this.inbox.provider_config,
          api_key: this.whatsAppInboxAPIKey,
        };

        await this.$store.dispatch('inboxes/updateInbox', payload);
        useAlert(this.$t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      }
    },
    async toogleActiveQuestions() {
      console.log("toogleActiveQuestions")
    },
    async getQuestions() {
      try {
        const { access_token, account_id } = this.currentUser;
        const { WINTOOK_API: urlApi } = process.env;

        // Crear URL con parámetros de consulta
        const url = new URL(`${urlApi}/v1/questions`);
        const dataBody = JSON.stringify({
          inbox_id: this.inbox.id,
          account_id: account_id,
        });

        const requestOptions = {
          method: "POST",
          headers: {
            'access-token': access_token,
            'Content-Type': 'application/json',
          },
          body: dataBody
        };

        // Realizar la solicitud
        const response = await fetch(url, requestOptions);

        if (!response.ok) {
          throw new Error(`Error en la solicitud: ${response.status} - ${response.statusText}`);
        }

        // Obtener datos como JSON
        const data = await response.json();
        this.dataQuestions = data; // Asignar el resultado a `dataQuestions`

        console.log("dataQuestions", this.dataQuestions);
      } catch (error) {
        console.error("Error en getQuestions:", error.message);
      }
    },

    async getInboxQuestions() {
      try {
        const { access_token } = this.currentUser;
        const { WINTOOK_API: urlApi } = process.env;

        // Crear URL con parámetros de consulta
        const url = new URL(`${urlApi}/v1/getInboxQuestions`);
        const dataBody = JSON.stringify({
          inbox_id: this.inbox.id
        });

        const requestOptions = {
          method: "POST",
          headers: {
            'access-token': access_token,
            'Content-Type': 'application/json',
          },
          body: dataBody
        };

        const response = await fetch(url, requestOptions);

        if (!response.ok) {
          throw new Error(`Error en la solicitud: ${response.status} - ${response.statusText}`);
        }

        const data = await response.json();
        this.dataActiveQuestions = data
        console.log(data)
      } catch (error) {
        console.error("Error en getInboxQuestions:", error.message);
      }
    },

    async onToggleEditQuestion(data) {
      console.log("onToggleEditQuestion", data)
      this.dataQuestion = data
      this.showModalQuestion = true
    },
    async onToggleCreateQuestion() {
      // console.log("onToggleCreateQuestion")
      const { access_token, account_id } = this.currentUser;
      this.dataQuestion = {
        question_id: 0,
        account_id,
        question: '',
        inbox_id: this.inbox.id
      }
      this.showModalQuestion = true
      // console.log("dataQuestion",this.dataQuestion)
    },

    async onToggleCreateAnswer() {
      console.log("onToggleCreateAnswer")
      const { access_token, account_id } = this.currentUser;
      this.dataAnswer = {
        answer_id: 0,
        question_id: 0,
        account_id,
        answer: '',
        inbox_id: this.inbox.id
      }
      this.showModalAnswer = true
    },
    hideModalQuestion() {
      this.showModalQuestion = false
    },
    hideModalAnswer() {
      this.showModalAnswer = false
    },
    hideAnswer() {
      this.showAnswer = false;
    },

    onToggleDeleteQuestion(data) {
      this.dataQuestion = data
      this.showDeleteConfirmationQuestion = true
    },
    closeDeletePopupQuestion() {
      this.showDeleteConfirmationQuestion = false;
    },
    closeDeletePopupAnswer() {
      this.showDeleteConfirmationAnswer = false;
    },
    async confirmDeletionQuestion() {
      console.log("confirmDeletionQuestion")
      try {
        const { access_token } = this.currentUser
        const { WINTOOK_API: urlApi } = process.env

        const requestOptions = {
          method: "POST",
          headers: {
            'Content-Type': 'application/json',
            'access-token': access_token
          },
          body: JSON.stringify(this.dataQuestion),
        };
        const response = await fetch(`${urlApi}/v1/deletequestion`, requestOptions);

        if (!response.ok) {
          // Manejo de errores HTTP
          const errorText = await response.text();
          throw new Error(`Error en la solicitud: ${response.status} - ${errorText}`);
        }

        // const result = await response.text();
        await this.getQuestions();
        useAlert("¡Se eliminó descripción de pregunta satisfactoriamente!...")
        this.showDeleteConfirmationQuestion = false
      } catch (error) {
        console.error("Error al eliminar la pregunta:", error);
      }
    },

    async confirmDeletionAnswer() {
      console.log("confirmDeletionAnswer")
      try {
        const { access_token } = this.currentUser
        const { WINTOOK_API: urlApi } = process.env

        const requestOptions = {
          method: "POST",
          headers: {
            'Content-Type': 'application/json',
            'access-token': access_token
          },
          body: JSON.stringify(this.dataAnswer),
        };
        const response = await fetch(`${urlApi}/v1/deleteanswer`, requestOptions);

        if (!response.ok) {
          // Manejo de errores HTTP
          const errorText = await response.text();
          throw new Error(`Error en la solicitud: ${response.status} - ${errorText}`);
        }

        // const result = await response.text();
        await this.getQuestions();
        useAlert("¡Se eliminó respuesta satisfactoriamente!...")
        this.showDeleteConfirmationAnswer = false
        this.showModalAnswer = false
      } catch (error) {
        console.error("Error al eliminar la respuesta:", error);
      }
    },

    async setQuestion() {
      console.log("setQuestion");
      try {
        const { access_token } = this.currentUser;
        const { WINTOOK_API: urlApi } = process.env;

        const requestOptions = {
          method: "POST",
          headers: {
            'Content-Type': 'application/json',
            'access-token': access_token
          },
          body: JSON.stringify(this.dataQuestion),
        };

        const response = await fetch(`${urlApi}/v1/setquestion`, requestOptions);

        if (!response.ok) {
          // Manejo de errores HTTP
          const errorDetails = await response.json();
          throw new Error(`Error en la API: ${response.status} - ${errorDetails.message}`);
        }

        const result = await response.json();
        console.log("Respuesta de la API:", result);

        // Llama a getQuestions después de una operación exitosa
        await this.getQuestions();
        useAlert("¡Se guardó descripción de pregunta satisfactoriamente!...")
        this.showModalQuestion = false
      } catch (error) {
        console.error("Error en setQuestion:", error);
      }
    },

    async setAnswer() {
      console.log("setAnswer");
      try {
        const { access_token } = this.currentUser;
        const { WINTOOK_API: urlApi } = process.env;

        const requestOptions = {
          method: "POST",
          headers: {
            'Content-Type': 'application/json',
            'access-token': access_token
          },
          body: JSON.stringify(this.dataAnswer),
        };

        const response = await fetch(`${urlApi}/v1/setanswer`, requestOptions);

        if (!response.ok) {
          // Manejo de errores HTTP
          const errorDetails = await response.json();
          throw new Error(`Error en la API: ${response.status} - ${errorDetails.message}`);
        }

        const result = await response.json();
        console.log("Respuesta de la API:", result);

        // Llama a getQuestions después de una operación exitosa
        await this.getQuestions();
        useAlert("¡Se guardó descripción de respuesta satisfactoriamente!...")
        this.showModalAnswer = false
      } catch (error) {
        console.error("Error en setAnswer:", error);
      }
    },

    async handleEditAnswer({ row, answer }) {
      this.dataAnswer = answer
      this.showModalAnswer = true

    },
    async handleDeleteAnswer({ row, answer }) {
      this.dataAnswer = answer
      this.showDeleteConfirmationAnswer = true
    },

    onCancelAnswer() {
      this.showModalAnswer = false
    },

    onCancelQuestion() {
      this.showModalQuestion = false
    },

    onDeleteAnswer() {
      console.log("onDeleteAnswer")
      this.showDeleteConfirmationAnswer = true
    },

    async handleActiveQuestions(data) {
      console.log('Estado de preguntas activas:', data.active);
      try {
        const { access_token } = this.currentUser;
        const { WINTOOK_API: urlApi } = process.env;

        const requestOptions = {
          method: "POST",
          headers: {
            'Content-Type': 'application/json',
            'access-token': access_token
          },
          body: JSON.stringify({
            inbox_id: this.inbox.id
          }),
        };

        const response = await fetch(`${urlApi}/v1/toogleInboxQuestions`, requestOptions);

        if (!response.ok) {
          // Manejo de errores HTTP
          const errorDetails = await response.json();
          throw new Error(`Error en la API: ${response.status} - ${errorDetails.message}`);
        }

        const result = await response.json();
        console.log("Respuesta de la API:", result);

        // Llama a getQuestions después de una operación exitosa
        useAlert(`¡Se actualizó  "Activar preguntas de calificación de prospecto" satisfactoriamente!...`)
      } catch (error) {
        console.error("Error en handleActiveQuestions:", error);
      }
    },
  },
};
</script>


<template>
  <div v-if="isAWhatsAppChannel">
    <div v-if="inbox.provider_config" class="m-8">
      <div>
        <QuestionsHeader :on-toggle-create-question="onToggleCreateQuestion"
          :on-toggle-create-answer="onToggleCreateAnswer" :toogle-active-questions="toogleActiveQuestions"
          :data-active-questions="dataActiveQuestions" @active-questions="handleActiveQuestions" />

        <QuestionsTable :data-table="dataQuestions" :on-toggle-delete-question="onToggleDeleteQuestion"
          :on-toggle-edit-question="onToggleEditQuestion" @edit-answer="handleEditAnswer"
          @delete-answer="handleDeleteAnswer" />
      </div>
    </div>

    <woot-delete-modal :show.sync="showDeleteConfirmationQuestion" :on-close="closeDeletePopupQuestion"
      :on-confirm="confirmDeletionQuestion" :title="'Confirmar eliminación de pregunta...'"
      :message="deleteMessageQuestion" :confirm-text="deleteConfirmTextQuestion"
      :reject-text="deleteRejectTextQuestion" />

    <woot-delete-modal :show.sync="showDeleteConfirmationAnswer" :on-close="closeDeletePopupAnswer"
      :on-confirm="confirmDeletionAnswer" :title="'Confirmar eliminación de respuesta...'"
      :message="deleteMessageAnswer" :confirm-text="deleteConfirmTextAnswer" :reject-text="deleteRejectTextAnswer" />

    <woot-modal :show.sync="showModalQuestion" :on-close="hideModalQuestion">
      <div class="column content-box">
        <woot-modal-header :header-title="headerTitleQuestion" />
        <form @submit.prevent="setQuestion">
          <label>Descripción de pregunta:
            <input type="text" v-model="dataQuestion.question" />
          </label>

          <div class="flex justify-end gap-2 mt-6">
            <woot-button variant="clear" color-scheme="alert" @click.prevent="onCancelQuestion">
              Cancelar
            </woot-button>
            <woot-button type="submit" :is-disabled="!dataQuestion.question.length">
              Guardar
            </woot-button>
          </div>

        </form>
      </div>
    </woot-modal>


    <woot-modal :show.sync="showModalAnswer" :on-close="hideModalAnswer">
      <div class="column content-box">
        <woot-modal-header :header-title="headerTitleAnswer" />
        <form @submit.prevent="setAnswer">
          <label>
            Descripción de pregunta:
            <select v-model="dataAnswer.question_id">
              <option v-for="d in this.dataQuestions" :key="d.question_id" :value="d.question_id">
                {{ d.question }}
              </option>
            </select>
          </label>
          <label>Descripción de respuesta:
            <input type="text" v-model="dataAnswer.answer" />
          </label>


          <div class="flex justify-end gap-2 mt-6">
            <woot-button variant="clear" color-scheme="alert" @click.prevent="onCancelAnswer">
              Cancelar
            </woot-button>
            <woot-button type="submit" :is-disabled="!dataAnswer.answer.length || !dataAnswer.question_id">
              Guardar
            </woot-button>
          </div>

        </form>
      </div>
    </woot-modal>


  </div>
</template>

<style lang="scss" scoped>
.whatsapp-settings--content {
  ::v-deep input {
    margin-bottom: 0;
  }
}
</style>
