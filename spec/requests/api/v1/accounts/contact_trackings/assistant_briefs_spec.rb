# frozen_string_literal: true

require 'rails_helper'

# proyecto@asistente_agentes_ia — el encargo (.md), fase F0 de docs/importar_prompt_md_plan.md
RSpec.describe 'Asistente de Agentes IA — encargos' do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }
  let(:base)    { "/api/v1/accounts/#{account.id}/contact_trackings/assistant/briefs" }
  let(:texto)   { "# Agente de citas\n\nAgenda citas médicas. Nunca da diagnósticos.\n" }

  def archivo(contenido = texto, nombre = 'encargo.md')
    Rack::Test::UploadedFile.new(StringIO.new(contenido), 'text/markdown', original_filename: nombre)
  end

  def subir(params = {}, user: admin)
    post base, params: { file: archivo }.merge(params), headers: user.create_new_auth_token
  end

  def sesion(dueno = admin)
    TrackingAssistantSession.create!(account: account, user: dueno)
  end

  describe 'POST' do
    it 'no deja entrar a un agente' do
      subir(user: agent)

      expect(response).to have_http_status(:unauthorized)
      expect(TrackingAgentBrief.where(account: account).count).to eq(0)
    end

    it 'guarda el encargo entero, con su huella, pendiente de leer' do
      subir

      expect(response).to have_http_status(:created)
      brief = TrackingAgentBrief.find(response.parsed_body['id'])
      expect(brief.content).to eq(texto)
      expect(brief.sha256).to eq(Digest::SHA256.hexdigest(texto))
      expect(brief.status).to eq('pending')
      expect(response.parsed_body).not_to have_key('content')
    end

    it 'lo manda a leer en segundo plano, con el turno para seguir el avance' do
      expect { subir({ turn_id: 'turno-12345' }) }
        .to have_enqueued_job(ContactTrackings::Assistant::AgentBriefDigestJob)
        .with(kind_of(Integer), admin.id, 'turno-12345')
    end

    it 'no manda a leer uno que ya viene leído' do
      subir({ session_id: sesion.id })
      TrackingAgentBrief.where(account: account).last.update!(status: 'ready')

      expect { subir({ session_id: sesion.id }) }.not_to have_enqueued_job(ContactTrackings::Assistant::AgentBriefDigestJob)
    end

    it 'lo liga a la conversación del Asistente' do
      conversacion = sesion
      subir({ session_id: conversacion.id })

      expect(TrackingAgentBrief.where(account: account).last.tracking_assistant_session).to eq(conversacion)
    end

    it 'no duplica el mismo archivo en la misma conversación' do
      conversacion = sesion
      subir({ session_id: conversacion.id })
      primero = response.parsed_body['id']
      subir({ session_id: conversacion.id })

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('id' => primero, 'reused' => 'same_session')
      expect(TrackingAgentBrief.where(account: account).count).to eq(1)
    end

    # Leer un encargo grande cuesta: si la cuenta ya lo leyó, se copia la lectura.
    it 'copia la lectura de otro encargo de la cuenta con el mismo archivo' do
      subir({ session_id: sesion.id })
      TrackingAgentBrief.where(account: account).last.update!(status: 'ready', digest: { 'objetivo' => 'agendar' }, answers: { 'x' => 1 })

      subir({ session_id: sesion.id })

      expect(response).to have_http_status(:created)
      nuevo = TrackingAgentBrief.find(response.parsed_body['id'])
      expect(response.parsed_body['reused']).to eq('reading')
      expect(nuevo).to have_attributes(status: 'ready', digest: { 'objetivo' => 'agendar' }, answers: {})
    end

    it 'no copia la lectura de otra cuenta' do
      otra = create(:account)
      TrackingAgentBrief.create!(account: otra, user: create(:user, account: otra), filename: 'x.md', content: texto,
                                 sha256: Digest::SHA256.hexdigest(texto), status: 'ready', digest: { 'a' => 1 })
      subir

      expect(TrackingAgentBrief.find(response.parsed_body['id']).status).to eq('pending')
    end

    it 'rechaza una conversación de otra cuenta' do
      otra = create(:account)
      ajena = TrackingAssistantSession.create!(account: otra, user: create(:user, account: otra))
      subir({ session_id: ajena.id })

      expect(response).to have_http_status(:not_found)
    end

    it 'deja el texto limpio: sin BOM y con saltos de línea Unix' do
      post base, params: { file: archivo("\uFEFFuno\r\ndos\rtres") }, headers: admin.create_new_auth_token

      expect(TrackingAgentBrief.where(account: account).last.content).to eq("uno\ndos\ntres")
    end

    {
      'sin archivo' => [{ file: nil }, 'missing_file'],
      'con extensión que no es texto' => [{ file: :pdf }, 'bad_extension'],
      'binario disfrazado de .md' => [{ file: :zip }, 'not_text'],
      'vacío' => [{ file: :blank }, 'empty']
    }.each do |caso, (params, error)|
      it "rechaza un archivo #{caso}" do
        file = { pdf: -> { archivo(texto, 'encargo.pdf') }, zip: -> { archivo("PK\u0003\u0004\u0000\u0000", 'x.md') },
                 blank: -> { archivo("  \n\n", 'x.md') } }[params[:file]]&.call
        post base, params: { file: file }.compact, headers: admin.create_new_auth_token

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq(error)
      end
    end

    it 'rechaza un archivo de más de 5 MB' do
      stub_const('TrackingAgentBrief::MAX_BYTES', 10)
      subir

      expect(response.parsed_body['error']).to eq('too_large')
    end
  end

  describe 'GET' do
    let!(:brief) do
      TrackingAgentBrief.create!(account: account, user: admin, filename: 'encargo.md', content: texto,
                                 sha256: TrackingAgentBrief.fingerprint(texto))
    end

    it 'devuelve los datos sin el texto' do
      get "#{base}/#{brief.id}", headers: admin.create_new_auth_token

      expect(response.parsed_body).to include('id' => brief.id, 'filename' => 'encargo.md', 'status' => 'pending')
      expect(response.parsed_body).not_to have_key('content')
    end

    it 'con la lectura hecha, devuelve la ficha y lo que falta' do
      brief.update!(status: 'ready', digest: { 'ficha' => { 'objetivo' => { 'texto' => 'agendar' } }, 'faltas' => [] })
      get "#{base}/#{brief.id}", headers: admin.create_new_auth_token

      expect(response.parsed_body['digest']['ficha']['objetivo']['texto']).to eq('agendar')
    end

    it 'reintentar la lectura la vuelve a encolar' do
      brief.update!(status: 'failed')

      expect { post "#{base}/#{brief.id}/digest", headers: admin.create_new_auth_token }
        .to have_enqueued_job(ContactTrackings::Assistant::AgentBriefDigestJob).with(brief.id, admin.id, nil)
      expect(response).to have_http_status(:accepted)
    end

    it 'devuelve el .md tal cual' do
      get "#{base}/#{brief.id}/content", headers: admin.create_new_auth_token

      expect(response.body.force_encoding('UTF-8')).to eq(texto)
      expect(response.media_type).to eq('text/markdown')
    end

    it 'otra cuenta no lo ve' do
      otra = create(:account)
      ajeno = create(:user, account: otra, role: :administrator)
      get "/api/v1/accounts/#{otra.id}/contact_trackings/assistant/briefs/#{brief.id}",
          headers: ajeno.create_new_auth_token

      expect(response).to have_http_status(:not_found)
    end
  end
end
