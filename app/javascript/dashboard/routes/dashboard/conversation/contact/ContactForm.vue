<!-- DEV0002 -->
<script>
/* eslint no-console: ["error", { allow: ["log","warn", "error"] }] */
import { useAlert } from 'dashboard/composables';
import {
  DuplicateContactException,
  ExceptionWithMessage,
} from 'shared/helpers/CustomErrors';
import { useVuelidate } from '@vuelidate/core';
import { required, email } from '@vuelidate/validators';
import countries from 'shared/constants/countries.js';
import { isPhoneNumberValid } from 'shared/helpers/Validators';
import parsePhoneNumber from 'libphonenumber-js';

import AddOrganization from './AddOrganization.vue';
import ContactDetailsItem from '../ContactDetailsItem.vue';
import Synchronizer from './Synchronizer';

export default {
  components: {
    ContactDetailsItem,
    AddOrganization,
  },
  mixins: [Synchronizer],
  props: {
    contact: {
      type: Object,
      default: () => ({}),
    },
    crmContact: {
      type: Object,
      default: () => ({}),
    },
    inProgress: {
      type: Boolean,
      default: false,
    },
    onSubmit: {
      type: Function,
      default: () => { },
    },
    isIntegrationEnabled: {
      type: Boolean,
      default: false
    }
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      showContactDetails: true,
      readonlyOrganization: true,
      isAddContact: false,
      isEditContact: false,

      countries: countries,
      companyName: '',
      description: '',
      email: '',
      name: '',
      phoneNumber: '',
      activeDialCode: '',
      avatarFile: null,
      avatarUrl: '',
      country: {
        id: '',
        name: '',
      },
      city: '',
      socialProfileUserNames: {
        facebook: '',
        twitter: '',
        linkedin: '',
        github: '',
        instagram: '',
        line: '',
        telegram: '',
        website: '',
      },
      socialProfileKeys: [
        { key: 'facebook', label: 'https://facebook.com/' },
        { key: 'twitter', label: 'https://twitter.com/' },
        { key: 'linkedin', label: 'https://linkedin.com/' },
        { key: 'github', label: 'https://github.com/' },
        { key: 'instagram', label: 'https://instagram.com/' },
        { key: 'line', label: 'Line User Id ' },
        { key: 'telegram', label: 'Telegram Username ' },
        { key: 'website', label: 'Website: https://' },
      ],
      showOrganizationModal: false,
      id_company: 0,
      id_contact: 0,
      id_contact_type: 0,
      id_contact_email: 0,
      preparedCustomAttributes: null,

      // 🆕 NUEVAS PROPIEDADES PARA CONTROLAR BÚSQUEDAS
      isSearchingInCRMZeus: false,
      searchType: null, // 'phone' o 'email'
      showExistContactoModal: false,
      confirmExistContactoMessage: '',
    };
  },
  validations: {
    name: {
      required,
    },
    description: {},
    email: {
      email,
    },
    companyName: {},
    phoneNumber: {},
    bio: {},
  },
  computed: {
    parsePhoneNumber() {
      return parsePhoneNumber(this.phoneNumber);
    },
    isPhoneNumberNotValid() {
      if (this.phoneNumber !== '') {
        return (
          !isPhoneNumberValid(this.phoneNumber, this.activeDialCode) ||
          (this.phoneNumber !== '' ? this.activeDialCode === '' : false)
        );
      }
      return false;
    },
    phoneNumberError() {
      if (this.activeDialCode === '') {
        return this.$t('CONTACT_FORM.FORM.PHONE_NUMBER.DIAL_CODE_ERROR');
      }
      if (!isPhoneNumberValid(this.phoneNumber, this.activeDialCode)) {
        return this.$t('CONTACT_FORM.FORM.PHONE_NUMBER.ERROR');
      }
      return this.$t('CONTACT_FORM.FORM.PHONE_NUMBER.NO_ERROR');
    },
    setPhoneNumber() {
      if (this.parsePhoneNumber && this.parsePhoneNumber.countryCallingCode) {
        return this.phoneNumber;
      }
      if (this.phoneNumber === '' && this.activeDialCode !== '') {
        return '';
      }
      return this.activeDialCode
        ? `${this.activeDialCode}${this.phoneNumber}`
        : '';
    },
    isContactEmpty() {
      return Object.keys(this.contact).length === 0;
    },
    integration() {
      return this.$store.getters['integrations/getIntegration']('crmzeus');
    },

    // 🔍 Verificar si contacto existente está sincronizado
    isSynchronized() {
      const { custom_attributes = {} } = this.contact || {};
      const { idcontacto_crmzeus = 0, idorganizacion_crmzeus = 0 } = custom_attributes;
      return idcontacto_crmzeus > 0 && idorganizacion_crmzeus > 0;
    },

    // 🔍 Detectar si encontramos contacto en CRMZeus durante búsqueda
    isFoundInCRMZeus() {
      return this.id_contact > 0 && this.id_company > 0;
    },

    // 🎯 LÓGICA ÚNICA PARA MOSTRAR BOTONES
    shouldShowOrganizationButtons() {
      console.log("🔍 Evaluando shouldShowOrganizationButtons:", {
        isEditContact: this.isEditContact,
        isSynchronized: this.isSynchronized,
        isFoundInCRMZeus: this.isFoundInCRMZeus,
        id_contact: this.id_contact,
        id_company: this.id_company
      });

      return !this.isEditContact &&      // No en modo edición
        !this.isSynchronized &&     // No sincronizado previamente
        !this.isFoundInCRMZeus &&
        this.isIntegrationEnabled;     // No encontrado en búsqueda actual
    },

    // isSubmitDisabled() {
    //   const basicValidations = {
    //     nameValid: !this.v$.name.$error && this.name.trim() !== '',
    //     emailValid:
    //       this.email === '' ||
    //       (!this.v$.email.$error && this.email.includes('@')),
    //     phoneValid: this.phoneNumber === '' || !this.isPhoneNumberNotValid,
    //     contactInfoPresent:
    //       this.email.trim() !== '' || this.phoneNumber.trim() !== '',
    //   };

    //   const crmZeusValidations = this.integration?.enabled
    //     ? {
    //       companyValid: this.companyName.trim() !== '',
    //     }
    //     : {};

    //   const allValidations = {
    //     ...basicValidations,
    //     ...crmZeusValidations,
    //   };

    //   return Object.values(allValidations).some(valid => !valid);
    // },

    isSubmitDisabled() {
      const basicValidations = {
        // Nombre es requerido y no puede estar vacío
        nameValid: !this.v$.name.$error && this.name.trim() !== '',

        // Email: si está presente, debe ser válido
        // emailValid: this.email.trim() === '' || (!this.v$.email.$error && this.email.includes('@')),
        // emailValid: this.email.trim() === '' || (!this.v$.email.$error && this.isValidEmail(this.email)),
        // emailValid: this.email.trim() !== '' || (!this.v$.email.$error),
        emailValid: this.email.trim() !== '' && !this.v$.email.$error,

        // Teléfono: OBLIGATORIO y debe ser válido
        phoneValid: this.phoneNumber.trim() !== '' && !this.isPhoneNumberNotValid,

        // Mantener esta validación por si acaso (aunque phoneValid ya lo cubre)
        contactInfoPresent: this.email.trim() !== '' || this.phoneNumber.trim() !== '',
      };

      // Si la integración CRM está habilitada, companyName es requerido
      const crmZeusValidations = this.integration?.enabled
        ? {
          companyValid: this.companyName.trim() !== '',
        }
        : {};

      const allValidations = {
        ...basicValidations,
        ...crmZeusValidations,
      };

      // Retorna true (deshabilitar) si alguna validación falla
      return Object.values(allValidations).some(valid => !valid);
    },
    statusEditContact() {
      return (Object.keys(this.crmContact).length > 0);
    }
  },

  // 🔥 WATCHERS MODIFICADOS PARA MOSTRAR ALERTAS
  watch: {
    contact() {
      this.setContactObject();
    },

    // 🔥 WATCHER MODIFICADO PARA id_contact
    id_contact(newVal, oldVal) {
      console.log("🔍 id_contact cambió:", { antes: oldVal, ahora: newVal });

      // Si estábamos buscando y encontramos un contacto
      if (this.isSearchingInCRMZeus && newVal > 0 && oldVal === 0) {
        console.log("✅ Contacto encontrado en CRMZeus via watcher!");
        useAlert('✅ ¡Contacto encontrado en CRMZeus! Datos cargados automáticamente');
        this.isSearchingInCRMZeus = false; // Reset flag
        this.searchType = null;
      }

      if (newVal > 0) {
        console.log("✅ Contacto encontrado en CRMZeus, actualizando UI...");
        this.$forceUpdate();
      }
    },

    // 🔥 WATCHER MODIFICADO PARA id_company  
    id_company(newVal, oldVal) {
      console.log("🔍 id_company cambió:", { antes: oldVal, ahora: newVal });

      // Si estábamos buscando y encontramos una empresa
      if (this.isSearchingInCRMZeus && newVal > 0 && oldVal === 0) {
        console.log("✅ Organización encontrada en CRMZeus via watcher!");
        // No mostrar alert aquí si ya se mostró en id_contact
      }

      if (newVal > 0) {
        console.log("✅ Organización encontrada en CRMZeus, actualizando UI...");
        this.readonlyOrganization = true;
        this.$forceUpdate();
      }
    },

    // 🆕 NUEVO WATCHER PARA DETECTAR CUANDO LA BÚSQUEDA NO ENCUENTRA NADA
    isSearchingInCRMZeus(newVal, oldVal) {
      if (oldVal === true && newVal === false) {
        // La búsqueda terminó, verificar si encontró algo
        setTimeout(() => {
          if (this.id_contact === 0 && this.id_company === 0) {
            console.log("❌ Búsqueda terminó sin resultados");
            useAlert('❌ Contacto no encontrado en CRMZeus');
          }
        }, 200); // Pequeño delay para asegurar que los watchers se ejecuten
      }
    }
  },

  mounted() {
    this.setContactObject();
    this.setDialCode();
  },

  methods: {
    isValidEmail(email) {
      if (!email || email.trim() === '') return true; // Email vacío es válido
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      return emailRegex.test(email.trim());
    },
    onCancel() {
      this.$emit('cancel');
    },
    onSuccess() {
      this.$emit('success');
    },
    countryNameWithCode({ name, id }) {
      if (!id) return name;
      if (!name && !id) return '';
      return `${name} (${id})`;
    },
    setDialCode() {
      if (
        this.phoneNumber !== '' &&
        this.parsePhoneNumber &&
        this.parsePhoneNumber.countryCallingCode
      ) {
        const dialCode = this.parsePhoneNumber.countryCallingCode;
        this.activeDialCode = `+${dialCode}`;
      }
    },

    setContactObject() {

      console.log("setContactObject <setContactObject>", this.crmContact)
      this.isAddContact = Object.keys(this.contact).length === 0;
      this.isEditContact = Object.keys(this.crmContact).length > 0;
      const { name,
        email: emailAddress,
        phone_number: phoneNumber
      } = this.contact

      const contact =
        Object.keys(this.crmContact).length > 0
          ? this.crmContact
          : this.contact;
      const {
        // name,
        // email: emailAddress,
        // phone_number: phoneNumber,
        companyName,
        id_company = contact.id_company || 0,
        id_contact = contact.id_contact || 0,
        id_contact_type = contact.id_contact_type || 0,
        id_contact_email = contact.id_contact_email || 0,
      } = contact;

      console.log("setContactObject <this.contact> ******", this.contact)
      const additionalAttributes = this.contact.additional_attributes || {};
      this.id_company = id_company || 0;
      this.id_contact = id_contact || 0;
      this.id_contact_type = id_contact_type || 0;
      this.id_contact_email = id_contact_email;
      this.name = name || '';
      this.email = emailAddress || '';
      this.phoneNumber = phoneNumber
        ? phoneNumber.startsWith('+')
          ? phoneNumber
          : `+${phoneNumber}`
        : '';
      this.companyName = additionalAttributes.company_name || companyName || '';
      this.country = {
        id: additionalAttributes.country_code || '',
        name:
          additionalAttributes.country ||
          this.$t('CONTACT_FORM.FORM.COUNTRY.SELECT_COUNTRY'),
      };
      this.city = additionalAttributes.city || '';
      this.description = additionalAttributes.description || '';
      this.avatarUrl = this.contact.thumbnail || '';
      const {
        social_profiles: socialProfiles = {},
        screen_name: twitterScreenName,
      } = additionalAttributes;
      this.socialProfileUserNames = {
        twitter: socialProfiles.twitter || twitterScreenName || '',
        facebook: socialProfiles.facebook || '',
        linkedin: socialProfiles.linkedin || '',
        github: socialProfiles.github || '',
        instagram: socialProfiles.instagram || '',
        line: socialProfiles.line || '',
        telegram: socialProfiles.telegram || '',
        website: socialProfiles.website || '',
      };
    },

    getContactObject() {
      if (this.country === null) {
        this.country = {
          id: '',
          name: '',
        };
      }

      const contactObject = {
        id: this.contact.id,
        name: this.name,
        email: this.email,
        phone_number: this.setPhoneNumber,
        id_company: this.id_company || 0,
        id_contact: this.id_contact || 0,
        id_contact_type: this.id_contact_type || 0,
        id_contact_email: this.id_contact_email,
        additional_attributes: {
          ...this.contact.additional_attributes,
          description: this.description,
          company_name: this.companyName,
          country_code: this.country.id,
          country:
            this.country.name ===
              this.$t('CONTACT_FORM.FORM.COUNTRY.SELECT_COUNTRY')
              ? ''
              : this.country.name,
          city: this.city,
          social_profiles: this.socialProfileUserNames,
        },
        custom_attributes: {
          idcontacto_crmzeus: this.id_contact || 0,
          idorganizacion_crmzeus: this.id_company || 0,
        }
      };

      return contactObject;
    },

    resetPreparedCustomAttributes() {
      this.preparedCustomAttributes = null;
      console.log("🧹 Custom attributes preparados limpiados");
    },

    onPhoneNumberInputChange(value, code) {
      this.activeDialCode = code;
    },

    setPhoneCode(code) {
      if (this.phoneNumber !== '' && this.parsePhoneNumber) {
        const dialCode = this.parsePhoneNumber.countryCallingCode;
        if (dialCode === code) {
          return;
        }
        this.activeDialCode = `+${dialCode}`;
        const newPhoneNumber = this.phoneNumber.replace(
          `+${dialCode}`,
          `${code}`
        );
        this.phoneNumber = newPhoneNumber;
      } else {
        this.activeDialCode = code;
      }
    },

    async handleSubmit() {
      this.v$.$touch();
      if (this.v$.$invalid || this.isPhoneNumberNotValid) {
        return;
      }
      try {
        await this.onSubmit(this.getContactObject());
        this.onSuccess();
        useAlert(this.$t('CONTACT_FORM.SUCCESS_MESSAGE'));

      } catch (error) {
        if (error instanceof DuplicateContactException) {
          if (error.data.includes('email')) {
            useAlert(this.$t('CONTACT_FORM.FORM.EMAIL_ADDRESS.DUPLICATE'));
            // this.confirmExistContactoMessage = this.$t('CONTACT_FORM.FORM.EMAIL_ADDRESS.DUPLICATE');
          } else if (error.data.includes('phone_number')) {
            useAlert(this.$t('CONTACT_FORM.FORM.PHONE_NUMBER.DUPLICATE'));
            // this.confirmExistContactoMessage = this.$t('CONTACT_FORM.FORM.PHONE_NUMBER.DUPLICATE');
          }
          return;
        } else if (error instanceof ExceptionWithMessage) {
          useAlert(error.data);
        } else {
          useAlert(this.$t('CONTACT_FORM.ERROR_MESSAGE'));
        }
      }
    },

    toggleAddOrganization() {
      this.companyName = '';
      this.id_company = 0;
      this.readonlyOrganization = false;
    },

    toogleOrganizationModal() {
      this.readonlyOrganization = true;
      this.showOrganizationModal = !this.showOrganizationModal;
    },

    closeExistContacto() {
      this.showExistContactoModal = false;
    },

    handleImageUpload({ file, url }) {
      this.avatarFile = file;
      this.avatarUrl = url;
    },

    async handleAvatarDelete() {
      try {
        if (this.contact && this.contact.id) {
          await this.$store.dispatch('contacts/deleteAvatar', this.contact.id);
          useAlert(this.$t('CONTACT_FORM.DELETE_AVATAR.API.SUCCESS_MESSAGE'));
        }
        this.avatarFile = null;
        this.avatarUrl = '';
        this.activeDialCode = '';
      } catch (error) {
        useAlert(
          error.message
            ? error.message
            : this.$t('CONTACT_FORM.DELETE_AVATAR.API.ERROR_MESSAGE')
        );
      }
    },

    onSelected(data) {
      const { CLIENTE_ID, NOMBRE_COMERCIAL } = data;
      this.companyName = NOMBRE_COMERCIAL;
      this.id_company = CLIENTE_ID;
      console.log("this.id_company", this.id_company)
      this.showOrganizationModal = false;
    },

    onClose() {
      this.showOrganizationModal = false;
    },

    // 🔄 MÉTODOS SIMPLIFICADOS PARA BÚSQUEDA EN CRMZEUS
    async handlePhoneEnterSearch(event) {
      event.preventDefault();
      event.stopPropagation();

      console.log('🔍 Enter presionado en campo teléfono - Búsqueda CRM');

      if (!this.isIntegrationEnabled) {
        // useAlert('❌ Integración CRMZeus no disponible');
        return;
      }

      if (!this.phoneNumber || this.isPhoneNumberNotValid) {
        useAlert('❌ Número de teléfono inválido para búsqueda');
        return;
      }

      if (this.isAddContact || !this.isSynchronized) {
        // 🔥 MARCAR QUE ESTAMOS BUSCANDO
        this.isSearchingInCRMZeus = true;
        this.searchType = 'phone';

        useAlert('🔍 Buscando contacto por teléfono en CRMZeus...');

        try {
          await this.handlePhoneEnter();

          // 🔥 TIMEOUT PARA DETECTAR SI NO SE ENCONTRÓ NADA
          setTimeout(() => {
            if (this.isSearchingInCRMZeus) {
              // Si después de 2 segundos seguimos buscando, significa que no se encontró
              this.isSearchingInCRMZeus = false;
              this.searchType = null;
            }
          }, 2000);

        } catch (error) {
          console.error('❌ Error en búsqueda CRMZeus:', error);
          useAlert('❌ Error al buscar en CRMZeus');
          this.isSearchingInCRMZeus = false;
          this.searchType = null;
        }
      } else {
        useAlert('ℹ️ Contacto ya sincronizado');
      }
    },

    async handleEmailEnterSearch(event) {
      event.preventDefault();
      event.stopPropagation();

      console.log('🔍 Enter presionado en campo email - Búsqueda CRM');

      if (!this.isIntegrationEnabled) {
        // useAlert('❌ Integración CRMZeus no disponible');
        return;
      }

      if (!this.email || this.v$.email.$error) {
        useAlert('❌ Email inválido para búsqueda');
        return;
      }

      if (this.isAddContact || !this.isSynchronized) {
        // 🔥 MARCAR QUE ESTAMOS BUSCANDO
        this.isSearchingInCRMZeus = true;
        this.searchType = 'email';

        useAlert('🔍 Buscando contacto por email en CRMZeus...');

        try {
          await this.handlePhoneEmail();

          // 🔥 TIMEOUT PARA DETECTAR SI NO SE ENCONTRÓ NADA
          setTimeout(() => {
            if (this.isSearchingInCRMZeus) {
              // Si después de 2 segundos seguimos buscando, significa que no se encontró
              this.isSearchingInCRMZeus = false;
              this.searchType = null;
            }
          }, 2000);

        } catch (error) {
          console.error('❌ Error en búsqueda CRMZeus:', error);
          useAlert('❌ Error al buscar en CRMZeus');
          this.isSearchingInCRMZeus = false;
          this.searchType = null;
        }
      } else {
        useAlert('ℹ️ Contacto ya sincronizado');
      }
    },

    // Prevenir Enter en otros campos
    preventFormSubmitOnEnter(event) {
      if (event.key === 'Enter') {
        event.preventDefault();
        event.stopPropagation();
        console.log('🚫 Enter bloqueado en campo:', event.target.name || 'unnamed');
      }
    },
  },
};
</script>

<template>
  <div>
    <form class="w-full px-8 pt-6 pb-8 contact--form" @submit.prevent="handleSubmit">
      <div class="w-full">
        <woot-avatar-uploader :label="$t('CONTACT_FORM.FORM.AVATAR.LABEL')" :src="avatarUrl" :username-avatar="name"
          :delete-avatar="!!avatarUrl" class="settings-item" @change="handleImageUpload"
          @onAvatarDelete="handleAvatarDelete" />
      </div>

      <div class="w-full">
        <label :class="{ error: v$.name.$error }">
          {{ $t('CONTACT_FORM.FORM.NAME.LABEL') }}
          <input v-model.trim="name" type="text" :placeholder="$t('CONTACT_FORM.FORM.NAME.PLACEHOLDER')"
            @input="v$.name.$touch" @keydown.enter.prevent.stop="console.log('Enter bloqueado en campo nombre')" />
        </label>
      </div>

      <div>
        <div class="w-full">
          <label :class="{ error: isPhoneNumberNotValid }">
            {{ $t('CONTACT_FORM.FORM.PHONE_NUMBER.LABEL') }}
            <woot-phone-input v-model="phoneNumber" :value="phoneNumber" :error="isPhoneNumberNotValid"
              :placeholder="$t('CONTACT_FORM.FORM.PHONE_NUMBER.PLACEHOLDER')" @input="onPhoneNumberInputChange"
              @setCode="setPhoneCode" @keydown.enter.native.prevent.stop="handlePhoneEnterSearch" />
            <span v-if="isPhoneNumberNotValid" class="message">
              {{ phoneNumberError }}
            </span>
          </label>
          <div v-if="isPhoneNumberNotValid || !phoneNumber"
            class="relative mx-0 mt-0 mb-2.5 p-2 rounded-md text-sm border border-solid border-yellow-500 text-yellow-700 dark:border-yellow-700 bg-yellow-200/60 dark:bg-yellow-200/20 dark:text-yellow-400">
            {{ $t('CONTACT_FORM.FORM.PHONE_NUMBER.HELP') }}
          </div>
          <!-- Ayuda para búsqueda -->
          <div v-if="isAddContact && phoneNumber && !isPhoneNumberNotValid && isIntegrationEnabled"
            class="relative mx-0 mt-0 mb-2.5 p-2 rounded-md text-sm border border-solid border-blue-500 text-blue-700 dark:border-blue-700 bg-blue-200/60 dark:bg-blue-200/20 dark:text-blue-400">
            💡 Presione <kbd class="px-1 py-0.5 text-xs bg-blue-300/50 rounded">Enter</kbd> para buscar contacto en
            CRMZeus
          </div>
        </div>
      </div>

      <div class="w-full">
        <label :class="{ error: v$.email.$error }">
          {{ $t('CONTACT_FORM.FORM.EMAIL_ADDRESS.LABEL') }}
          <input v-model.trim="email" type="text" :placeholder="$t('CONTACT_FORM.FORM.EMAIL_ADDRESS.PLACEHOLDER')"
            @input="v$.email.$touch" @keydown.enter.prevent.stop="handleEmailEnterSearch" />
          <span v-if="v$.email.$error" class="message">
            {{ $t('CONTACT_FORM.FORM.EMAIL_ADDRESS.ERROR') }}
          </span>
        </label>
        <!-- Ayuda para búsqueda -->
        <div v-if="isAddContact && email && !v$.email.$error && isIntegrationEnabled"
          class="relative mx-0 mt-0 mb-2.5 p-2 rounded-md text-sm border border-solid border-blue-500 text-blue-700 dark:border-blue-700 bg-blue-200/60 dark:bg-blue-200/20 dark:text-blue-400">
          💡 Presione <kbd class="px-1 py-0.5 text-xs bg-blue-300/50 rounded">Enter</kbd> para buscar contacto en
          CRMZeus
        </div>
      </div>

      <div class="w-full">
        <!-- 🎯 SECCIÓN DE ORGANIZACIÓN LIMPIA Y ÚNICA -->
        <ContactDetailsItem compact title="Organización">
          <template v-if="shouldShowOrganizationButtons" #button>
            <woot-button icon="add" variant="link" size="small" @click.prevent="toggleAddOrganization">
              Agregar
            </woot-button>
            <woot-button icon="filter" variant="link" size="small" @click.prevent="toogleOrganizationModal">
              Buscar
            </woot-button>
          </template>
        </ContactDetailsItem>

        <!-- Campo de compañía -->
        <!--
          proyecto@organization_field: :readonly y :is-disabled comentados a propósito
          para que el campo companyName sea siempre editable.
          Original:
          :readonly="isEditContact || isFoundInCRMZeus || readonlyOrganization || isSynchronized"
          :is-disabled="isSynchronized"
        -->
        <woot-input v-model.trim="companyName" class="columns-ajuste"
          :placeholder="$t('CONTACT_FORM.FORM.COMPANY_NAME.PLACEHOLDER')" />
        <div v-if="isIntegrationEnabled"
          class="relative mx-0 mt-0 mb-2.5 p-2 rounded-md text-sm border border-solid border-blue-500 text-blue-700 dark:border-blue-700 bg-blue-200/60 dark:bg-blue-200/20 dark:text-blue-400">
          💡 Nueva organización: <kbd class="px-1 py-0.5 text-xs bg-blue-300/50 rounded">Agregar</kbd>. Organización existente: <kbd class="px-1 py-0.5 text-xs bg-blue-300/50 rounded">Buscar</kbd>.
        </div>
      </div>

      <div>
        <div class="w-full">
          <label>
            {{ $t('CONTACT_FORM.FORM.COUNTRY.LABEL') }}
          </label>
          <multiselect v-model="country" track-by="id" label="name"
            :placeholder="$t('CONTACT_FORM.FORM.COUNTRY.PLACEHOLDER')" selected-label
            :select-label="$t('CONTACT_FORM.FORM.COUNTRY.SELECT_PLACEHOLDER')"
            :deselect-label="$t('CONTACT_FORM.FORM.COUNTRY.REMOVE')" :custom-label="countryNameWithCode"
            :max-height="160" :options="countries" allow-empty :option-height="104" />
        </div>
      </div>

      <woot-input v-model="city" class="w-full" :label="$t('CONTACT_FORM.FORM.CITY.LABEL')"
        :placeholder="$t('CONTACT_FORM.FORM.CITY.PLACEHOLDER')"
        @keydown.enter.prevent.stop="console.log('Enter bloqueado en campo ciudad')" />

      <div class="w-full">
        <label :class="{ error: v$.description.$error }">
          {{ $t('CONTACT_FORM.FORM.BIO.LABEL') }}
          <textarea v-model.trim="description" type="text" :placeholder="$t('CONTACT_FORM.FORM.BIO.PLACEHOLDER')"
            @input="v$.description.$touch" />
        </label>
      </div>

      <div class="w-full">
        <label>{{ $t('CONTACTS_PAGE.LIST.TABLE_HEADER.SOCIAL_PROFILES') }}</label>
        <div v-for="socialProfile in socialProfileKeys" :key="socialProfile.key" class="flex items-stretch w-full mb-4">
          <span
            class="flex items-center h-10 px-2 text-sm border-solid bg-slate-50 border-y ltr:border-l rtl:border-r ltr:rounded-l-md rtl:rounded-r-md dark:bg-slate-700 text-slate-800 dark:text-slate-100 border-slate-200 dark:border-slate-600">
            {{ socialProfile.label }}
          </span>
          <input v-model="socialProfileUserNames[socialProfile.key]"
            class="input-group-field ltr:!rounded-l-none rtl:rounded-r-none !mb-0" type="text"
            @keydown.enter.prevent.stop="console.log('Enter bloqueado en campo social:', socialProfile.key)" />
        </div>
      </div>

      <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
        <div class="w-full">
          <woot-submit-button :loading="inProgress" :button-text="$t('CONTACT_FORM.FORM.SUBMIT')"
            :disabled="isSubmitDisabled && isIntegrationEnabled" />
          <button class="button clear" @click.prevent="onCancel">
            {{ $t('CONTACT_FORM.FORM.CANCEL') }}
          </button>
        </div>
      </div>
    </form>

    <AddOrganization :show-organization="showOrganizationModal" :contact="contact"
      @close="showOrganizationModal = false" :on-selected="onSelected" @cancel="toogleOrganizationModal"
      :integration="integration" />

    <!-- No se utiliza para borrar solo cono notificacion  -->
    <!-- <woot-delete-modal class="contact-existence-modal" v-if="showExistContactoModal" :show.sync="showExistContactoModal" :on-close="closeExistContacto"
      title="Existencia de contacto (Wintook)..." :message="confirmExistContactoMessage" confirm-text="Aceptar"
      :on-confirm="closeExistContacto" /> -->

    <!-- <woot-modal :show.sync="showExistContactoModal" :on-close="closeExistContacto" :size="medium">
      {{ confirmExistContactoMessage }}
    </woot-modal> -->
  </div>
</template>

<style scoped lang="scss">
::v-deep {
  .multiselect .multiselect__tags .multiselect__single {
    @apply pl-0;
  }
}

kbd {
  font-family: ui-monospace, SFMono-Regular, "SF Mono", monospace;
  font-weight: 600;
}
</style>