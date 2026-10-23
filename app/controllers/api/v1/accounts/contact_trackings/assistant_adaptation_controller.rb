# frozen_string_literal: true

# ================================================================================
# proyecto@adaptar_prompts_publicados (F1) — LA PESTAÑA «CONFIGURAR» DEL ASISTENTE
# ================================================================================
# POST …/assistant/adaptation        { text, tracking_template_id? }
#   → { items } — qué le falta a este texto en esta cuenta (AdaptationInventory).
#
# POST …/assistant/adaptation/apply  { text, answers: { key => valor }, tracking_template_id? }
#   → { text, applied, rejected, items, validation } — el texto reescrito
#     (AdaptationApplier), lo que queda pendiente y el comprobador ya corrido.
#
# Los dos son POST con el texto porque el borrador puede no estar guardado (igual que
# assistant/validate). El texto no se guarda aquí: el navegador lo pone en el editor y lo
# guarda como cualquier otro cambio (autosave → Versiones y Cambios). Lo único que apply
# escribe son las respuestas aplicadas, en el agente (F6: adaptation_answers).
#
# feat/reemplazo_directo_variables: mark_variables con `value` escribe el valor directo
# (sin marca) y lo recuerda; un agente «En construcción» lo recuerda en su conversación
# (`session_id`) hasta que se guarde. Lo recordado deja cambiarlo después desde la misma
# pestaña: el inventario lo muestra ✔ y apply cambia el valor anterior por el nuevo.
#
# Crear lo que falta (fuente, etiqueta, archivo) va por los endpoints que ya existen;
# aquí solo se lee y se reescribe texto. Mismo permiso que el resto del Asistente.
# Plan: docs/adaptar_prompts_publicados_plan.md
# ================================================================================

class Api::V1::Accounts::ContactTrackings::AssistantAdaptationController < Api::V1::Accounts::BaseController
  MAX_ANSWERS = 100

  before_action :check_authorization

  def index
    render json: { items: inventory(params[:text]) }
  end

  def apply
    result = ContactTrackings::Assistant::AdaptationApplier.new(params[:text], answers, previous: remembered).call
    remember(answers.slice(*result.applied))

    render json: {
      text: result.text,
      applied: result.applied,
      rejected: result.rejected,
      items: inventory(result.text),
      validation: ContactTrackings::Assistant::ValidatorService.new(result.text, account: Current.account).call
    }
  end

  # F7: el modelo propone qué textos son datos de un negocio. No escribe nada. Lo que ya
  # se reemplazó aquí es dato de ESTE negocio: no se vuelve a ofrecer (F9).
  def suggest_variables
    result = ContactTrackings::Assistant::VariableSuggestions.new(params[:text], account: Current.account).call
    render json: { variables: not_yet_written(result.variables), error: result.error }.compact
  end

  # F7: los elegidos pasan a <PENDIENTE: nombre> (mismo reemplazo protegido que al publicar)
  # y aparecen en «Datos de tu negocio» para llenarlos. Con `value` se escribe el valor
  # directo y se recuerda. El texto no se guarda aquí, igual que apply.
  def mark_variables
    variables = PublishedPrompts::Variables.normalize(params[:variables])
    problemas = PublishedPrompts::Variables.problems(variables, params[:text].to_s)
    return render json: { message: problemas.join(' · ') }, status: :unprocessable_entity if problemas.any?

    text = PublishedPrompts::Variables.apply(params[:text].to_s, variables)
    remember(written_values(variables))
    render json: { text: text, items: inventory(text),
                   validation: ContactTrackings::Assistant::ValidatorService.new(text, account: Current.account).call }
  end

  private

  def inventory(text)
    ContactTrackings::Assistant::AdaptationInventory.new(text, account: Current.account, template: template,
                                                               answers: remembered).call
  end

  # El agente guardado (si lo hay) dice qué archivos y qué bandeja tiene ya.
  def template
    return nil if params[:tracking_template_id].blank?

    @template ||= Current.account.tracking_templates.find_by(id: params[:tracking_template_id])
  end

  def not_yet_written(variables)
    return variables if variables.nil?

    propios = remembered.values.map { |valor| valor.to_s.strip.downcase }
    variables.reject { |v| propios.include?(v['text'].to_s.strip.downcase) }
  end

  # Lo escrito directo, con la misma llave que una marca llenada: "var:<etiqueta>".
  def written_values(variables)
    variables.select { |v| v['value'] }.to_h { |v| ["var:#{v['label'].downcase}", v['value']] }
  end

  # Sin agente, la conversación «En construcción» (pasa al agente al guardarla).
  def session_record
    return nil if template || params[:session_id].blank?

    @session_record ||= TrackingAssistantSession.find_by(id: params[:session_id], account: Current.account)
  end

  # Lo aplicado antes: del agente o, sin agente, de su conversación.
  def remembered
    (template || session_record)&.adaptation_answers.to_h
  end

  # F6: lo aplicado queda en el agente (si lo hay) para prellenar «Configurar» cuando el
  # autor publique una versión nueva, y para cambiarlo después. Es lo ÚNICO que este
  # endpoint escribe: el texto no se guarda aquí. Sin validaciones a propósito: no cambia
  # nada que se valide.
  def remember(valores)
    duenio = template || session_record
    return if duenio.nil? || valores.empty?

    nuevas = valores.transform_values { |value| value.to_s.strip }
    duenio.update_column(:adaptation_answers, duenio.adaptation_answers.to_h.merge(nuevas)) # rubocop:disable Rails/SkipsModelValidations
  end

  # Solo llave → texto: un valor que no es texto (lista, objeto) no se aplica.
  def answers
    crudo = params[:answers]
    crudo = crudo.to_unsafe_h if crudo.respond_to?(:to_unsafe_h)
    return {} unless crudo.is_a?(Hash)

    crudo.select { |key, value| key.is_a?(String) && (value.is_a?(String) || value.is_a?(Numeric)) }
         .first(MAX_ANSWERS).to_h
  end

  def check_authorization
    render json: { error: I18n.t('errors.unauthorized') }, status: :unauthorized unless Current.account_user&.administrator?
  end
end
