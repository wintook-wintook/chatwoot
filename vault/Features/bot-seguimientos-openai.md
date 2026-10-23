# El bot de seguimientos y su dependencia de OpenAI

OpenAI (GPT-4o-mini) es un **requisito obligatorio** para el bot de seguimientos
(`ContactTrackingResponseAnalyzerJob`, ver [[bug-dia-semana-equivocado]] para detalle del archivo).
Sin OpenAI el sistema no funciona.

**Por qué:** el bot de análisis de intenciones depende completamente de GPT-4o-mini para
clasificar correctamente los mensajes según el objetivo del seguimiento (lógica INTENCIÓN vs
EJECUCIÓN). El fallback de keywords que existe en el código es incapaz de distinguir contexto.

**Cómo aplicar:** no es necesario optimizar el fallback de keywords ni diseñar para escenarios sin
API key. Todas las mejoras de prompts aplican directamente a los prompts de OpenAI (Prompt A
contextual). El fallback existe pero no es un escenario a optimizar.

## Relacionado
- [[bug-dia-semana-equivocado]]
- [[discourse-knowledge-base]]
- [[contact-tracking-changes-20260420]]
- [[refactor-tracking-bot-job-plan]]
