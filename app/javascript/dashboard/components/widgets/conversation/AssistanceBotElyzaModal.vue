<script>
export default {
    components: {
        // TemplatesPicker,
        // TemplateParser,
    },
    props: {
        show: {
            type: Boolean,
            default: true,
        },
        onClose: {
            type: Function,
            default: () => { },
        },
        currentChat: {
            type: Array,
            required: true,
        },
        inReplyTo: {
            type: Array,
            required: true,
        }
    },
    data() {
        return {
            selectedWaTemplate: null,
            messageProcessed: '',
            messagePrompt: 'Eres un asistente profesional. Tu tarea es analizar la conversación y sugerir una respuesta útil al contacto con base en la interacción previa.',
        };
    },
    computed: {
        modalHeaderContent() {
            return "Sugerencia respuesta botElyza"
        },
    },
    mounted() {
        console.log(this.currentChat)
        console.log(this.inReplyTo)
    },
    methods: {
        // pickTemplate(template) {
        //   this.selectedWaTemplate = template;
        // },
        // onResetTemplate() {
        //   this.selectedWaTemplate = null;
        // },
        // onSendMessage(message) {
        //   this.$emit('onSend', message);
        // },

        // async onProcess() {
        //   const messages = this.currentChat.messages || [];
        //   console.log(messages)
        //   const start_id = this.inReplyTo.id
        //   console.log(start_id)
        //   // .filter(item => item.id >= start_id && item.content_type === "text")
        //   const conversation = messages
        //     .filter(item =>
        //       item.id >= start_id &&
        //       item.content_type === "text" &&
        //       item.private !== true &&
        //       Object.keys(item.content_attributes).length === 0
        //     )
        //     .map(item => `${item.sender.type} : ${item.content}\n`);
        //     // .map(item => `Prompt: ${this.messagePrompt} (Solo dame la respuesta), Este es le contenido para generar la sugerencia : ${item.sender.type} : ${item.content}\n`);

        //     // .map(item => ({
        //     //   content: item.content,
        //     //   senderType: item.sender.type
        //     // }));

        //   // const convertToChatMessages = (conversation) => {
        //   //   return conversation.map((entry) => ({
        //   //     role: entry.senderType === "contact" ? "user" : "assistant",
        //   //     content: entry.content,
        //   //   }));
        //   // };
        //   // console.log("convertToChatMessages", convertToChatMessages)
        //   console.log(conversation)
        //   try {
        //     const apiKey = "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"
        //     const query = `Prompt: ${this.messagePrompt} (Solo dame la respuesta), Este es le contenido para generar la sugerencia : ${conversation}`
        //     // this.messagePrompt.concat(conversation)
        //     const messages_body = [
        //       { role: "user", content: query }
        //       // {
        //       //   role: "system",
        //       //   content: this.messagePrompt,
        //       // },
        //       // ...convertToChatMessages(conversation),
        //     ];
        //     console.log("messages_body", messages_body)

        //     const url = "https://api.openai.com/v1/chat/completions";

        //     const response = await fetch(url, {
        //       method: "POST",
        //       headers: {
        //         "Content-Type": "application/json",
        //         Authorization: `Bearer ${apiKey}`,
        //       },
        //       body: JSON.stringify({
        //         model: 'gpt-3.5-turbo',
        //         messages: messages_body,
        //         temperature: 0.7,
        //         max_tokens: 1000,
        //       }),
        //     });

        //     if (!response.ok) {
        //       throw new Error(`Error HTTP: ${response.status}`);
        //     }

        //     const data = await response.json();
        //     this.messageProcessed = data.choices[0].message.content;
        //     console.log("this.messageProcessed", this.messageProcessed)
        //     return (true);

        //   } catch (error) {
        //     console.error("Error al llamar a la API:", error.message);
        //     throw error; // Propaga el error para que el llamador lo maneje si es necesario
        //   }
        // },
        async onProcess() {
            try {
                const messages = this.currentChat.messages || [];
                console.log("Mensajes actuales:", messages);

                const start_id = this.inReplyTo?.id || 0;
                console.log("start_id:", start_id);

                const validMessages = messages.filter(item => {
                    console.log("Mensaje evaluado:", item);
                    return (
                        item.id >= start_id &&
                        item.content_type === "text" &&
                        item.private !== true &&
                        Object.keys(item.content_attributes).length === 0
                    );
                });

                console.log("Mensajes válidos:", validMessages);

                // const conversation = validMessages.map(item => `${item.sender.type} : ${item.content}\n`);
                const conversation = validMessages.map(item => item.sender ? `${item.sender.type} : ${item.content}\n` : null)
                console.log("Conversación procesada:", conversation);

                if (!conversation.length) {
                    throw new Error("La conversación está vacía. No se puede procesar.");
                }

                const apiKey = "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";
                const query = `Prompt: ${this.messagePrompt} (Solo dame la respuesta), Este es le contenido para generar la sugerencia : ${conversation}`;
                const messages_body = [{ role: "user", content: query }];

                console.log("messages_body:", messages_body);

                const url = "https://api.openai.com/v1/chat/completions";

                const response = await fetch(url, {
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json",
                        Authorization: `Bearer ${apiKey}`,
                    },
                    body: JSON.stringify({
                        model: 'gpt-3.5-turbo',
                        messages: messages_body,
                        temperature: 0.7,
                        max_tokens: 1000,
                    }),
                });

                if (!response.ok) {
                    throw new Error(`Error HTTP: ${response.status}`);
                }

                const data = await response.json();
                this.messageProcessed = data.choices[0].message.content;
                console.log("Respuesta procesada:", this.messageProcessed);
                return true;

            } catch (error) {
                console.error("Error al procesar:", error.message);
                throw error;
            }
        },
        applyText() {
            this.$emit('messageProcessed', this.messageProcessed);
            // this.onClose();
        },
    }
};
</script>

<!-- eslint-disable vue/no-mutating-props -->
<template>
    <woot-modal :show.sync="show" :on-close="onClose" size="modal-big">
        <woot-modal-header :header-title="modalHeaderContent" />
        <form class="flex flex-col w-full modal-content" @submit.prevent="applyText">
            <div class="flex flex-col">
                <label>
                    {{ 'Descripción de Prompt' }}
                    <textarea v-model="messagePrompt" class="min-h-[10rem]" type="text"
                        :placeholder="'Descripción de Prompt'" />
                </label>
            </div>
            <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
                <woot-button @click.prevent="onProcess">
                    {{ 'Consultar sugerencia' }}
                </woot-button>
            </div>
            <div class="flex flex-col">
                <label>
                    {{ 'Contenido de respuesta sugerida' }}
                    <textarea v-model="messageProcessed" class="min-h-[10rem]" type="text"
                        :placeholder="'Sugerencia '" />
                </label>
            </div>
            <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
                <woot-button variant="clear" @click.prevent="onClose">
                    {{
                        $t('INTEGRATION_SETTINGS.OPEN_AI.ASSISTANCE_MODAL.BUTTONS.CANCEL')
                    }}
                </woot-button>
                <woot-button :disabled="!messageProcessed">
                    {{
                        $t('INTEGRATION_SETTINGS.OPEN_AI.ASSISTANCE_MODAL.BUTTONS.APPLY')
                    }}
                </woot-button>
            </div>
        </form>
    </woot-modal>
</template>

<style scoped>
.modal-content {
    padding: 1.5625rem 2rem;
}
</style>
