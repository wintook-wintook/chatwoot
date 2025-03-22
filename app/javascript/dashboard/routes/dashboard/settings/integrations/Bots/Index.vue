<script>
import axios from 'axios';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import globalConfigMixin from 'shared/mixins/globalConfigMixin';
import BaseSettingsHeader from '../../components/BaseSettingsHeader.vue';
import BotTags from '../Addons/BotTags.vue'

export default {
  components: {
    BaseSettingsHeader,
    BotTags,
  },
  mixins: [globalConfigMixin],
  data() {
    return {
      loading: {},
      records: {},
      listInboxes: {},
      textButtonI: 'Bot : Apagado',
      colorSchemeI: 'alert',
      botI: false,
      statusBot: false,
    };
  },
  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
      uiFlags: 'dashboardApps/getUIFlags',
    }),
  },
  mounted() {
    this.getListInboxes();
    this.getBotAccount();
  },
  methods: {    
    async getListInboxes() {
      this.listInboxes = null;
      const access_token = this.currentUser.access_token;

      try {
        const response = await fetch(`${process.env.WINTOOK_BOT}/api/getListInboxes?access_token=${access_token}`);

        if (response.ok) {  // Verifica si el estado HTTP es 200-299
          const data = await response.json();  // Convierte la respuesta a JSON
          this.listInboxes = data.data;
          console.log(this.listInboxes);
        } else {
          console.error('Error en la respuesta: ', response.status);
        }
      } catch (error) {
        console.error('Error de red o al procesar la petición: ', error);
      }
    },

    async setBotInbox(inboxId) {
      let access_token = this.currentUser.access_token;
      let result = await axios.get(process.env.WINTOOK_BOT + '/api/setBotInbox', {
        params: {
          access_token: access_token,
          inbox_id: inboxId,
        }
      })
        .then(function (resp) { return resp.data; })
        .catch(function (error) { return error; });
      if (result.status == 200) {
        this.getListInboxes();
        useAlert(result.toastMessage);
      }
    },

    async setBotAccount() {
      const { access_token, account_id } = this.currentUser;
      const result = await axios.get(process.env.WINTOOK_BOT + '/api/setBotAccount', {
        params: { access_token, account_id }
      })
        .then(function (resp) { return resp.data; })
        .catch(function (error) { return error; });
      console.log(result);
      if (result.status === 200) {
        this.textButtonI = result.textButton;
        this.colorSchemeI = result.colorScheme;
        this.botI = result.bot;
        useAlert(result.toastMessage);
      }
    },

    async getBotAccount() {
      const { access_token, account_id } = this.currentUser;
      try {
        const response = await fetch(`${process.env.WINTOOK_BOT}/api/getBotAccount?access_token=${access_token}&account_id=${account_id}`);

        if (response.ok) {  // Verifica si el estado HTTP es 200-299
          const result = await response.json();  // Convierte la respuesta a JSON
          if (result.status === 200) {
            this.statusBot   = result.statusBot;
            this.textButtonI = result.textButton;
            this.colorSchemeI = result.colorScheme;
            this.botI = result.bot;
          } else {
            console.error('Error en los datos: ', result);
          }
        } else {
          console.error('Error en la respuesta HTTP: ', response.status);
        }
      } catch (error) {
        console.error('Error de red o al procesar la petición: ', error);
      }
    },

    async setBotEvai() {
      const token = this.currentUser.access_token;
      try {
        const response = await fetch(`${process.env.WINTOOK_BOT}/api/setConexionEva?token=${token}`, {
          method: 'GET',
        });
        if (!response.ok) {
          throw new Error('Network response was not ok');
        }
        const data = await response.json();
        this.statusBot = data.status;        
      } catch (error) {
        console.error('Fetch error:', error);
        this.conectadoEva = false;
        this.estadoEva = "Iniciar";  // Maneja el estado en caso de error
      }
    }

  },
};
</script>

<template>
  <div class="flex flex-col flex-1 gap-8 overflow-auto">
    <BaseSettingsHeader :title="$t('INTEGRATION_SETTINGS.BOTS_INBOXES.TITLE')"
      feature-name="bots"
      :back-button-label="$t('INTEGRATION_SETTINGS.HEADER')">
      <template #actions>
        <woot-button v-if="statusBot"
          color-scheme="primary"
          class="rounded-md button nice" icon="bot" 
          @click="setBotEvai">
          {{ 'Bot Modo < Encendido >'}}
        </woot-button>
        <woot-button v-if="!statusBot"
          color-scheme="alert"
          class="rounded-md button nice" icon="bot" 
          @click="setBotEvai">
          {{ 'Bot Modo < Apagado >'}}
        </woot-button>
        <woot-button class="rounded-md button nice" icon="bot"
          :color-scheme="colorSchemeI" @click="setBotAccount">
          {{ textButtonI }}
        </woot-button>
      </template>
    </BaseSettingsHeader>
    <div class="w-full overflow-x-auto text-slate-700 dark:text-slate-200">
      <BotTags />
    </div>
    <div class="w-full overflow-x-auto text-slate-700 dark:text-slate-200">
      <table class="min-w-full divide-y divide-slate-75 dark:divide-slate-700">
        <thead>
          <th class="py-4 pr-4 text-left font-semibold text-slate-700 dark:text-slate-300">
            {{ 'Nombre de Canal' }}
          </th>
          <th class="py-4 pr-4 text-left font-semibold text-slate-700 dark:text-slate-300">
            {{ 'Aplicación' }}
          </th>
          <th class="py-4 pr-4 text-left font-semibold text-slate-700 dark:text-slate-300">
            {{ 'Bot EVA' }}
          </th>
        </thead>
        <tbody class="divide-y divide-slate-50 dark:divide-slate-800">
            <tr v-for="inbox in listInboxes" :key="inbox.id">
                <td>{{ inbox.name }}</td>
                <td>
                <span> {{ inbox.channel_type.replace('Channel::', '') }} </span>
                </td>
                <td class="">
                <woot-button v-if="inbox.bot" 
                    icon="bot"
                    color-scheme="primary"
                    icon-size="14" variant="smooth"
                    :disabled="!botI"
                    size="large expanded" @click="setBotInbox(inbox.id)">
                    {{ 'Encendido' }}
                </woot-button>
                <woot-button v-if="!inbox.bot" 
                    icon="bot"
                    color-scheme="alert"
                    icon-size="14" variant="smooth"
                    :disabled="!botI"
                    size="large expanded" @click="setBotInbox(inbox.id)">
                    {{ 'Apagado' }}
                </woot-button>
                </td>
                            <!-- @click="editarCuentaBlog(cuentaBlog.cuenta_blog_id)" -->
            </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
