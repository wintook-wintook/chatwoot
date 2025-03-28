<script>
import CustomButton from 'shared/components/Button.vue';
import Spinner from 'shared/components/Spinner.vue';
import { mapGetters } from 'vuex';
import { getContrastingTextColor } from '@chatwoot/utils';
import { isEmptyObject } from 'widget/helpers/utils';
import { getRegexp } from 'shared/helpers/Validators';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import routerMixin from 'widget/mixins/routerMixin';
import { useDarkMode } from 'widget/composables/useDarkMode';
import configMixin from 'widget/mixins/configMixin';

export default {
  components: {
    CustomButton,
    Spinner,
  },
  mixins: [routerMixin, configMixin],
  props: {
    options: {
      type: Object,
      default: () => {},
    },
  },
  setup() {
    const { formatMessage } = useMessageFormatter();
    const { getThemeClass } = useDarkMode();
    return { formatMessage, getThemeClass };
  },
  data() {
    return {
      locale: this.$root.$i18n.locale,
      hasErrorInPhoneInput: false,
      message: '',
      formValues: {},
      labels: {
        emailAddress: 'EMAIL_ADDRESS',
        fullName: 'FULL_NAME',
        phoneNumber: 'PHONE_NUMBER',
      },
    };
  },
  computed: {
    ...mapGetters({
      widgetColor: 'appConfig/getWidgetColor',
      isCreating: 'conversation/getIsCreating',
      activeCampaign: 'campaign/getActiveCampaign',
      currentUser: 'contacts/getCurrentUser',
    }),
    textColor() {
      return getContrastingTextColor(this.widgetColor);
    },
    hasActiveCampaign() {
      return !isEmptyObject(this.activeCampaign);
    },
    shouldShowHeaderMessage() {
      return this.hasActiveCampaign || this.preChatFormEnabled;
    },
    headerMessage() {
      if (this.preChatFormEnabled) {
        return this.options.preChatMessage;
      }
      if (this.hasActiveCampaign) {
        return this.$t('PRE_CHAT_FORM.CAMPAIGN_HEADER');
      }
      return '';
    },
    preChatFields() {
      return this.preChatFormEnabled ? this.options.preChatFields : [];
    },
    filteredPreChatFields() {
      const isUserEmailAvailable = this.currentUser.has_email;
      const isUserPhoneNumberAvailable = this.currentUser.has_phone_number;
      const isUserIdentifierAvailable = !!this.currentUser.identifier;

      const isUserNameAvailable = !!(
        isUserIdentifierAvailable ||
        isUserEmailAvailable ||
        isUserPhoneNumberAvailable
      );
      return this.preChatFields.filter(field => {
        if (isUserEmailAvailable && field.name === 'emailAddress') {
          return false;
        }
        if (isUserPhoneNumberAvailable && field.name === 'phoneNumber') {
          return false;
        }
        if (isUserNameAvailable && field.name === 'fullName') {
          return false;
        }
        return true;
      });
    },
    enabledPreChatFields() {
      return this.filteredPreChatFields
        .filter(field => field.enabled)
        .map(field => ({
          ...field,
          type:
            field.name === 'phoneNumber'
              ? 'phoneInput'
              : this.findFieldType(field.type),
        }));
    },
    conversationCustomAttributes() {
      let conversationAttributes = {};
      this.enabledPreChatFields.forEach(field => {
        if (field.field_type === 'conversation_attribute') {
          conversationAttributes = {
            ...conversationAttributes,
            [field.name]: this.getValue(field),
          };
        }
      });
      return conversationAttributes;
    },
    contactCustomAttributes() {
      let contactAttributes = {};
      this.enabledPreChatFields.forEach(field => {
        if (field.field_type === 'contact_attribute') {
          contactAttributes = {
            ...contactAttributes,
            [field.name]: this.getValue(field),
          };
        }
      });
      return contactAttributes;
    },
    inputStyles() {
      return `mt-1 border rounded w-full py-2 px-3 text-slate-700 outline-none`;
    },
    isInputDarkOrLightMode() {
      return `${this.getThemeClass(
        'bg-white',
        'dark:bg-slate-600'
      )} ${this.getThemeClass('text-slate-700', 'dark:text-slate-50')}`;
    },
    inputBorderColor() {
      return `${this.getThemeClass(
        'border-black-200',
        'dark:border-black-500'
      )}`;
    },
  },
  methods: {
    labelClass(context) {
      const { hasErrors } = context;
      if (!hasErrors) {
        return `text-xs font-medium ${this.getThemeClass(
          'text-black-800',
          'dark:text-slate-50'
        )}`;
      }
      return `text-xs font-medium ${this.getThemeClass(
        'text-red-400',
        'dark:text-red-400'
      )}`;
    },
    inputClass(context) {
      const { hasErrors, classification, type } = context;
      if (classification === 'box' && type === 'checkbox') {
        return '';
      }
      if (type === 'phoneInput') {
        this.hasErrorInPhoneInput = hasErrors;
      }
      if (!hasErrors) {
        return `${this.inputStyles} hover:border-black-300 focus:border-black-300 ${this.isInputDarkOrLightMode} ${this.inputBorderColor}`;
      }
      return `${this.inputStyles} border-red-200 hover:border-red-300 focus:border-red-300 ${this.isInputDarkOrLightMode}`;
    },
    isContactFieldRequired(field) {
      return this.preChatFields.find(option => option.name === field).required;
    },
    getLabel({ label }) {
      return label;
    },
    getPlaceHolder({ placeholder }) {
      return placeholder;
    },
    getValue({ name, type }) {
      if (type === 'select') {
        return this.enabledPreChatFields.find(option => option.name === name)
          .values[this.formValues[name]];
      }
      return this.formValues[name] || null;
    },
    getValidation({ type, name, field_type, regex_pattern }) {
      let regex = regex_pattern ? getRegexp(regex_pattern) : null;
      const validations = {
        emailAddress: 'email',
        phoneNumber: ['startsWithPlus', 'isValidPhoneNumber'],
        url: 'url',
        date: 'date',
        text: null,
        select: null,
        number: null,
        checkbox: false,
        contact_attribute: regex ? [['matches', regex]] : null,
        conversation_attribute: regex ? [['matches', regex]] : null,
      };
      const validationKeys = Object.keys(validations);
      const isRequired = this.isContactFieldRequired(name);
      const validation = isRequired
        ? ['bail', 'required']
        : ['bail', 'optional'];

      if (
        validationKeys.includes(name) ||
        validationKeys.includes(type) ||
        validationKeys.includes(field_type)
      ) {
        const validationType =
          validations[type] || validations[name] || validations[field_type];
        return validationType ? validation.concat(validationType) : validation;
      }

      return [];
    },
    findFieldType(type) {
      if (type === 'link') {
        return 'url';
      }
      if (type === 'list') {
        return 'select';
      }

      return type;
    },
    getOptions(item) {
      if (item.type === 'select') {
        let values = {};
        item.values.forEach((value, index) => {
          values = {
            ...values,
            [index]: value,
          };
        });
        return values;
      }
      return null;
    },
    onSubmit() {
      const { emailAddress, fullName, phoneNumber, message } = this.formValues;
      let phoneNumberAux = "";
      if (phoneNumber.startsWith('+521')) {
        // Si ya empieza con +521, lo dejamos como está
        phoneNumberAux = phoneNumber;
      } else if (phoneNumber.startsWith('+52')) {
        // Si empieza con +52 pero no tiene el 1 después, se lo agregamos
        if (phoneNumber.charAt(3) !== '1') {
          phoneNumberAux = `+521${phoneNumber.slice(3)}`;
        } else {
          phoneNumberAux = phoneNumber; // Si ya tiene +52 seguido de 1, lo dejamos igual
        }
      } else {
        // Si no empieza con +52, lo dejamos tal como está
        phoneNumberAux = phoneNumber;
      }
      this.$emit('submit', {
        fullName,
        phoneNumber: phoneNumberAux,
        emailAddress,
        message,
        activeCampaignId: this.activeCampaign.id,
        conversationCustomAttributes: this.conversationCustomAttributes,
        contactCustomAttributes: this.contactCustomAttributes,
      });
    },
  },
};
</script>

<template>
  <FormulateForm
    v-model="formValues"
    class="flex flex-col flex-1 p-6 overflow-y-auto"
    @submit="onSubmit"
  >
    <div
      v-if="shouldShowHeaderMessage"
      v-dompurify-html="formatMessage(headerMessage, false)"
      class="mb-4 text-sm leading-5 pre-chat-header-message"
      :class="getThemeClass('text-black-800', 'dark:text-slate-50')"
    />
    <FormulateInput
      v-for="item in enabledPreChatFields"
      :key="item.name"
      :name="item.name"
      :type="item.type"
      :label="getLabel(item)"
      :placeholder="getPlaceHolder(item)"
      :validation="getValidation(item)"
      :options="getOptions(item)"
      :label-class="context => labelClass(context)"
      :input-class="context => inputClass(context)"
      :validation-messages="{
        startsWithPlus: $t(
          'PRE_CHAT_FORM.FIELDS.PHONE_NUMBER.DIAL_CODE_VALID_ERROR'
        ),
        isValidPhoneNumber: $t('PRE_CHAT_FORM.FIELDS.PHONE_NUMBER.VALID_ERROR'),
        email: $t('PRE_CHAT_FORM.FIELDS.EMAIL_ADDRESS.VALID_ERROR'),
        required: $t('PRE_CHAT_FORM.REQUIRED'),
        matches: item.regex_cue
          ? item.regex_cue
          : $t('PRE_CHAT_FORM.REGEX_ERROR'),
      }"
      :has-error-in-phone-input="hasErrorInPhoneInput"
    />
    <FormulateInput
      v-if="!hasActiveCampaign"
      name="message"
      type="textarea"
      :label-class="context => labelClass(context)"
      :input-class="context => inputClass(context)"
      :label="$t('PRE_CHAT_FORM.FIELDS.MESSAGE.LABEL')"
      :placeholder="$t('PRE_CHAT_FORM.FIELDS.MESSAGE.PLACEHOLDER')"
      validation="required"
      :validation-messages="{
        required: $t('PRE_CHAT_FORM.FIELDS.MESSAGE.ERROR'),
      }"
    />

    <CustomButton
      class="mt-2 mb-5 font-medium"
      block
      :bg-color="widgetColor"
      :text-color="textColor"
      :disabled="isCreating"
    >
      <Spinner v-if="isCreating" class="p-0" />
      {{ $t('START_CONVERSATION') }}
    </CustomButton>
  </FormulateForm>
</template>

<style lang="scss" scoped>
@import '~widget/assets/scss/variables.scss';
::v-deep {
  .wrapper[data-type='checkbox'] {
    .formulate-input-wrapper {
      display: flex;
      align-items: center;
      line-height: $space-normal;

      label {
        margin-left: 0.2rem;
      }
    }
  }
  @media (prefers-color-scheme: dark) {
    .wrapper {
      .formulate-input-element--date,
      .formulate-input-element--checkbox {
        input {
          color-scheme: dark;
        }
      }
    }
  }
  .wrapper[data-type='textarea'] {
    .formulate-input-element--textarea {
      textarea {
        min-height: 8rem;
      }
    }
  }
  .pre-chat-header-message {
    .link {
      color: $color-woot;
      text-decoration: underline;
    }
  }
}
</style>
