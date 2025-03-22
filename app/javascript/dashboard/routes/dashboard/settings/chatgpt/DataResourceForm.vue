<template>
  <woot-modal :show.sync="show" :on-close="onClose">
    <div class="column content-box">
      <woot-modal-header :header-title="'OpenAI - Origen de Datos'"
        :header-content="'Entrenamiento de origenes de datos para ChatGPT.'" />
      <div class="p-5">
        <label>
          <input type="hidden" v-model="dataResource.id" />
        </label>

        <label>
          {{ 'Descripción de Origen de Datos' }}
          <input type="text" v-model="dataResource.forum_account" />
        </label>

        <label>
          {{ 'Origen de Datos' }}
          <select v-model="dataResource.forum_type_id" id="optDataResourceType">
            <option :value="0">{{ 'Seleccione Origen de Datos' }}</option>
            <option v-for="od in this.forumsType" :key="od.id" :value="od.id">
              {{ od.forum_type }}
            </option>
          </select>
          <!-- <input type="text" :value="od.path" /> -->
        </label>

        <label :class="{}">
          {{ 'Dirección URL de Origen de Datos' }}
          <input type="url" v-model="dataResource.forum_url" />
        </label>

        <woot-button :is-disabled="!dataResource.forum_url ||
          !dataResource.forum_account ||
          !dataResource.forum_type_id
          " @click="onSubmit">
          {{ ' Guardar ' }}
        </woot-button>

        <woot-button class="button clear" @click="onClose">
          {{ ' Cancelar ' }}
        </woot-button>
      </div>
    </div>
    <div class="column" style="padding: 3.2rem" v-show="showLoading">
      <label>
        {{ 'Cargando información a la Base de Datos, espere por favor...' }}
      </label>
      <div class="custom-loader"></div>
    </div>
  </woot-modal>
</template>

<script>
import axios from 'axios';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';

export default {
  data() {
    return {
      show: true,
      showLoading: false,
      existsUrl: false,
    };
  },

  props: {
    showDataResource: { type: Boolean, default: false },
    forumsType: { type: Array, default: () => [] },
    dataResource: { type: Array, default: () => [] },
    onToggleShow: { type: Function, default: data => { } },
    onClose: {
      type: Function,
      default: () => { },
    },
  },

  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
    }),
  },

  methods: {
    async existsForumUrl() {
      const { access_token, account_id } = this.currentUser;
      const urlBaseApi = process.env.WINTOOK_OPENAI;
      console.log("this.dataResource", this.dataResource);
      const forum_url = this.dataResource.forum_url;
      console.log("forum_url", forum_url);

      const myBody = JSON.stringify({
        "account_id": account_id,
        "forum_url": forum_url
      });

      const requestOptions = {
        method: "POST",
        headers: {
          'access-token': access_token,
          'Content-Type': 'application/json',
        },
        body: myBody
      };

      console.log("requestOptions", requestOptions);

      // Realiza la solicitud
      const response = await fetch(`${urlBaseApi}/v1/responses/existsForumUrl`, requestOptions);
      console.log("Response Status:", response.status);
      console.log("Response Status:", response);
      if (response.status === 200) {
        const result = await response.json();
        console.log("result:", result);
        // Si result es un array o un objeto, comprobar su longitud
        return (result.length ? true : false);
      } else {
        // Manejo de otros estados de respuesta
        console.error("Error en la solicitud:", response.status, response.statusText);
        return false;
      }

    },

    async onSubmit() {
      if (await this.existsForumUrl()) {
        useAlert(`El foro ${this.dataResource.forum_url} ya esta registrado...`);
      } else {
        const { access_token, account_id } = this.currentUser;
        const dataBody = this.dataResource;
        this.showLoading = true;
        const urlBaseApi = process.env.WINTOOK_OPENAI;
        const urlApi = `${urlBaseApi}/v1/responses/ForumAccount`;
        const options = {
          method: 'PUT',
          url: urlApi,
          headers: {
            'access-token': access_token,
            'Content-Type': 'application/json',
          },
          data: dataBody,
        };

        try {
          const response = await axios.request(options);
          if (response.status === 500) {
            useAlert(response.data);
          }
          if (response.status === 200) {
            this.showLoading = false;
            this.show = false;
            useAlert(response.data);
          }
        } catch (error) {
          useAlert(
            error.response ? error.response.data : error.message
          );
        }

      }
    },

    getDataPath() {
      let element = document.getElementById('optDataResourceType');
      return element.options[element.selectedIndex].getAttribute('data-path');
    },
  },
};
</script>

<style scoped>
.custom-loader {
  width: 100%;
  height: 20px;
  background: linear-gradient(90deg, #0000, #a722f4) left -50px top 0/50px 20px no-repeat #e4e4ed;
  animation: ct2 1s infinite linear;
}

@keyframes ct2 {
  100% {
    background-position: right -50px top 0;
  }
}
</style>
