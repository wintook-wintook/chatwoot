# frozen_string_literal: true

# == Schema Information
#
# Table name: assistant_threads
#
#  id         :bigint           not null, primary key
#  archived   :boolean          default(FALSE), not null
#  messages   :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_assistant_threads_on_account_id                           (account_id)
#  index_assistant_threads_on_account_id_and_user_id_and_archived  (account_id,user_id,archived)
#  index_assistant_threads_on_user_id                              (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
# Asistente (Dali) — la conversación de un usuario con el asistente. Cada mensaje:
#   { id, role: 'user'|'assistant', content, at, proposals: [...], navigate: '/app/...',
#     feedback: 'down' (el usuario marcó 👎; queda en AssistantGuideGap) }
# Una propuesta es una acción que el asistente quiere hacer y espera «Confirmar»:
#   { id, type, payload, labels, status: 'pending'|'done'|'cancelled'|'failed', result }
class AssistantThread < ApplicationRecord
  MAX_MESSAGES = 80

  belongs_to :account
  belongs_to :user

  scope :active, -> { where(archived: false) }

  def self.current_for(account, user)
    active.where(account: account, user: user).order(updated_at: :desc).first ||
      create!(account: account, user: user)
  end

  def add_message(attrs)
    message = { 'id' => SecureRandom.hex(6), 'at' => Time.current.iso8601 }.merge(attrs.deep_stringify_keys)
    self.messages = (messages + [message]).last(MAX_MESSAGES)
    save!
    message
  end

  def find_proposal(id)
    messages.each do |message|
      proposal = Array(message['proposals']).find { |p| p['id'] == id }
      return proposal if proposal
    end
    nil
  end

  # 👎 del usuario a una respuesta: la marca y devuelve [respuesta, pregunta que la originó].
  def mark_unhelpful!(id)
    index = messages.index { |m| m['id'] == id && m['role'] == 'assistant' }
    return nil unless index

    messages[index]['feedback'] = 'down'
    messages_will_change!
    save!
    question = messages[0...index].reverse.find { |m| m['role'] == 'user' }
    [messages[index], question]
  end

  def update_proposal!(id, changes)
    messages.each do |message|
      Array(message['proposals']).each { |p| p.merge!(changes.deep_stringify_keys) if p['id'] == id }
    end
    messages_will_change!
    save!
  end
end
