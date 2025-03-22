<template>
    <div class="w-full overflow-x-auto text-slate-700 dark:text-slate-200">
        <div class="mt-6 flex-1">
            <div class="mx-0 flex flex-wrap">
                <div class="flex-shrink-0 flex-grow-0 w-full md:w-[65%]">
                    <form class="mx-0 flex flex-wrap">

                        <div class="w-full flex items-center gap-2">
                            <input v-model="systemSettings.menu" type="checkbox" :value="true" @change="setSystemSettings" />
                            <label for="conversation_creation">
                                {{ 'Activar menú del sistema' }}
                            </label>
                        </div>

                        <div class="w-full flex items-center gap-2">
                            <input v-model="systemSettings.keywords" type="checkbox" :value="true" @change="setSystemSettings" />
                            <label for="conversation_creation">
                                {{ 'Mostrar resultado de palabras clave' }}
                            </label>
                        </div>

                    </form>
                </div>
            </div>
        </div>
    </div>
</template>
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
export default {
    components: {
    },
    data() {
        return {
            systemSettings: {},
        };
    },
    computed: {
        ...mapGetters({
            currentUser: 'getCurrentUser',
        }),
    },
    mounted() {
        this.getSystemSettings();
    },
    methods: {
        async getSystemSettings() {
            const { access_token, account_id } = this.currentUser;
            const { WINTOOK_BOT } = process.env;
            const params = new URLSearchParams({ access_token, account_id });
            try {
                const url = `${WINTOOK_BOT}/api/getSystemSettings?${params}`;
                const response = await fetch(url);
                if (response.ok) {
                    this.systemSettings = await response.json();
                } else {
                    console.error('Error en la respuesta HTTP: ', response.status);
                }
            } catch (error) {
                console.error('Error de red o al procesar la petición: ', error);
            }
        },
        async setSystemSettings() {
            const { access_token, account_id } = this.currentUser;
            const { WINTOOK_BOT } = process.env;
            const data = {
                access_token,
                account_id,
                ...this.systemSettings
            };

            try {
                const url = `${WINTOOK_BOT}/api/setSystemSettings`;
                const response = await fetch(url, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(data)
                });

                if (response.ok) {
                    useAlert('Actualizado....');
                } else {
                    console.error('Error en la respuesta HTTP: ', response.status);
                }
            } catch (error) {
                console.error('Error de red o al procesar la petición: ', error);
            }
        },


    }
}
</script>