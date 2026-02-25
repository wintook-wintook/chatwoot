# KANBAN0725-POLICY
# app/policies/kanban_process_policy.rb
class KanbanProcessPolicy < ApplicationPolicy
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
  
    def reorder?
      @user.administrator?
    end
  end