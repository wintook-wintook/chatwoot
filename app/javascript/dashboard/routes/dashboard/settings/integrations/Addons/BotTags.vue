<template>
  <div>
    <div class="flex">
      <div class="integration--image"></div>
      <div class="flex flex-col">
        <form class="flex flex-row space-x-4" @submit.prevent="setChatGTP">
          <!-- Primer grupo (Etiqueta Bot 1) -->
          <div class="flex flex-col">
            <label class="mb-1">{{ "Etiqueta Bot 1" }}</label>
            <input v-model="labelBot1" type="text" :disabled="readOnlyLabelBot" class="p-2 border border-gray-300 rounded" />
          </div>

          <!-- Segundo grupo (Etiqueta Bot 2) -->
          <div class="flex flex-col">
            <label class="mb-1">{{ "Etiqueta Bot 2" }}</label>
            <input v-model="labelBot2" type="text" :disabled="readOnlyLabelBot" class="p-2 border border-gray-300 rounded" />
          </div>

          <!-- Tercer grupo (Etiqueta Bot 3) -->
          <div class="flex flex-col">
            <label class="mb-1">{{ "Etiqueta Bot 3" }}</label>
            <input v-model="labelBot3" type="text" :disabled="readOnlyLabelBot" class="p-2 border border-gray-300 rounded" />
          </div>

          <!-- Botón -->
          <div class="flex flex-col justify-center pt-4">
            <woot-button
              @click="setLabelsBots()"
              v-if="!readOnlyLabelBot"
              class="bg-blue-500 text-white rounded disabled:opacity-50"
              >{{ "Guardar" }}</woot-button
            >
            <woot-button @click="editLabelsBots()" v-if="readOnlyLabelBot" 
              class="bg-gray-500 text-white rounded">
              {{ "Editar" }}
            </woot-button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

  <script>
  import axios from "axios";
  import { mapGetters } from "vuex";
  
  export default {
    data() {
      return {
        labelBot1: "",
        labelBot2: "",
        labelBot3: "",
        readOnlyLabelBot: false,
      };
    },
    computed: {
      ...mapGetters({
        currentUser: "getCurrentUser",
        getAccount: "accounts/getAccount",
        accountId: "getCurrentAccountId",
      }),
  
      // Delete Modal
      deleteConfirmText() {
        return `${this.$t("LABEL_MGMT.DELETE.CONFIRM.YES")} ${
          this.borrarCuentaBlogURL
        }`;
      },
      deleteRejectText() {
        return `${this.$t("LABEL_MGMT.DELETE.CONFIRM.NO")} ${
          this.borrarCuentaBlogURL
        }`;
      },
      deleteMessage() {
        return `${this.$t("LABEL_MGMT.DELETE.CONFIRM.MESSAGE")} ${
          this.borrarCuentaBlogURL
        } ?`;
      },
    },
  
    mounted() {
      this.getLabelsBots();
    },
  
    methods: {
      async editLabelsBots() {
        this.readOnlyLabelBot = false;
      },
      async setLabelsBots() {
        const { access_token, account_id } = this.currentUser;
        const labelBot1 = this.labelBot1;
        const labelBot2 = this.labelBot2;
        const labelBot3 = this.labelBot3;
  
        const result = await axios
          .post(process.env.WINTOOK_BOT + "/api/setLabelsBots", {
            access_token,
            account_id,
            labelBot1,
            labelBot2,
            labelBot3,
          })
          .then(function (resp) {
            return resp.data;
          })
          .catch(function (error) {
            return error;
          });
  
        if (result.status === 200) {
          this.readOnlyLabelBot = true;
          bus.$emit("newToastMessage", result.toastMessage);
        }
      },
  
      async getLabelsBots() {
        const { access_token, account_id } = this.currentUser;
  
        const result = await axios
          .get(process.env.WINTOOK_BOT + "/api/getLabelsBots", {
            params: {
              access_token: access_token,
              account_id: account_id,
            },
          })
          .then(function (resp) {
            return resp.data;
          })
          .catch(function (error) {
            return error;
          });
  
        if (result.status === 200) {
          this.labelBot1 = result.labelBot1;
          this.labelBot2 = result.labelBot2;
          this.labelBot3 = result.labelBot3;
          this.readOnlyLabelBot = true;
        }
      },
  
      async initializeAccount() {
        try {
          await this.$store.dispatch("accounts/get");
          const { custom_attributes } = this.getAccount(this.accountId);
  
          console.log(this.getAccount(this.accountId));
  
          this.nameBot1 = custom_attributes.nameBot1;
          this.nameBot2 = custom_attributes.nameBot2;
          this.nameBot3 = custom_attributes.nameBot3;
        } catch (error) {
          // Ignore error
        }
      },
    },
  };
  </script>