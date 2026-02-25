<!-- DEV0002 -->
<!-- app/javascript/dashboard/routes/dashboard/conversation/contact/CreateContact.vue -->
<!-- <script>
import { mapGetters } from 'vuex';
import ContactForm from './ContactForm.vue';
import Synchronizer from './Synchronizer';

export default {
  components: {
    ContactForm,
  },
  mixins: [Synchronizer],
  props: {
    show: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      contactFoundInCrm: false,
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'contacts/getUIFlags',
    }),
  },
  methods: {
    onCancel() {
      this.$emit('cancel');
    },
    onSuccess() {
      this.$emit('cancel');
    },
    async onSubmit(contactItem) {
      try {
        console.log("Creando nuevo contacto en Chatwoot...");
        const resultContact = await this.$store.dispatch('contacts/create', contactItem);
        
        const { id_company, id_contact, id: id_wcontact = 0 } = contactItem;
        const dataContact = { ...resultContact, id_company, id_contact, id_wcontact };
        
        console.log("Contacto creado, iniciando sincronización con CRMZeus...");
        await this.setContactCRM(dataContact);
        
        console.log("Proceso completado exitosamente");
      } catch (error) {
        console.error('Error al crear contacto:', error);
        throw error;
      }
    },
  },
  // Resetear estado cuando se muestra el modal
  watch: {
    show(newValue) {
      if (newValue) {
        this.contactFoundInCrm = false;
        // Resetear controles de búsqueda
        this.hasSearchedByPhone = false;
        this.hasSearchedByEmail = false;
      }
    }
  }
};
</script> -->

<script>
import { mapGetters } from 'vuex';
import ContactForm from './ContactForm.vue';
import Synchronizer from './Synchronizer';
import MessageContactModal from './MessageContactModal.vue'; // ← Importar el modal mejorado

export default {
  components: {
    ContactForm,
    MessageContactModal, // ← Registrar componente
  },
  mixins: [Synchronizer],
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    isIntegrationEnabled: {
      type: Boolean,
      default: false
    }
  },

  data() {
    return {
      contact: {
        name: '',
        email: '',
        additional_attributes : {
          company_name: ''
        }
      },
      showEmailExistsModal: false,
      isProcessing: false,
      shouldShowSuccess: false,
      showExistsContactModal: false,
    };
  },

  computed: {
    ...mapGetters({
      uiFlags: 'contacts/getUIFlags',
    }),
    // ← Mensaje dinámico para el modal
    emailExistsMessage() {
      return `El correo electrónico ${this.contact.email} del contacto ${this.contact.name} ya existe en la organización ${this.contact.additional_attributes.company_name}.`;
    },
    // emailExistsMessage() {
    //   return `El correo electrónico `;
    // },
  },

  methods: {
    onCancel() {
      this.$emit('cancel');
    },
    onSuccess() {
      this.$emit('cancel');
    },

    // ← Método actualizado para usar el modal mejorado
    onEmailExistsAccept() {
      console.log('✅ Usuario decidió continuar con email existente');
      this.closeEmailExistsModal();

      // TODO: Implementar lógica para continuar con el proceso
      // this.continueWithDuplicateEmail = true;
      // this.continueSubmit();
    },

    // ← Método para cancelar desde el modal
    onEmailExistsCancel() {
      console.log('❌ Usuario canceló la actualización');
      this.closeEmailExistsModal();
    },

    // ← Método para cerrar el modal (X o backdrop)
    onEmailExistsClose() {
      console.log('🔄 Usuario cerró el modal de email existente');
      this.closeEmailExistsModal();
    },

    closeEmailExistsModal() {
      this.showEmailExistsModal = false;
      this.isProcessing = false;
      this.shouldShowSuccess = false;
      console.log('🔄 Modal cerrado, proceso terminado');
    },

    // ← Método deprecado - ya no se necesita
    confirmEmailExists() {
      console.log(
        '⚠️ Método deprecado: confirmEmailExists. Usar onEmailExistsAccept'
      );
      this.onEmailExistsAccept();
    },

    // ← Método deprecado - ya no se necesita
    confirmEmailExistsMessage() {
      console.log(
        '⚠️ Método deprecado: confirmEmailExistsMessage. Usar computed emailExistsMessage'
      );
      return this.emailExistsMessage;
    },

    async onSubmit(contactItem) {
      this.contact = contactItem;
      if (this.isProcessing) {
        console.log('🛑 Proceso ya en curso, ignorando nueva ejecución');
        return false;
      }

      this.isProcessing = true;
      console.log('🚀 Iniciando proceso de actualización...');

      try {

        // const checkUpdatingEmail = await this.checkBeforeUpdatingEmail(contactItem);

        // if (checkUpdatingEmail) {
        //   console.log('🔍 Email exists, showing modal...');
        //   this.showEmailExistsModal = true;
        //   this.shouldShowSuccess = false;

        //   this.$emit('suppress-alerts', true);
        //   useAlert('🔍 Email exists, showing modal...');

        //   await this.$nextTick();
        //   console.log('After nextTick - Modal state:', this.showEmailExistsModal);

        //   return false;
        // } else {
        //   console.log('✅ Email no existe, continuando con el proceso...');
        // }



        const newContact = await this.$store.dispatch(
          'contacts/create',
          contactItem
        );
        console.log('Contacto creado en Chatwoot <contactItem>:', contactItem);

        // Preparar datos para sincronización con CRMZeus
        const { id: id_wcontact = 0 } = newContact;
        const { id_company, id_contact } = contactItem;
        const dataContact = {
          ...contactItem,
          id_company,
          id_contact,
          id_wcontact,
          // id_contact_type, id_contact_email
        };

        console.log('Iniciando sincronización con CRMZeus...');

        // 🔥 CLAVE: isNewContact = true
        await this.setContactCRM(dataContact, true);
      } catch (error) {
        console.error('❌ Error en EditContact onSubmit:', error);
        if (!this.showEmailExistsModal) {
          this.isProcessing = false;
          this.shouldShowSuccess = false;
        }
        throw error;
      }

      this.isProcessing = false;
      console.log('🔄 Proceso completado exitosamente');
    },
  },
};
</script>
<!-- eslint-disable vue/no-mutating-props -->
<template>
  <div>
    <MessageContactModal
      :show="showEmailExistsModal"
      :message="emailExistsMessage"
      title="Email ya existe"
      :showCancelButton="true"
      acceptButtonText="Continuar"
      cancelButtonText="Cancelar"
      @accept="onEmailExistsAccept"
      @cancel="onEmailExistsCancel"
      @close="onEmailExistsClose"
    />

    <woot-modal
      :show.sync="show"
      :on-close="onCancel"
      modal-type="right-aligned"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="$t('CREATE_CONTACT.TITLE')"
          :header-content="$t('CREATE_CONTACT.DESC')"
        />
        <ContactForm
          :in-progress="uiFlags.isCreating"
          :on-submit="onSubmit"
          @success="onSuccess"
          @cancel="onCancel"
          :is-integration-enabled="isIntegrationEnabled"
        />
      </div>
    </woot-modal>
  </div>
</template>