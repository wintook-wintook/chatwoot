# frozen_string_literal: true

# Portal del cliente (/cliente/:token) — sin usuario: el enlace de la organización (o del
# contacto). Ve sus casos y proyectos y trabaja las tareas que le tocan: empezar,
# comentar, subir archivo y completar (ClientTasks::Recorder). Quien firma se elige de
# los contactos de la organización y se recuerda en este navegador.
class Public::ClientPortalsController < PublicController
  layout 'public_document'

  before_action :set_link
  around_action :use_account_locale

  ACTIONS = %w[start comment attach finish].freeze

  def show
    @people = @link.people.limit(300).to_a
    @person = current_person
    @snapshot = ClientPortal::Snapshot.new(@link)
    @link.update_column(:last_used_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def person
    contact = @link.people.find_by(id: params[:contact_id])
    cookies.signed[cookie_key] = { value: contact.id, expires: 1.year, httponly: true } if contact
    redirect_to public_client_portal_path(params[:token])
  end

  def task
    task = CaseTask.client_facing.where(case_ticket_id: @link.cases.select(:id)).find(params[:task_id])
    return redirect_back_to(task, I18n.t('client_portal.errors.who')) if needs_person?

    run(task)
    redirect_back_to(task)
  rescue ClientTasks::Recorder::Error => e
    redirect_back_to(task, e.message)
  end

  private

  def run(task)
    recorder = ClientTasks::Recorder.new(task, contact: current_person)
    case params[:do].to_s
    when 'start' then recorder.start
    when 'comment' then recorder.comment(params[:content])
    when 'attach' then recorder.attach(params[:file], params[:content])
    when 'finish' then recorder.finish(params[:content])
    end
  end

  def redirect_back_to(task, error = nil)
    flash[:client_portal_error] = error if error
    redirect_to "#{public_client_portal_path(params[:token])}#t#{task.id}"
  end

  def set_link
    @link = ClientPortalLink.active.includes(:account, :organization, :contact).find_by!(token: params[:token])
    @account = @link.account
  end

  def current_person
    return @link.contact if @link.contact_id

    id = cookies.signed[cookie_key]
    id && @link.people.find_by(id: id)
  end

  def needs_person?
    @link.organization_id.present? && current_person.nil? && @link.people.exists?
  end

  def cookie_key
    "client_portal_#{@link.id}"
  end

  def use_account_locale(&)
    I18n.with_locale(@account.locale.presence || I18n.default_locale, &)
  end
end
