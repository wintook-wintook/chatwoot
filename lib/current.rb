module Current
  thread_mattr_accessor :user
  thread_mattr_accessor :account
  thread_mattr_accessor :account_user
  thread_mattr_accessor :executed_by
  thread_mattr_accessor :contact
  # Asistente (Dali) — lo que se hace al confirmar una propuesta del asistente queda
  # marcado «vía asistente» en la bitácora del caso (CaseEvent).
  thread_mattr_accessor :via_assistant

  def self.reset
    Current.user = nil
    Current.account = nil
    Current.account_user = nil
    Current.executed_by = nil
    Current.contact = nil
    Current.via_assistant = nil
  end
end
