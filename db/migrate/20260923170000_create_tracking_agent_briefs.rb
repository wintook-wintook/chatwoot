# proyecto@asistente_agentes_ia — el ENCARGO de un Agente IA (ver docs/importar_prompt_md_plan.md).
#
# Un .md con la idea de cómo se quiere el agente: quién es, qué atiende, qué nunca
# hace. No es el Entrenamiento: el Asistente lo lee, pregunta lo que falta y ESCRIBE
# el Entrenamiento. Se guarda entero para poder regenerar sin volver a subirlo, y con
# su huella para no volver a pagar la lectura de un archivo que ya se leyó.
#
# Mismo prefijo que tracking_assistant_sessions, por la misma razón: esta base ya
# tiene tablas "assistant" de otros módulos (Captain, el PR revertido #23).
class CreateTrackingAgentBriefs < ActiveRecord::Migration[7.0]
  def change
    create_table :tracking_agent_briefs do |t|
      t.references :account, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      # El agente al que quedó ligado al guardar. Nullable: se sube antes de que exista.
      t.references :tracking_template, foreign_key: { on_delete: :nullify }
      # La conversación del Asistente donde se subió.
      t.references :tracking_assistant_session, foreign_key: { on_delete: :nullify }

      t.string :filename, null: false
      # El .md completo (ADAM: 1,1 MB). text y no ActiveStorage: se lee entero para
      # trocearlo y no hace falta servirlo como archivo.
      t.text :content, null: false
      t.string :sha256, null: false
      # pending = subido, sin leer · reading · ready · failed
      t.string :status, null: false, default: 'pending'
      # Huella + ruta de títulos + ficha parcial de cada trozo (F1/F2).
      t.jsonb :chunks, null: false, default: []
      # La ficha del encargo, ya junta (F2).
      t.jsonb :digest, null: false, default: {}
      # Preguntas y respuestas del chat, y lo marcado "dejar fuera" (F3/F4).
      t.jsonb :answers, null: false, default: {}
      # Tokens y segundos por paso.
      t.jsonb :usage, null: false, default: {}

      t.timestamps
    end

    # "¿Esta cuenta ya leyó este archivo?" — la consulta que evita pagar dos veces.
    add_index :tracking_agent_briefs, %i[account_id sha256]
  end
end
