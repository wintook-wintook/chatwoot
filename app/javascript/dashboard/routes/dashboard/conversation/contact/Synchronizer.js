// DEV0002
/* eslint no-console: ["error", { allow: ["log","warn", "error"] }] */
import { mapGetters } from 'vuex';
import { mapActions } from 'vuex';
import { useAlert } from 'dashboard/composables';

import postCreateContactCRM from './constants.js';

export default {
  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
    }),
    integration() {
      return this.$store.getters['integrations/getIntegration']('crmzeus');
    },
  },
  methods: {
    ...mapActions('contacts', ['update']),
    handlePhoneEnter() {
      const phone_number = this.phoneNumber.replace(/\+/g, "");
      this.getFindContactCRM({ 'TELEFONO': phone_number });
    },
    handlePhoneEmail() {
      this.getFindContactCRM({ 'EMAIL': this.email });
    },

    async getIntegration() {
      if (
        this.integration &&
        Array.isArray(this.integration.hooks) &&
        this.integration.hooks.length > 0
      ) {
        const hook = this.integration.hooks[0];
        const { api_url_base, api_access_token } = hook.settings || {};
        if (api_url_base && api_access_token) {
          const url_base = api_url_base.endsWith('/')
            ? api_url_base.slice(0, -1)
            : api_url_base;
          return {
            active: true,
            url_base,
            api_access_token,
          };
        }
      }
      return {
        active: false,
        url_base: null,
        api_access_token: null,
      };
    },

    // 🔍 BÚSQUEDA DE CONTACTOS EN CRMZEUS - CON MANEJO DE ERRORES MEJORADO
    async getFindContactCRM(dataBody) {
      try {
        console.log("🔍 getFindContactCRM - Buscando en CRMZeus:", dataBody);

        const dataIntegration = await this.getIntegration();
        if (!dataIntegration?.active) {
          console.error('La integración o sus hooks no tienen la estructura esperada.');
          return false;
        }

        const { url_base, api_access_token } = dataIntegration;

        const requestOptions = {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            api_access_token: api_access_token,
          },
          body: JSON.stringify(dataBody),
        };

        const response = await fetch(
          `${url_base}/apiCrm/externalAccess/accessToken/api/v1/contact/find_Contacto`,
          requestOptions
        );

        // 🛡️ MANEJO ESPECÍFICO DE CÓDIGOS DE ESTADO HTTP
        if (!response.ok) {
          await this.handleHttpError(response);
          return false;
        }

        const data = await response.json();
        // console.log("getFindContactCRM <data> ========", data);
        const datas = this.processContactData(data)
        return datas;

      } catch (error) {
        return this.handleGeneralError(error);
      }
    },

    // 🛡️ MANEJO ESPECÍFICO DE ERRORES HTTP
    async handleHttpError(response) {
      const status = response.status;
      const statusText = response.statusText;

      let errorData = null;
      try {
        errorData = await response.json();
      } catch {
        // Si no se puede parsear JSON, usar statusText
        errorData = { message: statusText };
      }

      switch (status) {
        case 400:
          console.error('❌ Error 400 - Solicitud incorrecta:', errorData);
          useAlert(this.$t('CONTACT.ERRORS.BAD_REQUEST'), 'error');
          break;

        case 401:
          console.error('❌ Error 401 - No autorizado:', errorData);
          useAlert(this.$t('CONTACT.ERRORS.UNAUTHORIZED'), 'error');
          break;

        case 403:
          console.error('❌ Error 403 - Prohibido:', errorData);
          useAlert(this.$t('CONTACT.ERRORS.FORBIDDEN'), 'error');
          break;

        case 404:
          console.log('ℹ️ Error 404 - Endpoint no encontrado o contacto no existe:', errorData);
          // Para 404, no mostramos error al usuario ya que es normal no encontrar contactos
          useAlert(this.$t('CONTACT.INFO.NOT_FOUND_IN_CRM'), 'info');
          break;

        case 422:
          console.error('❌ Error 422 - Datos no procesables:', errorData);
          useAlert(this.$t('CONTACT.ERRORS.UNPROCESSABLE_ENTITY'), 'error');
          break;

        case 429:
          console.error('❌ Error 429 - Muchas solicitudes:', errorData);
          useAlert(this.$t('CONTACT.ERRORS.RATE_LIMIT'), 'warning');
          break;

        case 500:
        case 502:
        case 503:
        case 504:
          console.error(`❌ Error ${status} - Error del servidor:`, errorData);
          useAlert(this.$t('CONTACT.ERRORS.SERVER_ERROR'), 'error');
          break;

        default:
          console.error(`❌ Error HTTP ${status}:`, errorData);
          useAlert(this.$t('CONTACT.ERRORS.UNKNOWN_HTTP_ERROR', { status }), 'error');
      }
    },

    // 🔄 PROCESAMIENTO DE DATOS DEL CONTACTO
    processContactData(data) {
      const contactIntegration = Array.isArray(data) && data.length ? data[0] : null;

      if (contactIntegration) {
        const {
          NOMBRE: name,
          CORREO: email,
          CELULAR: phone_number,
          CONTACTO_CONTACTO_ID: id_contact,
          TIPO_CONTACTO_CONTACTO_ID: id_contact_type,
          CONTACTO_CONTACTOS_EMAIL_ID: id_contact_email,
          ORG: { ORG_ID: id_company, NOMBRE: company_name } = {}
        } = contactIntegration;

        // Cargar datos del formulario
        this.updateContactFields({
          id_company: id_company || 0,
          id_contact: id_contact || 0,
          id_contact_type: id_contact_type || 0,
          id_contact_email,
          name: name || '',
          email: email || '',
          phoneNumber: phone_number
            ? phone_number.startsWith('+')
              ? phone_number
              : `+${phone_number}`
            : '',
          companyName: company_name || ''
        });

        // 🆕 PREPARAR CUSTOM ATTRIBUTES
        this.preparedCustomAttributes = {
          idcontacto_crmzeus: id_contact,
          idorganizacion_crmzeus: id_company
        };

        console.log("✅ Contacto encontrado en CRMZeus - Datos y custom_attributes preparados:", {
          name: this.name,
          company: this.companyName,
          custom_attributes: this.preparedCustomAttributes
        });

        useAlert(this.$t('CONTACT.SUCCESS.FOUND_IN_CRM'), 'success');
        return ({
          name: this.name,
          company: this.companyName,
          custom_attributes: this.preparedCustomAttributes
        });

      } else {
        this.resetContactData();
        console.log("ℹ️ Contacto no encontrado en CRMZeus");
        useAlert(this.$t('CONTACT.INFO.NOT_FOUND_IN_CRM'), 'info');
        return false;
      }
    },

    // 🚨 MANEJO DE ERRORES GENERALES (RED, TIMEOUT, ETC.)
    handleGeneralError(error) {
      this.resetContactData();

      if (error.name === 'TypeError' && error.message.includes('fetch')) {
        console.error('❌ Error de red - No se puede conectar con CRMZeus:', error);
        useAlert(this.$t('CONTACT.ERRORS.NETWORK_ERROR'), 'error');
      } else if (error.name === 'AbortError') {
        console.error('❌ Solicitud cancelada/timeout:', error);
        useAlert(this.$t('CONTACT.ERRORS.TIMEOUT'), 'warning');
      } else if (error instanceof SyntaxError) {
        console.error('❌ Error al parsear respuesta JSON:', error);
        useAlert(this.$t('CONTACT.ERRORS.INVALID_RESPONSE'), 'error');
      } else {
        console.error('❌ Error inesperado al buscar contacto:', error);
        useAlert(this.$t('CONTACT.ERRORS.UNEXPECTED_ERROR'), 'error');
      }

      return false;
    },

    // 🧹 MÉTODOS AUXILIARES
    updateContactFields(fields) {
      Object.assign(this, fields);
    },

    resetContactData() {
      this.crmContact = {};
      this.preparedCustomAttributes = null;
    },

    // 📋 CARGAR CONTACTO EXISTENTE PARA EDICIÓN
    async setContactIntegration(contact) {
      try {
        this.crmContact = {};
        // const { custom_attributes } = contact || {};
        const {
          custom_attributes: { idcontacto_crmzeus: id_contact = 0 } = {},
        } = contact || {};
        if (id_contact === 0) return (this.crmContact);

        const dataIntegration = await this.getIntegration();
        if (!dataIntegration?.active) {
          console.error('La integración o sus hooks no tienen la estructura esperada.');
          return false;
        }
        const { url_base, api_access_token } = dataIntegration;

        const requestOptions = {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            api_access_token: api_access_token,
          },
          body: JSON.stringify({
            CONTACTO_CONTACTO_ID: id_contact,
          }),
        };

        const response = await fetch(
          `${url_base}/apiCrm/externalAccess/accessToken/api/v1/contact/get_Contacto`,
          requestOptions
        );
        const contactIntegration = await response.json();
        this.crmContact = {
          name: contactIntegration.NOMBRE,
          email: contactIntegration.CORREO,
          phone_number: contactIntegration.CELULAR,
          companyName: contactIntegration.ORG.NOMBRE,
          id_company: contactIntegration.ORG.ORG_ID,
          id_contact: id_contact,
          id_contact_type: contactIntegration.TIPO_CONTACTO_CONTACTO_ID,
          id_contact_email: contactIntegration.CONTACTO_CONTACTOS_EMAIL_ID
        };
        // console.log("this.crmContact -->", this.crmContact)
        return (this.crmContact)
      } catch (error) {
        this.crmContact = {};
        console.error('Error al configurar la integración de contacto:', error);
        return (this.crmContact)
      }
    },

    // 🎯 MÉTODO PRINCIPAL DE SINCRONIZACIÓN - SIMPLIFICADO
    async setContactCRM(contact, isNewContact = false) {
      try {
        const dataIntegration = await this.getIntegration();

        if (!dataIntegration?.active) {
          console.error('Integración inactiva o mal estructurada.');
          return false;
        }

        const {
          id_company: idOrgCRMZeus,
          id_contact: idContactoCRMZeus,
          id_wcontact: idContactoWintook = 0
        } = contact;

        console.log("🎯 setContactCRM - Parámetros:", {
          isNewContact,
          idContactoCRMZeus,
          idOrgCRMZeus,
          idContactoWintook,
          contactName: contact.name,
          hasCustomAttributes: !!contact.custom_attributes
        });

        const { crmzeus } = await this.validateParams(
          idOrgCRMZeus,
          idContactoCRMZeus,
          idContactoWintook,
          isNewContact
        );

        console.log("🎯 Acción determinada para CRMZeus:", crmzeus);

        if (!idOrgCRMZeus) {
          console.log("📝 Sin organización: usando AddWebForm");
          await this.addByWebform(contact);
          return;
        }

        switch (crmzeus) {
          case 'UPDATE':
            console.log("🔄 Editando contacto - actualizando en CRMZeus...");
            await this.updContact(contact);
            break;
          case 'ADD':
            console.log("➕ Agregando nuevo contacto en CRMZeus...");
            await this.addContact(contact);
            break;
          case 'ADDFORM':
            console.log("📝 Usando formulario web para agregar contacto...");
            await this.addByWebform(contact);
            break;
          case 'NA':
            console.log("✅ Contacto nuevo ya creado con custom_attributes - No se requiere acción adicional");
            // 🎉 NO HACER NADA - Los custom_attributes ya se incluyeron en la creación
            break;
          default:
            console.warn('⚠️ Acción desconocida:', crmzeus);
        }

      } catch (error) {
        console.error('❌ Error en setContactCRM:', error);
      }
    },

    // 🧠 LÓGICA DE VALIDACIÓN (SIN CAMBIOS)
    async validateParams(idOrgCRMZeus, idContactoCRMZeus, idContactoWintook, isNewContact = false) {
      const wintook = idContactoWintook === 0 ? 'ADD' : 'UPDATE';

      let crmzeus = 'NA';

      if (idOrgCRMZeus === 0) {
        crmzeus = 'ADDFORM';
      } else if (idOrgCRMZeus > 1) {
        if (idContactoCRMZeus === 0) {
          crmzeus = 'ADD';
        } else {
          if (isNewContact) {
            crmzeus = 'NA'; // Ya se creó con custom_attributes
          } else {
            crmzeus = idContactoWintook === 0 ? 'NA' : 'UPDATE';
          }
        }
      }

      console.log("validateParams resultado:", { wintook, crmzeus, isNewContact });
      return { wintook, crmzeus };
    },

    // 🔄 ACTUALIZAR CONTACTO EN CRMZEUS
    async updContact(contact) {
      console.log("updContact")
      try {
        const dataIntegration = await this.getIntegration();
        if (!dataIntegration?.active) {
          console.error('La integración o sus hooks no tienen la estructura esperada.');
          return false;
        }
        const { url_base, api_access_token } = dataIntegration;
        const { name, phone_number, id_company, id_contact, email, id_contact_type, id_contact_email } = contact;

        const postBody = {
          CONTACTO_CONTACTO_ID: id_contact,
          NOMBRE: name,
          TELEFONO: phone_number.replace(/\D/g, ''),
          CELULAR: phone_number.replace(/\D/g, ''),
          ES_PPAL: true,
          CLIENTE_ID: id_company,
          PASSWORD: "12345678",
          TIPO_CONTACTO_CONTACTO_ID: id_contact_type,
          CORREOS: {
            resources: [
              {
                CONTACTO_CONTACTOS_EMAIL_ID: id_contact_email,
                EMAIL: email,
                ES_PPAL: "1",
                USAR_MKT: "N",
                ESTATUS_ID: "A"
              }
            ]
          }
        };

        const requestOptions = {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            api_access_token: api_access_token,
          },
          body: JSON.stringify(postBody),
        };

        console.log("Actualizando contacto en CRMZeus...");
        const response = await fetch(
          `${url_base}/apiCrm/externalAccess/accessToken/api/v1/contact/upd_Contacto`,
          requestOptions
        );
        const resultUpdateContact = await response.json();
        console.log("resultUpdateContact -->", resultUpdateContact)

        if (response.status === 404) {
          console.log("showEmailExistsModal con error 404");
          this.showEmailExistsModal = true;
          const custom_attributes = {
            "idcontacto_crmzeus": 0,
            "idorganizacion_crmzeus": resultUpdateContact.CLIENTE_ID
          };

          const { id_wcontact: id } = contact;
          const updatedFields = {
            id,
            custom_attributes
          };
          await this.update(updatedFields);
          return;
        }
      } catch (error) {
        this.crmContact = {};
        console.error('Error al configurar la integración de contacto:', error);
      }
    },

    // ➕ AGREGAR CONTACTO EN CRMZEUS
    async addContact(contact) {
      console.log("addContact")
      const contactType = await this.contactType();
      console.log("contactType", contactType);
      try {
        const dataIntegration = await this.getIntegration();
        if (!dataIntegration?.active) {
          console.error('La integración o sus hooks no tienen la estructura esperada.');
          return false;
        }
        const { url_base, api_access_token } = dataIntegration;

        const { name, phone_number, id_company, email } = contact;
        const tipo_contacto_contacto_id = contactType.TIPO_CONTACTO_CONTACTO_ID
        const postBody = {
          NOMBRE: name,
          TITULO: 'Titulo',
          TELEFONO: phone_number.replace(/\D/g, ''),
          CELULAR: phone_number.replace(/\D/g, ''),
          ES_PPAL: true,
          PUESTO: '',
          CLIENTE_ID: id_company,
          PASSWORD: "12345678",
          TIPO_CONTACTO_CONTACTO_ID: tipo_contacto_contacto_id,
          CORREOS: {
            resources: [
              {
                EMAIL: email,
                ES_PPAL: "1",
                USAR_MKT: "N",
                ESTATUS_ID: "A"
              }
            ]
          }
        };

        const requestOptions = {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            api_access_token: api_access_token,
          },
          body: JSON.stringify(postBody),
        };

        const response = await fetch(
          `${url_base}/apiCrm/externalAccess/accessToken/api/v1/contact/add_contacto`,
          requestOptions
        );
        const resultAddContact = await response.json();
        if (response.status === 404) {
          this.showEmailExistsModal = true;
          return;
        }
        await this.addCustomAttributes(resultAddContact, contact);
      } catch (error) {
        this.crmContact = {};
        console.error('Error al configurar la integración de contacto:', error);
      }
    },

    // 📝 AGREGAR POR FORMULARIO WEB
    async addByWebform(contact) {
      console.log("addByWebform")
      try {
        const dataIntegration = await this.getIntegration();
        if (!dataIntegration?.active) {
          console.error('La integración o sus hooks no tienen la estructura esperada.');
          return false;
        }
        const { url_base, api_access_token } = dataIntegration;

        const { name, phone_number, email, additional_attributes : { company_name }} = contact;
        const postForm = {
          TIPO: "Wintook",
          nameuser: company_name,
          emailuser: email,
          teluser: phone_number.replace(/\D/g, ''),
          contacto1user: name,
        };

        const postBody = { ...postForm, ...postCreateContactCRM };
        const requestOptions = {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            api_access_token: api_access_token,
          },
          body: JSON.stringify(postBody),
        };

        const response = await fetch(
          `${url_base}/apiCrm/externalAccess/accessToken/api/v2/prospect/add_byWebform`,
          requestOptions
        );
        const resultAddByWebform = await response.json();
        console.log("resultAddByWebform")
        await this.addCustomAttributes(resultAddByWebform, contact);
      } catch (error) {
        this.crmContact = {};
        console.error('Error al configurar la integración de contacto:', error);
      }
    },

    // 🏷️ OBTENER TIPO DE CONTACTO
    async contactType() {
      console.log("contactType")
      try {
        const dataIntegration = await this.getIntegration();
        if (!dataIntegration?.active) {
          console.error('La integración o sus hooks no tienen la estructura esperada.');
          return false;
        }
        const { url_base, api_access_token } = dataIntegration;
        const requestOptions = {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            api_access_token: api_access_token,
          }
        };

        const response = await fetch(
          `${url_base}/apiCrm/externalAccess/accessToken/api/v1/catalog/getLst_TipoContacto`,
          requestOptions
        );
        const resultContactType = await response.json();
        const elementDefault = resultContactType.find(item => item.ES_DEFAULT === "S");
        return elementDefault;
      } catch (error) {
        this.crmContact = {};
        console.error('Error al configurar la integración de contacto:', error);
      }
    },

    // 🔗 MÉTODO PARA CASOS DONDE AÚN SE NECESITA ACTUALIZACIÓN POSTERIOR
    async addCustomAttributes(data, contact) {
      console.log("addCustomAttributes > data")
      console.log(data)
      console.log("addCustomAttributes > contact")
      console.log(contact)

      console.log("🔗 addCustomAttributes - Para casos de creación en CRMZeus...");
      try {
        // const custom_attributes = await this.getContactCRM(data);
        // console.log("🏷️ Custom attributes obtenidos:", custom_attributes);
        const custom_attributes = {
          "idcontacto_crmzeus": data.CONTACTO_CONTACTO_ID,
          "idorganizacion_crmzeus": data.CLIENTE_ID
        };

        const { id_wcontact: id } = contact;
        const updatedFields = {
          id,
          custom_attributes
        };

        // await this.$store.dispatch('contacts/update', updatedFields);
        await this.update(updatedFields);

        console.log("✅ Custom attributes actualizados via Vuex store");
      } catch (error) {
        console.error('❌ Error al actualizar custom attributes:', error);
      }
    },

    // 📊 OBTENER DATOS DEL CONTACTO DESDE CRMZEUS
    async getContactCRM(data) {
      try {
        const { CONTACTO_CONTACTO_ID } = data;
        const dataIntegration = await this.getIntegration();
        if (!dataIntegration?.active) {
          console.error('La integración o sus hooks no tienen la estructura esperada.');
          return false;
        }
        const { url_base, api_access_token } = dataIntegration;

        const requestOptions = {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            api_access_token: api_access_token,
          },
          body: JSON.stringify({
            CONTACTO_CONTACTO_ID
          }),
        };

        const response = await fetch(
          `${url_base}/apiCrm/externalAccess/accessToken/api/v1/contact/get_Contacto`,
          requestOptions
        );
        const resultGetContactCRM = await response.json();
        console.log('Datos del contacto en CRMZeus:', resultGetContactCRM);

        const customAttributes = {
          "idcontacto_crmzeus": resultGetContactCRM.CONTACTO_CONTACTO_ID,
          "idorganizacion_crmzeus": resultGetContactCRM.CLIENTE_ID
        };

        console.log("Custom attributes preparados:", customAttributes);
        return customAttributes;
      } catch (error) {
        this.crmContact = {};
        console.error('Error al obtener contacto de CRMZeus:', error);
      }
    },



    async searchContactCRMZeusById(contact) {
      try {
        const {
          custom_attributes: { idcontacto_crmzeus: CONTACTO_CONTACTO_ID = 0 } = {},
        } = contact || {};

        console.log("CONTACTO_CONTACTO_ID", CONTACTO_CONTACTO_ID)

        // Validación temprana
        if (!CONTACTO_CONTACTO_ID) {
          console.warn('ID de contacto no proporcionado');
          return {
            success: false,
            message: "ID de contacto no proporcionado",
            data: {}
          };
        }

        const dataIntegration = await this.getIntegration();
        const { url_base, api_access_token } = dataIntegration;

        const response = await fetch(
          `${url_base}/apiCrm/externalAccess/accessToken/api/v1/contact/get_Contacto`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              api_access_token,
            },
            body: JSON.stringify({
              CONTACTO_CONTACTO_ID
            }),
          }
        );

        if (!response.ok) {
          return {
            success: false,
            message: `HTTP error! status: ${response.status}`,
            data: {}
          };
        }

        const result = await response.json();
        // Validación para resultado vacío
        if (!result || Object.keys(result).length === 0) {
          return {
            success: false,
            message: "Contacto previamente sincronizado pero no encontrado por ID",
            data: {}
          };
        }

        // Validación adicional para campos esenciales
        if (!result.NOMBRE && !result.CORREO && !result.CELULAR) {
          return {
            success: false,
            message: "Contacto encontrado pero sin datos válidos",
            data: {}
          };
        }

        const data = {
          name: result.NOMBRE,
          email: result.CORREO,
          phone_number: result.CELULAR,
          companyName: result.ORG?.NOMBRE,
          id_company: result.ORG?.ORG_ID,
          id_contact: CONTACTO_CONTACTO_ID,
          id_contact_type: result.TIPO_CONTACTO_CONTACTO_ID,
          id_contact_email: result.CONTACTO_CONTACTOS_EMAIL_ID
        };

        return {
          success: true,
          message: "Contacto encontrado por ID en CRMZeus",
          data
        };

      } catch (error) {
        return {
          success: false,
          message: `Error al obtener contacto de CRMZeus: ${error.message || error}`,
          data: {}
        };
      }
    },

    async searchContactCRMZeusByPhone(contact) {
      try {
        const { phone_number } = contact
        const payload = { TELEFONO: phone_number?.replace(/\+/g, '') };

        console.log("payload", payload)

        const dataIntegration = await this.getIntegration();
        const { url_base, api_access_token } = dataIntegration;

        const response = await fetch(
          `${url_base}/apiCrm/externalAccess/accessToken/api/v1/contact/find_Contacto`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              api_access_token,
            },
            body: JSON.stringify(payload),
          }
        );

        if (!response.ok) {
          return {
            success: false,
            message: `HTTP error! status: ${response.status}`,
            data: {}
          };
        }

        const result = await response.json();
        console.log("result", result)

        // Validación para resultado vacío
        if (!result || (Array.isArray(result) && result.length === 0) || Object.keys(result).length === 0) {
          return {
            success: false,
            message: "No se encontró el contacto en CRMZeus",
            data: {}
          };
        }

        // Si es un array, tomar el primer elemento
        const firstResult = Array.isArray(result) ? result[0] : result;

        console.log("firstResult", firstResult);

        // Validación adicional para campos esenciales del primer resultado
        if (!firstResult || (!firstResult.NOMBRE && !firstResult.CORREO && !firstResult.CELULAR)) {
          return {
            success: false,
            message: "Contacto encontrado pero sin datos válidos",
            data: {}
          };
        }

        const data = {
          name: firstResult.NOMBRE,
          email: firstResult.CORREO,
          phone_number: firstResult.CELULAR,
          companyName: firstResult.ORG?.NOMBRE,
          id_company: firstResult.ORG?.ORG_ID,
          id_contact: firstResult.CONTACTO_CONTACTO_ID, // Corregido: usar el ID del resultado
          id_contact_type: firstResult.TIPO_CONTACTO_CONTACTO_ID,
          id_contact_email: firstResult.CONTACTO_CONTACTOS_EMAIL_ID
        };

        return {
          success: true,
          message: "Contacto obtenido exitosamente por número telefónico...",
          data
        };

      } catch (error) {
        return {
          success: false,
          message: `Error al obtener contacto de CRMZeus: ${error.message || error}`,
          data: {}
        };
      }
    },

    async searchContactCRMZeusByEmail(contact) {
      try {
        const { email } = contact
        const payload = { EMAIL: email };

        console.log("payload", payload)

        const dataIntegration = await this.getIntegration();
        const { url_base, api_access_token } = dataIntegration;

        const response = await fetch(
          `${url_base}/apiCrm/externalAccess/accessToken/api/v1/contact/find_Contacto`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              api_access_token,
            },
            body: JSON.stringify(payload),
          }
        );

        if (!response.ok) {
          return {
            success: false,
            message: `HTTP error! status: ${response.status}`,
            data: {}
          };
        }

        const result = await response.json();
        console.log("result", result)

        // Validación para resultado vacío
        if (!result || (Array.isArray(result) && result.length === 0) || Object.keys(result).length === 0) {
          return {
            success: false,
            message: "No se encontró el contacto en CRMZeus",
            data: {}
          };
        }

        // Si es un array, tomar el primer elemento
        const firstResult = Array.isArray(result) ? result[0] : result;
        // Validación adicional para campos esenciales del primer resultado
        if (!firstResult || (!firstResult.NOMBRE && !firstResult.CORREO && !firstResult.CELULAR)) {
          return {
            success: false,
            message: "Contacto encontrado pero sin datos válidos",
            data: {}
          };
        }

        const data = {
          name: firstResult.NOMBRE,
          email: firstResult.CORREO,
          phone_number: firstResult.CELULAR,
          companyName: firstResult.ORG?.NOMBRE,
          id_company: firstResult.ORG?.ORG_ID,
          id_contact: firstResult.CONTACTO_CONTACTO_ID, // Corregido: usar el ID del resultado
          id_contact_type: firstResult.TIPO_CONTACTO_CONTACTO_ID,
          id_contact_email: firstResult.CONTACTO_CONTACTOS_EMAIL_ID
        };

        return {
          success: true,
          message: "Contacto obtenido exitosamente por correo electrónico...",
          data
        };

      } catch (error) {
        return {
          success: false,
          message: `Error al obtener contacto de CRMZeus: ${error.message || error}`,
          data: {}
        };
      }
    },

    // async searchContactCRMZeusByEmail(contact) {
    //   try {
    //     const {
    //       custom_attributes: { idcontacto_crmzeus: CONTACTO_CONTACTO_ID = 0 } = {},
    //     } = contact || {};

    //     console.log("CONTACTO_CONTACTO_ID", CONTACTO_CONTACTO_ID)

    //     // Validación temprana
    //     if (!CONTACTO_CONTACTO_ID) {
    //       console.warn('ID de contacto no proporcionado');
    //       return {
    //         success: false,
    //         message: "ID de contacto no proporcionado",
    //         data: {}
    //       };
    //     }

    //     const dataIntegration = await this.getIntegration();
    //     const { url_base, api_access_token } = dataIntegration;

    //     const response = await fetch(
    //       `${url_base}/apiCrm/externalAccess/accessToken/api/v1/contact/get_Contacto`,
    //       {
    //         method: 'POST',
    //         headers: {
    //           'Content-Type': 'application/json',
    //           api_access_token,
    //         },
    //         body: JSON.stringify({
    //           CONTACTO_CONTACTO_ID
    //         }),
    //       }
    //     );

    //     if (!response.ok) {
    //       return {
    //         success: false,
    //         message: `HTTP error! status: ${response.status}`,
    //         data: {}
    //       };
    //     }

    //     const result = await response.json();
    //     console.log("result", result)

    //     // Validación para resultado vacío
    //     if (!result || Object.keys(result).length === 0) {
    //       return {
    //         success: false,
    //         message: "No se encontró el contacto en CRMZeus",
    //         data: {}
    //       };
    //     }

    //     // Validación adicional para campos esenciales
    //     if (!result.NOMBRE && !result.CORREO && !result.CELULAR) {
    //       return {
    //         success: false,
    //         message: "Contacto encontrado pero sin datos válidos",
    //         data: {}
    //       };
    //     }

    //     const data = {
    //       name: result.NOMBRE,
    //       email: result.CORREO,
    //       phone_number: result.CELULAR,
    //       companyName: result.ORG?.NOMBRE,
    //       id_company: result.ORG?.ORG_ID,
    //       id_contact: CONTACTO_CONTACTO_ID,
    //       id_contact_type: result.TIPO_CONTACTO_CONTACTO_ID,
    //       id_contact_email: result.CONTACTO_CONTACTOS_EMAIL_ID
    //     };

    //     return {
    //       success: true,
    //       message: "Contacto obtenido exitosamente...",
    //       data
    //     };

    //   } catch (error) {
    //     return {
    //       success: false,
    //       message: `Error al obtener contacto de CRMZeus: ${error.message || error}`,
    //       data: {}
    //     };
    //   }
    // },

    async searchContactInCRM(contact) {
      try {
        console.log('🔍 Iniciando búsqueda de contacto en CRMZeus...');

        // Definir criterios de búsqueda en orden de prioridad
        const searchCriteria = [
          {
            field: 'phone_number',
            value: contact.phone_number?.replace(/\+/g, ''),
            payload: { TELEFONO: contact.phone_number?.replace(/\+/g, '') },
            label: 'teléfono'
          },
          {
            field: 'email',
            value: contact.email,
            payload: { EMAIL: contact.email },
            label: 'correo electrónico'
          }
        ];

        const dataIntegration = await this.getIntegration();
        const { url_base, api_access_token } = dataIntegration;

        // Buscar usando cada criterio hasta encontrar resultado
        for (const criteria of searchCriteria) {
          if (!criteria.value) continue; // Saltar si no hay valor

          console.log(`🔍 Buscando por ${criteria.label}:`, criteria.value);
          this[criteria.field === 'phone_number' ? 'phoneNumber' : criteria.field] = criteria.value;

          const response = await fetch(
            `${url_base}/apiCrm/externalAccess/accessToken/api/v1/contact/find_Contacto`,
            {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                api_access_token: api_access_token,
              },
              body: JSON.stringify(criteria.payload),
            }
          );

          if (!response.ok) {
            console.warn(`⚠️ Error HTTP al buscar por ${criteria.label}: ${response.status}`);
            continue; // Continuar con el siguiente criterio
          }

          const result = await response.json();
          console.log(`📋 Resultado de búsqueda por ${criteria.label}:`, result);

          // Validación para resultado vacío
          if (!result || Object.keys(result).length === 0) {
            console.log(`ℹ️ No se encontró contacto por ${criteria.label}`);
            continue; // Continuar con el siguiente criterio
          }

          // Validación adicional para campos esenciales
          if (!result.NOMBRE && !result.CORREO && !result.CELULAR) {
            console.log(`⚠️ Contacto encontrado por ${criteria.label} pero sin datos válidos`);
            continue; // Continuar con el siguiente criterio
          }

          // ¡Contacto encontrado con datos válidos!
          console.log(`✅ Contacto encontrado exitosamente por ${criteria.label}`);

          const data = {
            name: result.NOMBRE,
            email: result.CORREO,
            phone_number: result.CELULAR,
            companyName: result.ORG?.NOMBRE,
            id_company: result.ORG?.ORG_ID,
            id_contact: result.CONTACTO_CONTACTO_ID, // Corregido: usar el ID del resultado
            id_contact_type: result.TIPO_CONTACTO_CONTACTO_ID,
            id_contact_email: result.CONTACTO_CONTACTOS_EMAIL_ID
          };

          this.contactFoundInCRM = true;
          this.crmContact = data;

          return {
            success: true,
            message: `Contacto encontrado exitosamente por ${criteria.label}`,
            data
          };
        }

        // No se encontró con ningún criterio
        console.log('ℹ️ Contacto no encontrado en CRMZeus con ningún criterio');
        this.contactFoundInCRM = false;
        this.crmContact = {};

        return {
          success: false,
          message: "Contacto no encontrado en CRMZeus",
          data: {}
        };

      } catch (error) {
        console.error('❌ Error al buscar contacto en CRMZeus:', error);
        this.contactFoundInCRM = false;
        this.crmContact = {};

        return {
          success: false,
          message: `Error al buscar contacto en CRMZeus: ${error.message || error}`,
          data: {}
        };
      }
    },

    // async checkBeforeUpdatingEmail(contact) {
    //   console.log(`checkBeforeUpdatingEmail`)
    //   const dataIntegration = await this.getIntegration();

    //   if (!dataIntegration?.active) {
    //     console.error('La integración o sus hooks no tienen la estructura esperada.');
    //     return false;
    //   }

    //   const {
    //     custom_attributes: {
    //       idcontacto_crmzeus = 0,
    //       idorganizacion_crmzeus = 0
    //     } = {},
    //   } = contact || {};

    //   const contactEmail = await this.searchContactCRMZeusByEmail(contact)
    //   if (!contactEmail.success) {
    //     return false;
    //   }
    //   const { data : { id_company, id_contact }  } =  contactEmail
    //   console.log(`Datos extraidos id_company : ${id_company} y id_contact: ${id_contact}`)
    //   console.log(`Datos extraidos idcontacto_crmzeus >  ${idcontacto_crmzeus} y idorganizacion_crmzeus : ${id_contact}`)
    //   console.log(`Valor ${id_contact !== idcontacto_crmzeus && id_company === idorganizacion_crmzeus}`)
    //   return id_contact !== idcontacto_crmzeus && id_company === idorganizacion_crmzeus;
    //   // console.log(`idcontacto_crmzeus : ${idcontacto_crmzeus}, idorganizacion_crmzeus : ${idorganizacion_crmzeus}`)

    // },

    // 🔧 VERSIÓN MEJORADA del método en Synchronizer.js
    async checkBeforeUpdatingEmail(contact) {
      console.log('🔍 checkBeforeUpdatingEmail - Verificando email:', contact.email);

      try {
        // 1. Verificar integración activa
        const dataIntegration = await this.getIntegration();
        if (!dataIntegration?.active) {
          console.warn('⚠️ Integración CRMZeus inactiva, saltando verificación');
          return false;
        }

        // 2. Verificar que hay custom attributes
        const {
          custom_attributes: {
            idcontacto_crmzeus = 0,
            idorganizacion_crmzeus = 0
          } = {},
        } = contact || {};

        if (!idcontacto_crmzeus || !idorganizacion_crmzeus) {
          console.log('ℹ️ Contacto sin sincronización CRM previa, no hay conflicto posible');
          return false;
        }

        // 3. Verificar que hay email para buscar
        if (!contact.email || contact.email.trim() === '') {
          console.log('ℹ️ Sin email para verificar');
          return false;
        }

        // 4. Buscar email en CRMZeus
        console.log('🔍 Buscando email en CRMZeus...');
        const emailSearchResult = await this.searchContactCRMZeusByEmail(contact);

        if (!emailSearchResult.success) {
          console.log('✅ Email no encontrado en CRMZeus, no hay conflicto');
          return false;
        }

        const { data: foundContact } = emailSearchResult;
        const { id_company: foundCompanyId, id_contact: foundContactId } = foundContact;

        // 5. Comparar IDs para detectar conflicto
        console.log('📊 Comparando contactos:', {
          encontrado: {
            id_contact: foundContactId,
            id_company: foundCompanyId
          },
          actual: {
            idcontacto_crmzeus,
            idorganizacion_crmzeus
          }
        });

        // Hay conflicto si:
        // - El email pertenece a otro contacto (diferente ID)
        // - Pero está en la misma organización
        const hasConflict = (
          foundContactId !== idcontacto_crmzeus &&
          foundCompanyId === idorganizacion_crmzeus
        );

        if (hasConflict) {
          console.warn('⚠️ CONFLICTO DETECTADO: Email existe en otro contacto de la misma organización');
        } else {
          console.log('✅ Sin conflictos detectados');
        }

        return hasConflict;

      } catch (error) {
        console.error('❌ Error en checkBeforeUpdatingEmail:', error);
        // En caso de error, no bloquear al usuario
        return false;
      }
    },


    async checkStatusContactWintook(contact) {
      try {

        const { email } = contact
        const contacts = await this.$store.dispatch('contacts/filter', {
          queryPayload: {
            "payload": [
              {
                "attribute_key": "email",
                "filter_operator": "equal_to",
                "values": [email],
                "attribute_model": "standard",
                "custom_attribute_type": ""
              }
            ]
          },
        });

        console.log(`✅✅✅✅✅✅✅✅Filtro de contacts:`)
        console.log(contacts)
        const firstContact = contacts && contacts.length > 0 ? contacts[0] : null;

        if (firstContact) {
          const { id: id_contact } = contact
          const { id: id_contact_filter } = firstContact
          if (id_contact !== id_contact_filter) {
            return true
          }
          console.log('Primer contacto:', firstContact);
        } else {
          console.log('No se encontraron contactos');
        }
      } catch (error) {
        console.error('Error filtering contacts:', error);
      }
    }



  },
};