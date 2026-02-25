# KANBAN0725-POLICY
# app/policies/kanban_type_process_policy.rb
class KanbanTypeProcessPolicy < ApplicationPolicy
    def index?
      @user.administrator? || @user.agent?
    end
  
    def show?
      @user.administrator? || @user.agent?
    end
  
    def create?
      @user.administrator?
    end
  
    def update?
      @user.administrator?
    end
  
    def destroy?
      @user.administrator?
    end

    def conversation_kanban_info?
      # Mismos permisos que para ver un kanban type process
      show?
    end
  end