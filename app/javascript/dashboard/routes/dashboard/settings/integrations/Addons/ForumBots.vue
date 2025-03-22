<template>
    <div>
      <div class="row">
        <div class="integration--image"></div>
        <div class="column">
          <table class="woot-table">
            <thead>
              <th>{{ "Direccion URL Blog" }}</th>
              <th></th>
              <th>
                <button
                  @click="agregarCuentaBlog()"
                  class="button nice"
                  ref="conectorEva"
                >
                  {{ "Agregar" }}
                </button>
              </th>
            </thead>
  
            <tbody>
              <tr
                v-for="cuentaBlog in this.cuentasBlog"
                :key="cuentaBlog.cuenta_blog_id"
              >
                <td>{{ cuentaBlog.cuenta_blog_url }}</td>
                <td class="button-wrapper">
                  <woot-button
                    variant="link"
                    color-scheme="secondary"
                    class-names="grey-btn"
                    icon="edit"
                    @click="editarCuentaBlog(cuentaBlog.cuenta_blog_id)"
                  >
                    {{ "Editar" }}
                  </woot-button>
                  <woot-button
                    variant="link"
                    color-scheme="secondary"
                    class-names="grey-btn"
                    icon="dismiss-circle"
                    @click="openDeletePopup(cuentaBlog)"
                  >
                    {{ "Eliminar" }}
                  </woot-button>
                </td>
                <td></td>
              </tr>
            </tbody>
          </table>
        </div>
  
        <woot-modal :show.sync="showCuentaBlog" :on-close="hideCuentaBlog">
          <div class="column content-box">
            <woot-modal-header
              :header-title="'Eva - Integracion de Blogs'"
              :header-content="'Los blogs son consultados por el Bot Eva...'"
            />
            <form @submit.prevent="onSubmit">
              <label :class="{}">
                Tipo de Blog
                <select v-model="catalogo_blog_id">
                  <option :value="0">{{ "Seleccione Tipo Blog" }}</option>
                  <option
                    v-for="cb in this.catalogoBlogs"
                    :key="cb.catalogo_blog_id"
                    :value="cb.catalogo_blog_id"
                  >
                    {{ cb.catalogo_blog_descripcion }}
                  </option>
                </select>
              </label>
              <label :class="{}">
                <input type="hidden" v-model="cuenta_blog_id" />
              </label>
              <label :class="{}">
                Dirección URL del Blog
                <input type="url" v-model="cuenta_blog_url" />
              </label>
              <woot-button type="submit">Guardar</woot-button>
            </form>
          </div>
        </woot-modal>
  
        <woot-delete-modal
          :show.sync="showDeleteConfirmationPopup"
          :on-close="closeDeletePopup"
          :on-confirm="confirmDeletion"
          :title="'Confirmar eliminación'"
          :message="deleteMessage"
          :confirm-text="deleteConfirmText"
          :reject-text="deleteRejectText"
        />
      </div>
    </div>
  </template>
  <script>
  import axios from "axios";
  import { mapGetters } from "vuex";
  
  export default {
    data() {
      return {
        id: "",
        cuentasBlog: {},
        catalogoBlogs: {},
        catalogo_blog_id: 0,
        catalogo_blog_url: "",
        cuenta_blog_id: 0,
        cuenta_blog_url: "",
        showCuentaBlog: false,
        showDeleteConfirmationPopup: false,
        borrarCuentaBlogURL: "",
        borrarCuentaBlogId: 0,
        // labelBot1: "",
        // labelBot2: "",
        // labelBot3: "",
        // readOnlyLabelBot: false,
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
      this.getCuentasBlog();
    },
  
    methods: {
  
      async getCuentasBlog() {
        const token = this.currentUser.access_token;
        const response = await axios
          .get(process.env.WINTOOK_BOT + "/api/getCuentasBlog", {
            params: { token: token },
          })
          .then(function (resp) {
            return resp.data;
          })
          .catch(function (error) {
            return error;
          });
        if (response.status === 200) {
          this.cuentasBlog = response.data;
        }
  
        const result = await axios
          .get(process.env.WINTOOK_BOT + "/api/getCatalogoBlogs", {})
          .then(function (resp) {
            return resp.data;
          })
          .catch(function (error) {
            return error;
          });
        this.catalogoBlogs = result;
      },
  
      async onSubmit() {
        let token = this.currentUser.access_token;
        let catalogo_blog_id = this.catalogo_blog_id;
        let cuenta_blog_url = this.cuenta_blog_url;
        let cuenta_blog_id = this.cuenta_blog_id;
  
        let resultCuentaBlog = await axios
          .get(process.env.WINTOOK_BOT + "/api/setCuentaBlog", {
            params: {
              token: token,
              catalogo_blog_id: catalogo_blog_id,
              cuenta_blog_url: cuenta_blog_url,
              cuenta_blog_id: cuenta_blog_id,
            },
          })
          .then(function (resp) {
            return resp.data;
          })
          .catch(function (error) {
            return error;
          });
  
        if (resultCuentaBlog.status === 200) {
          this.showCuentaBlog = false;
          this.getCuentasBlog();
        } else {
          bus.$emit(
            "newToastMessage",
            "No fue posible agregar la url del blog, revise su información..."
          );
        }
      },
  
      agregarCuentaBlog() {
        this.catalogo_blog_id = 0;
        this.cuenta_blog_id = 0;
        this.cuenta_blog_url = "";
        this.showCuentaBlog = true;
      },
  
      async editarCuentaBlog(id) {
        let token = this.currentUser.access_token;
        let response = await axios
          .get(process.env.WINTOOK_BOT + "/api/getCuentaBlog", {
            params: { token: token, cuenta_blog_id: id },
          })
          .then(function (resp) {
            return resp.data;
          })
          .catch(function (error) {
            return error;
          });
        if (response.status === 200) {
          this.cuenta_blog_id = response.data.cuenta_blog_id;
          this.catalogo_blog_id = response.data.catalogo_blog_id;
          this.cuenta_blog_url = response.data.cuenta_blog_url;
          this.showCuentaBlog = true;
        }
      },
  
      openDeletePopup(response) {
        this.showDeleteConfirmationPopup = true;
        this.borrarCuentaBlogURL = response.cuenta_blog_url;
        this.borrarCuentaBlogId = response.cuenta_blog_id;
      },
  
      hideCuentaBlog() {
        this.showCuentaBlog = false;
      },
  
      closeDeletePopup() {
        this.showDeleteConfirmationPopup = false;
      },
  
      confirmDeletion() {
        this.closeDeletePopup();
        this.deleteURL();
      },
  
      async deleteURL() {
        let token = this.currentUser.access_token;
        let cuenta_blog_id = this.borrarCuentaBlogId;
        let response = await axios
          .get(process.env.WINTOOK_BOT + "/api/deleteCuentaBlog", {
            params: {
              token: token,
              cuenta_blog_id: cuenta_blog_id,
            },
          })
          .then(function (resp) {
            return resp.data;
          })
          .catch(function (error) {
            return error;
          });
        if (response.status === 200) {
          this.getCuentasBlog();
          bus.$emit(
            "newToastMessage",
            "Se ha eliminado el la dirección URL del blog..."
          );
        }
      },
    },
  };
  </script>