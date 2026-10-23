# frozen_string_literal: true

# proyecto@predefinidas_prompt — solo se vectoriza lo que se busca.
require 'rails_helper'

RSpec.describe CannedResponse do
  let(:account) { create(:account) }

  def vectoriza
    have_enqueued_job(KnowledgeItemSyncJob).with(hash_including(action: 'upsert', source_type: 'canned_response'))
  end

  it 'vectoriza una respuesta nueva' do
    expect { create(:canned_response, account: account) }.to vectoriza
  end

  it 'vuelve a vectorizar si cambió el contenido o el nombre' do
    canned = create(:canned_response, account: account)

    expect { canned.update!(content: 'otro contenido') }.to vectoriza
    expect { canned.update!(short_code: 'OTRO NOMBRE') }.to vectoriza
  end

  # El prompt propio no entra a la búsqueda: pedir el embedding otra vez sería una
  # llamada a OpenAI por nada.
  it 'no vuelve a vectorizar si solo cambió el prompt' do
    canned = create(:canned_response, account: account)

    expect { canned.update!(content_prompts: 'instrucciones nuevas') }.not_to vectoriza
  end
end
