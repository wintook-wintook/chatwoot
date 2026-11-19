# frozen_string_literal: true

# Motor 2.0 — base de una habilidad. `turn` es el Motor2::Runner del turno: da la ficha
# (config), la memoria del cliente (state), la traza, la conversación y si es prueba.
class Motor2::Skills::Base
  include Motor2::Tools

  def initialize(turn)
    @turn = turn
  end

  def self.key = name.demodulize.underscore

  def key = self.class.key

  def on? = config.skill_on?(key)

  # Definiciones de OpenAI.
  def tools = []

  def handles?(name) = tools.any? { |t| name_of(t) == name }

  # Unas líneas nuestras para el prompt (cómo usar la habilidad).
  def instructions = ''

  # Lo que el código recuerda, para que el modelo lo vea en cada turno.
  def memory = ''

  # Antes de armar el prompt, con la plática (cliente = user, agente = assistant): lo que el código
  # puede deducir solo (p. ej. a qué pregunta contestó el cliente).
  def prepare(_history); end

  # Una línea para el final del turno (lo último que lee el modelo antes de contestar).
  def turn_note = ''

  # La pregunta con la que debe terminar su mensaje (el código lo revisa), o nil.
  def required_question = nil

  def call(_name, _args) = { error: 'herramienta desconocida' }

  private

  def config = @turn.config

  def state = @turn.state

  def trace = @turn.trace

  def test? = @turn.test?

  def setting(name) = config.skill(key)[name.to_s]
end
