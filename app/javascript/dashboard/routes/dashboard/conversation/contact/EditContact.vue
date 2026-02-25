<!-- DEV0002 -->
<script>
import { mapGetters } from 'vuex';
import ContactForm from './ContactForm.vue';
import Synchronizer from './Synchronizer';
import { useAlert } from 'dashboard/composables';
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
    contact: {
      type: Object,
      default: () => ({}),
    },
    crmContact: {
      type: Object,
      default: () => ({}),
    },
    isIntegrationEnabled: {
      type: Boolean,
      default: false
    }
  },
  data() {
    return {
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
      return `El correo electrónico ${ this.contact.email } del contacto ${ this.contact.name } ya existe en la organización ${ this.contact.additional_attributes.company_name }.`;
    },
  },

  watch: {
    show(newValue) {
      if (!newValue && this.showEmailExistsModal) {
        console.log('🚫 Previniendo cierre del modal principal via watcher');
        this.$nextTick(() => {
          this.$emit('update:show', true);
        });
      }
    }
  },

  methods: {
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
      console.log('⚠️ Método deprecado: confirmEmailExists. Usar onEmailExistsAccept');
      this.onEmailExistsAccept();
    },

    // ← Método deprecado - ya no se necesita
    confirmEmailExistsMessage() {
      console.log('⚠️ Método deprecado: confirmEmailExistsMessage. Usar computed emailExistsMessage');
      return this.emailExistsMessage;
    },

    onCancel() {
      if (this.showEmailExistsModal) {
        console.log('🚫 No se puede cerrar el modal principal, hay un modal de email abierto');
        return;
      }

      this.isProcessing = false;
      this.$emit('cancel');
    },

    onSuccess() {
      if (this.showEmailExistsModal) {
        console.log('🚫 No se puede procesar éxito, hay un modal de email abierto');
        return;
      }

      if (this.shouldShowSuccess) {
        console.log('✅ Mostrando mensaje de éxito');
        this.shouldShowSuccess = false;
      } else {
        console.log('🚫 Bloqueando mensaje de éxito - proceso no completado');
        this.$emit('suppress-alerts', true);
        return;
      }

      this.isProcessing = false;
      this.$emit('cancel');
    },

    handleModalClose() {
      if (this.showEmailExistsModal) {
        console.log('🚫 Bloqueando cierre del modal principal - hay modal de email abierto');
        return false;
      }

      this.onCancel();
    },

    async onSubmit(contactItem) {

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

        const result = await this.$store.dispatch('contacts/update', contactItem);
        await this.$store.dispatch(
          'contacts/fetchContactableInbox',
          this.contact.id
        );
        console.log("result >>???????", result);

        this.shouldShowSuccess = true;
        this.$emit('suppress-alerts', true);

        console.log('✅ Contacto actualizado en Chatwoot, iniciando sincronización con CRMZeus...');

        const { id: id_wcontact = 0 } = contactItem;
        const { id_company, id_contact } = contactItem;
        const dataContact = {
          ...contactItem,
          id_company,
          id_contact,
          id_wcontact,
        };

        await this.setContactCRM(dataContact, false);
        console.log('✅ Proceso de edición completado exitosamente');

        this.shouldShowSuccess = true;

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

<template>
  <div>
    <!-- ✅ Modal mejorado con Tailwind -->
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

    <!-- Modal principal del componente -->
    <woot-modal 
      :show.sync="show" 
      :on-close="handleModalClose" 
      modal-type="right-aligned"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header 
          :header-title="`${$t('EDIT_CONTACT.TITLE')} - ${contact.name || contact.email}`"
          :header-content="$t('EDIT_CONTACT.DESC')" 
        />
        <ContactForm 
          :contact="contact" 
          :in-progress="uiFlags.isUpdating || isProcessing" 
          :crm-contact="crmContact"
          :on-submit="onSubmit" 
          @success="onSuccess" 
          @cancel="onCancel" 
          :disabled="showEmailExistsModal" 
          :is-integration-enabled="isIntegrationEnabled"
        />
      </div>
    </woot-modal>
  </div>
</template>