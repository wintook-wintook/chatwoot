Rails.application.routes.draw do
  # AUTH STARTS
  mount_devise_token_auth_for 'User', at: 'auth', controllers: {
    confirmations: 'devise_overrides/confirmations',
    passwords: 'devise_overrides/passwords',
    sessions: 'devise_overrides/sessions',
    token_validations: 'devise_overrides/token_validations',
    omniauth_callbacks: 'devise_overrides/omniauth_callbacks'
  }, via: [:get, :post]

  ## renders the frontend paths only if its not an api only server
  if ActiveModel::Type::Boolean.new.cast(ENV.fetch('CW_API_ONLY_SERVER', false))
    root to: 'api#index'
  else
    root to: 'dashboard#index'

    get '/app', to: 'dashboard#index'
    get '/app/*params', to: 'dashboard#index'
    get '/app/accounts/:account_id/settings/inboxes/new/twitter', to: 'dashboard#index', as: 'app_new_twitter_inbox'
    get '/app/accounts/:account_id/settings/inboxes/new/microsoft', to: 'dashboard#index', as: 'app_new_microsoft_inbox'
    get '/app/accounts/:account_id/settings/inboxes/new/:inbox_id/agents', to: 'dashboard#index', as: 'app_twitter_inbox_agents'
    get '/app/accounts/:account_id/settings/inboxes/new/:inbox_id/agents', to: 'dashboard#index', as: 'app_email_inbox_agents'
    get '/app/accounts/:account_id/settings/inboxes/:inbox_id', to: 'dashboard#index', as: 'app_email_inbox_settings'

    resource :widget, only: [:show]
    namespace :survey do
      resources :responses, only: [:show]
    end
    resource :slack_uploads, only: [:show]
  end

  get '/api', to: 'api#index'
  namespace :api, defaults: { format: 'json' } do
    namespace :v1 do
      # ----------------------------------
      # start of account scoped api routes
      resources :accounts, only: [:create, :show, :update] do
        member do
          post :update_active_at
          get :cache_keys
        end

        scope module: :accounts do
          
          # KANBAN0725
          resources :kanban_type_processes do
            get :conversation_kanban_info, on: :collection, path: 'conversation/:conversation_id/kanban_info'
            resources :kanban_processes do
              member do
                patch :reorder
              end
            end
          end
          resources :kanban_processes, only: [:destroy]
          # KANBAN0725
          namespace :actions do
            resource :contact_merge, only: [:create]
          end
          resource :bulk_actions, only: [:create]
          resources :agents, only: [:index, :create, :update, :destroy] do
            post :bulk_create, on: :collection
          end
          resources :agent_bots, only: [:index, :create, :show, :update, :destroy] do
            delete :avatar, on: :member
          end
          resources :contact_inboxes, only: [] do
            collection do
              post :filter
            end
          end
          resources :assignable_agents, only: [:index]
          resource :audit_logs, only: [:show]
          resources :callbacks, only: [] do
            collection do
              post :register_facebook_page
              get :register_facebook_page
              post :facebook_pages
              post :reauthorize_page
            end
          end
          resources :canned_responses, only: [:index, :create, :update, :destroy]
          resources :tracking_templates, only: [:index, :show, :create, :update, :destroy] do # proyecto@tracking_templates
            collection do
              get :calendar_integrations
            end
          end
          resources :contact_tracking_imports, only: [:create] # proyecto@import_seguimiento

          # @knowledge_sources
          get    'knowledge_base/items',            to: 'knowledge_base#items'
          get    'knowledge_base/item_categories', to: 'knowledge_base#item_categories'
          get    'knowledge_base/sources',          to: 'knowledge_base#sources'
          post   'knowledge_base/sources',          to: 'knowledge_base#create_source'
          patch  'knowledge_base/sources/:id',      to: 'knowledge_base#update'
          delete 'knowledge_base/sources/:id',      to: 'knowledge_base#destroy'
          post   'knowledge_base/sources/:id/sync', to: 'knowledge_base#sync'
          post   'knowledge_base/search',           to: 'knowledge_base#search'
          post   'knowledge_base/discourse_categories', to: 'knowledge_base#discourse_categories'
          get    'knowledge_base/search_settings',  to: 'knowledge_base#search_settings'
          patch  'knowledge_base/search_settings',  to: 'knowledge_base#update_search_settings'
          resources :automation_rules, only: [:index, :create, :show, :update, :destroy] do
            post :clone
          end
          resources :macros, only: [:index, :create, :show, :update, :destroy] do
            post :execute, on: :member
          end
          resources :sla_policies, only: [:index, :create, :show, :update, :destroy]

          # =========================================================================
          # @tickets_cases — Gestor de Tickets
          # =========================================================================
          resources :case_tickets, only: [:index, :show, :create, :update] do
            collection do
              get :metrics
              get :kb_portals
            end
            member do
              patch :transition
              patch :assign
              patch :escalate
              patch :change_approval
              post :generate_article
              post :apply_ai_suggestion # @tickets_cases 3B
              delete :dismiss_ai_suggestion # @tickets_cases 3B
              post :suggest_reply # @tickets_cases 3C
              post :summarize # @tickets_cases 3E
              post :detect_duplicates # @tickets_cases 3D
              post :follow_up # @tickets_cases 3F
              patch :lock   # @tickets_cases — bloqueo de ticket
              patch :unlock # @tickets_cases — bloqueo de ticket
            end
            resources :case_events, only: [:index]
            # @tickets_cases 2E — relaciones entre tickets
            resources :case_ticket_relations, only: [:index, :create, :destroy], path: 'relations'
            # @tickets_cases — tareas/subtareas del ticket
            resources :case_tasks, only: [:index, :create, :update, :destroy], path: 'tasks'
          end
          resources :case_rules, only: [:index, :create, :update, :destroy]
          resources :case_types, only: [:index, :create, :update, :destroy] do
            resources :case_type_fields, only: [:index, :create, :update, :destroy], path: 'fields' # @tickets_cases 2K
          end
          resources :case_services, only: [:index, :create, :update, :destroy] # @tickets_cases 2B
          resources :case_categories, only: [:index, :create, :update, :destroy] # @tickets_cases 2B
          resources :case_sla_policies, only: [:index, :create, :update, :destroy] # @tickets_cases 2I
          resources :case_portals, only: [:index, :create, :update, :destroy] # @tickets_cases — User Portal
          resource  :case_setting, only: [:show, :update] # @tickets_cases — modo simple/ITIL
          resource  :case_folio_config, only: [:show, :update], controller: 'case_folio_configs'
          resource  :case_ai_config, only: [:show, :update], controller: 'case_ai_configs' # @tickets_cases 3A
          # =========================================================================
          resources :custom_roles, only: [:index, :create, :show, :update, :destroy]
          resources :campaigns, only: [:index, :create, :show, :update, :destroy]
          resources :dashboard_apps, only: [:index, :show, :create, :update, :destroy]
          namespace :channels do
            resource :twilio_channel, only: [:create]
          end
          # proyecto@waba_chatwoot
          namespace :whatsapp do
            resource :authorization, only: [:create]
          end

          # KANBAN0725
          namespace :conversations do
            resources :kanban, only: [] do
              collection do
                get :filter_by_kanban_type
                get :filter_by_kanban_process
                get :filter_by_both_kanban
              end
            end
          end
          # KANBAN0725

          resources :conversations, only: [:index, :create, :show, :update] do
            collection do
              get :meta
              get :search
              post :filter
              post :search_by_contacts  # proyecto@search_by_contacts - Search conversations by phone numbers and/or emails
              # KANBAN0725
              get :available_kanban_types 
              # KANBAN0725
            end
            scope module: :conversations do
              resources :messages, only: [:index, :create, :destroy] do
                member do
                  post :translate
                  post :forward
                  post :retry
                end
              end
              resources :assignments, only: [:create]
              resources :labels, only: [:create, :index]
              resource :participants, only: [:show, :create, :update, :destroy]
              resource :direct_uploads, only: [:create]
              resource :draft_messages, only: [:show, :update, :destroy]
            end
            member do
              post :mute
              post :unmute
              post :transcript
              post :toggle_status
              post :toggle_priority
              post :toggle_typing_status
              post :update_last_seen
              post :unread
              post :custom_attributes
              get :attachments
              # KANBAN0725
              patch :assign_kanban_type    
              patch :update_kanban_process
              patch :update_kanban_process_only     
              patch :bulk_update_kanban
              # KANBAN0725
            end
          end

          resources :search, only: [:index] do
            collection do
              get :conversations
              get :messages
              get :contacts
            end
          end

          resources :contacts, only: [:index, :show, :update, :create, :destroy] do
            collection do
              get :active
              get :search
              post :filter
              post :import
              post :export
            end
            member do
              get :contactable_inboxes
              post :destroy_custom_attributes
              delete :avatar
            end
            scope module: :contacts do
              resources :conversations, only: [:index]
              resources :contact_inboxes, only: [:create]
              resources :labels, only: [:create, :index]
              resources :notes
            end
              
            # =========================================================================
            # 🤖 SEGUIMIENTOS AUTOMÁTICOS CON IA - Contact Trackings
            # proyecto@contact_tracking v2.0
            # =========================================================================
            # Sistema de seguimientos programables con integración de IA para:
            # - Generación de mensajes contextuales con OpenAI (GPT-4o-mini)
            # - Soporte nativo para WhatsApp Cloud API con plantillas HSM
            # - Múltiples intentos automáticos con intervalos configurables
            # - Análisis de intención para reprogramación inteligente
            # - Estados del ciclo de vida completo del seguimiento
            # 
            # Estados disponibles:
            # - pending: Creado, esperando ejecución
            # - scheduled: Programado en cola de Sidekiq
            # - active: En proceso de ejecución
            # - paused: Pausado manualmente por el agente
            # - completed: Finalizado exitosamente
            # - cancelled: Cancelado por el agente
            # - failed: Falló en la ejecución
            # 
            # Endpoints disponibles:
            # -------------------------------------------------------------------------
            # GET    /api/v1/accounts/:account_id/contacts/:contact_id/contact_trackings
            #        Lista todos los seguimientos del contacto
            #        Params opcionales: ?conversation_id=X&status=pending&inbox_id=Y
            # 
            # POST   /api/v1/accounts/:account_id/contacts/:contact_id/contact_trackings
            #        Crea un nuevo seguimiento
            #        Body: { contact_tracking: { objective, scheduled_for, ... } }
            # 
            # PATCH  /api/v1/accounts/:account_id/contacts/:contact_id/contact_trackings/:id
            #        Actualiza un seguimiento existente
            # 
            # DELETE /api/v1/accounts/:account_id/contacts/:contact_id/contact_trackings/:id
            #        Elimina permanentemente un seguimiento
            # 
            # POST   /api/v1/accounts/:account_id/contacts/:contact_id/contact_trackings/:id/pause
            #        Pausa temporalmente la ejecución
            #        Útil cuando el cliente solicita espera o no está disponible
            # 
            # POST   /api/v1/accounts/:account_id/contacts/:contact_id/contact_trackings/:id/resume
            #        Reanuda un seguimiento pausado
            #        Continúa con los intentos restantes
            # 
            # POST   /api/v1/accounts/:account_id/contacts/:contact_id/contact_trackings/:id/cancel
            #        Cancela definitivamente el seguimiento
            #        Acción irreversible, usar cuando el seguimiento ya no aplica
            # 
            # Integración con servicios:
            # -------------------------------------------------------------------------
            # - OpenAI API: Generación de mensajes personalizados (AiFollowupService)
            # - WhatsApp Cloud API: Envío de mensajes y plantillas (WhatsappCloudService)
            # - Sidekiq: Ejecución programada de seguimientos (ContactTrackingJob)
            # - Sidekiq Cron: Jobs periódicos (ExecutePendingJob, CleanupJob)
            # 
            # Componentes frontend:
            # -------------------------------------------------------------------------
            # - ContactTrackingModal.vue: Modal de gestión en panel de contacto
            # - Store Vuex: contactTrackings (state management)
            # - API Client: contactTrackings.js (comunicación con backend)
            # - Filtrado automático por conversación e inbox actual
            # 
            # Jobs automáticos (Sidekiq):
            # -------------------------------------------------------------------------
            # - ContactTrackingJob: Ejecuta seguimientos individuales
            # - ExecutePendingJob: Busca y programa seguimientos pendientes (cada 5 min)
            # - CleanupJob: Limpia seguimientos completados antiguos (diario a las 3 AM)
            # 
            # Ejemplo de uso (crear seguimiento):
            # -------------------------------------------------------------------------
            # POST /api/v1/accounts/1/contacts/123/contact_trackings
            # Authorization: Bearer YOUR_ACCESS_TOKEN
            # Content-Type: application/json
            # 
            # {
            #   "contact_tracking": {
            #     "objective": "Seguimiento cotización plan premium",
            #     "scheduled_for": "2025-11-10T09:00:00Z",
            #     "max_attempts": 3,
            #     "interval_days": 2,
            #     "inbox_id": 1,
            #     "conversation_id": 456,
            #     "ai_context": "Cliente interesado en plan premium, presupuesto $5K, evaluando opciones"
            #   }
            # }
            # 
            # Respuesta exitosa:
            # {
            #   "id": 1,
            #   "contact_id": 123,
            #   "conversation_id": 456,
            #   "inbox_id": 1,
            #   "objective": "Seguimiento cotización plan premium",
            #   "scheduled_for": "2025-11-10T09:00:00Z",
            #   "max_attempts": 3,
            #   "attempt_count": 0,
            #   "interval_days": 2,
            #   "ai_context": "Cliente interesado en plan premium, presupuesto $5K",
            #   "status": "pending",
            #   "last_attempt_at": null,
            #   "last_message_sent": null,
            #   "created_at": "2025-01-07T10:00:00Z",
            #   "updated_at": "2025-01-07T10:00:00Z"
            # }
            # 
            # Documentación completa:
            # -------------------------------------------------------------------------
            # Backend: outputs/README.md
            # Frontend: outputs/FRONTEND_README.md
            # Instalación: outputs/INSTALACION_BACKEND_RAPIDA.md
            # Prompts IA: outputs/prompt_completo_y_optimizado_para_integrar_OpenAI.md
            # =========================================================================
            resources :contact_trackings, only: [:index, :show, :create, :update, :destroy] do
              collection do
                post :improve_text        # Mejorar texto con IA
              end
              member do
                post :pause   # Pausar temporalmente el seguimiento
                post :resume  # Reanudar seguimiento pausado
                post :cancel  # Cancelar definitivamente el seguimiento
              end
            end
            # =========================================================================
            # FIN: proyecto@contact_tracking v2.0
            # =========================================================================
            # =========================================================================
            # 📅 SEGUIMIENTOS AUTOMÁTICOS V2.00 - Contact Schedules
            # #SEGUIMIENTOS_V2.00
            # =========================================================================

            
          end
          resources :csat_survey_responses, only: [:index] do
            collection do
              get :metrics
              get :download
            end
          end
          resources :applied_slas, only: [:index] do
            collection do
              get :metrics
              get :download
            end
          end
          resources :custom_attribute_definitions, only: [:index, :show, :create, :update, :destroy]
          resources :custom_filters, only: [:index, :show, :create, :update, :destroy]
          resources :inboxes, only: [:index, :show, :create, :update, :destroy] do
            get :assignable_agents, on: :member
            get :campaigns, on: :member
            get :response_sources, on: :member
            get :agent_bot, on: :member
            post :set_agent_bot, on: :member
            delete :avatar, on: :member
          end
          resources :inbox_members, only: [:create, :show], param: :inbox_id do
            collection do
              delete :destroy
              patch :update
            end
          end
          resources :labels, only: [:index, :show, :create, :update, :destroy]
          resources :response_sources, only: [:create] do
            collection do
              post :parse
            end
            member do
              post :add_document
              post :remove_document
            end
          end

          resources :notifications, only: [:index, :update, :destroy] do
            collection do
              post :read_all
              get :unread_count
              post :destroy_all
            end
            member do
              post :snooze
              post :unread
            end
          end
          resource :notification_settings, only: [:show, :update]

          resources :teams do
            resources :team_members, only: [:index, :create] do
              collection do
                delete :destroy
                patch :update
              end
            end
          end

          namespace :twitter do
            resource :authorization, only: [:create]
          end

          namespace :microsoft do
            resource :authorization, only: [:create]
          end

          namespace :google do
            resource :authorization, only: [:create]
          end

          namespace :google_calendar do
            resource :authorization, only: [:create, :destroy]
            resources :events, only: [:index, :create, :update] do
              collection do
                get :agent_events
              end
            end
            resource :calendars, only: [:show, :update], controller: 'calendars' do
              collection do
                post :subscribe
              end
            end
            resource :availability, only: [:show], controller: 'availability'
            resource :sharing, only: [:create], controller: 'sharing'
          end

          resources :webhooks, only: [:index, :create, :update, :destroy]
          namespace :integrations do
            resources :apps, only: [:index, :show]
            resource :captain, controller: 'captain', only: [] do
              collection do
                get :sso_url
              end
            end
            resources :hooks, only: [:show, :create, :update, :destroy] do
              member do
                post :process_event
              end
            end
            resource :slack, only: [:create, :update, :destroy], controller: 'slack' do
              member do
                get :list_all_channels
              end
            end
            resource :dyte, controller: 'dyte', only: [] do
              collection do
                post :create_a_meeting
                post :add_participant_to_meeting
              end
            end
            resource :linear, controller: 'linear', only: [] do
              collection do
                get :teams
                get :team_entities
                post :create_issue
                post :link_issue
                post :unlink_issue
                get :search_issue
                get :linked_issues
              end
            end
          end

          #KANBAN0725
          resources :kanban_type_processes, path: 'kanban_processes' do
            resources :kanban_processes, path: 'kanban_type_processes' do
              collection do
                patch :bulk_reorder
              end
            end
          end
          #KANBAN0725

          resources :working_hours, only: [:update]

          resources :portals do
            member do
              patch :archive
              put :add_members
              delete :logo
            end
            resources :categories
            resources :articles do
              post :reorder, on: :collection
            end
          end

          resources :upload, only: [:create]
        end
      end
      # end of account scoped api routes
      # ----------------------------------

      namespace :integrations do
        resources :webhooks, only: [:create]
      end

      resource :profile, only: [:show, :update] do
        delete :avatar, on: :collection
        member do
          post :availability
          post :auto_offline
          put :set_active_account
          post :resend_confirmation
        end
      end

      resource :notification_subscriptions, only: [:create, :destroy]

      namespace :widget do
        resource :direct_uploads, only: [:create]
        resource :config, only: [:create]
        resources :campaigns, only: [:index]
        resources :events, only: [:create]
        resources :messages, only: [:index, :create, :update]
        resources :conversations, only: [:index, :create] do
          collection do
            post :destroy_custom_attributes
            post :set_custom_attributes
            post :update_last_seen
            post :toggle_typing
            post :transcript
            get  :toggle_status
          end
        end
        resource :contact, only: [:show, :update] do
          collection do
            post :destroy_custom_attributes
            patch :set_user
          end
        end
        resources :inbox_members, only: [:index]
        resources :labels, only: [:create, :destroy]
        namespace :integrations do
          resource :dyte, controller: 'dyte', only: [] do
            collection do
              post :add_participant_to_meeting
            end
          end
        end
      end
    end

    namespace :v2 do
      resources :accounts, only: [:create] do
        scope module: :accounts do
          resources :summary_reports, only: [] do
            collection do
              get :agent
              get :team
            end
          end
          resources :reports, only: [:index] do
            collection do
              get :summary
              get :bot_summary
              get :agents
              get :inboxes
              get :labels
              get :teams
              get :conversations
              get :conversation_traffic
              get :bot_metrics
            end
          end
        end
      end
    end
  end

  if ChatwootApp.enterprise?
    namespace :enterprise, defaults: { format: 'json' } do
      namespace :api do
        namespace :v1 do
          resources :accounts do
            member do
              post :checkout
              post :subscription
              get :limits
            end
          end
        end
      end

      post 'webhooks/stripe', to: 'webhooks/stripe#process_payload'
    end
  end

  # ----------------------------------------------------------------------
  # Routes for platform APIs
  namespace :platform, defaults: { format: 'json' } do
    namespace :api do
      namespace :v1 do
        resources :users, only: [:create, :show, :update, :destroy] do
          member do
            get :login
          end
        end
        resources :agent_bots, only: [:index, :create, :show, :update, :destroy] do
          delete :avatar, on: :member
        end
        resources :accounts, only: [:create, :show, :update, :destroy] do
          resources :account_users, only: [:index, :create] do
            collection do
              delete :destroy
            end
          end
        end
      end
    end
  end

  # ----------------------------------------------------------------------
  # Routes for inbox APIs Exposed to contacts
  namespace :public, defaults: { format: 'json' } do
    namespace :api do
      namespace :v1 do
        resources :inboxes do
          scope module: :inboxes do
            resources :contacts, only: [:create, :show, :update] do
              resources :conversations, only: [:index, :create, :show] do
                member do
                  post :toggle_status
                  post :toggle_typing
                  post :update_last_seen
                end

                resources :messages, only: [:index, :create, :update]
              end
            end
          end
        end

        resources :csat_survey, only: [:show, :update]
      end
    end
  end

  get 'hc/:slug', to: 'public/api/v1/portals#show'
  get 'hc/:slug/sitemap.xml', to: 'public/api/v1/portals#sitemap'
  get 'hc/:slug/:locale', to: 'public/api/v1/portals#show'
  get 'hc/:slug/:locale/articles', to: 'public/api/v1/portals/articles#index'
  get 'hc/:slug/:locale/categories', to: 'public/api/v1/portals/categories#index'
  get 'hc/:slug/:locale/categories/:category_slug', to: 'public/api/v1/portals/categories#show'
  get 'hc/:slug/:locale/categories/:category_slug/articles', to: 'public/api/v1/portals/articles#index'
  get 'hc/:slug/articles/:article_slug', to: 'public/api/v1/portals/articles#show'

  # ----------------------------------------------------------------------
  # @tickets_cases — User Portal (P1): superficie pública del cliente (estilo osTicket).
  # Se resuelve por slug (/portal/:slug). HTML server-rendered.
  get  'portal/:slug',         to: 'public/case_portal#show',   as: :case_portal
  get  'portal/:slug/new',     to: 'public/case_portal#new',    as: :new_case_portal_ticket
  post 'portal/:slug/tickets', to: 'public/case_portal#create', as: :case_portal_tickets
  get  'portal/:slug/status',  to: 'public/case_portal#status', as: :case_portal_status

  # ----------------------------------------------------------------------
  # Used in mailer templates
  resource :app, only: [:index] do
    resources :accounts do
      resources :conversations, only: [:show]
    end
  end

  # ----------------------------------------------------------------------
  # Routes for channel integrations
  mount Facebook::Messenger::Server, at: 'bot'
  get 'webhooks/twitter', to: 'api/v1/webhooks#twitter_crc'
  post 'webhooks/twitter', to: 'api/v1/webhooks#twitter_events'
  post 'webhooks/line/:line_channel_id', to: 'webhooks/line#process_payload'
  post 'webhooks/telegram/:bot_token', to: 'webhooks/telegram#process_payload'
  post 'webhooks/sms/:phone_number', to: 'webhooks/sms#process_payload'
  get 'webhooks/whatsapp/:phone_number', to: 'webhooks/whatsapp#verify'
  post 'webhooks/whatsapp/:phone_number', to: 'webhooks/whatsapp#process_payload'
  get 'webhooks/instagram', to: 'webhooks/instagram#verify'
  post 'webhooks/instagram', to: 'webhooks/instagram#events'
  namespace :twitter do
    resource :callback, only: [:show]
  end

  namespace :twilio do
    resources :callback, only: [:create]
    resources :delivery_status, only: [:create]
  end

  get 'microsoft/callback', to: 'microsoft/callbacks#show'
  get 'google/callback', to: 'google/callbacks#show'
  get 'google_calendar/callback', to: 'google_calendar_callback#show'

  # ----------------------------------------------------------------------
  # Routes for external service verifications
  get 'apple-app-site-association' => 'apple_app#site_association'
  get '.well-known/assetlinks.json' => 'android_app#assetlinks'
  get '.well-known/microsoft-identity-association.json' => 'microsoft#identity_association'

  # ----------------------------------------------------------------------
  # Internal Monitoring Routes
  require 'sidekiq/web'
  require 'sidekiq/cron/web'

  devise_for :super_admins, path: 'super_admin', controllers: { sessions: 'super_admin/devise/sessions' }
  devise_scope :super_admin do
    get 'super_admin/logout', to: 'super_admin/devise/sessions#destroy'
    namespace :super_admin do
      root to: 'dashboard#index'

      resource :app_config, only: [:show, :create]

      # order of resources affect the order of sidebar navigation in super admin
      resources :accounts, only: [:index, :new, :create, :show, :edit, :update, :destroy] do
        post :seed, on: :member
        post :reset_cache, on: :member
      end
      resources :users, only: [:index, :new, :create, :show, :edit, :update, :destroy] do
        delete :avatar, on: :member, action: :destroy_avatar
      end

      resources :access_tokens, only: [:index, :show]
      resources :response_sources, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
        get :chat, on: :member
        post :chat, on: :member, action: :process_chat
      end
      resources :response_documents, only: [:index, :show, :new, :create, :edit, :update, :destroy]
      resources :responses, only: [:index, :show, :new, :create, :edit, :update, :destroy]
      resources :installation_configs, only: [:index, :new, :create, :show, :edit, :update]
      resources :agent_bots, only: [:index, :new, :create, :show, :edit, :update] do
        delete :avatar, on: :member, action: :destroy_avatar
      end
      resources :platform_apps, only: [:index, :new, :create, :show, :edit, :update]
      resource :instance_status, only: [:show]

      resource :settings, only: [:show] do
        get :refresh, on: :collection
      end

      # resources that doesn't appear in primary navigation in super admin
      resources :account_users, only: [:new, :create, :destroy]
    end
    authenticated :super_admin do
      mount Sidekiq::Web => '/monitoring/sidekiq'
    end
  end

  namespace :installation do
    get 'onboarding', to: 'onboarding#index'
    post 'onboarding', to: 'onboarding#create'
  end

  # ---------------------------------------------------------------------
  # Routes for swagger docs
  get '/apidocs/*path', to: 'swagger#respond'
  get '/apidocs', to: 'swagger#respond'

  # ----------------------------------------------------------------------
  # Routes for testing
  resources :widget_tests, only: [:index] unless Rails.env.production?



  # Proyecto: DEV0001
  namespace :api do
    namespace :v1 do
      resources :accounts do
        scope module: :accounts do
          # Ruta para todos los mensajes programados de una cuenta
          resources :scheduled_messages, only: [:index]
          
          # Rutas para mensajes programados dentro de una conversación
          resources :conversations do
            resources :scheduled_messages, only: [:index, :create]
          end
          
          # Rutas para operaciones individuales de mensajes programados (show, update, destroy)
          # Estas rutas son "shallow" para no necesitar el conversation_id en estas operaciones
          resources :scheduled_messages, only: [:show, :update, :destroy]
        end
      end
    end
  end

  #KANBAN0725
  namespace :conversations do
    resources :kanban, only: [:index] do
      collection do
        get :filter_by_kanban_type
        get :filter_by_kanban_process
        get :filter_by_both_kanban
      end
    end
  end
  #KANBAN0725

end
