class BillStateDefinitions < StateWorkflow::StateDefinitions
  these_are_states_for :bill
  initial_state :writing
  
  state :writing do
    to_begin("lock for writing") {
      if bill.locked_by_user
        raise ArgumentError, "Bill is already locked by #{bill.locked_by_user.username}"
      else
        bill.locked_by_user = actor
        true
      end
    }
    to_finish("unlock") {
      bill.locked_by_user = nil
      true
    }
    validates("Must be Locked (by current user)"){
      bill.locked_by_user
    }
    validates("Bills can only be written by a congressman"){
      actor.user_type == "congressman"
    }
  end
  
  #state: written
  #introduced by a congressman
  state :ready_to_introduce, "Written / Ready to Introduce" do
    #... validates etc, can go in here, as they can in define state
    validates("Bill must have some content written"){
      not bill.contents.blank?
    }
  end
  
  #implcit state: 'introducing', but we don't ever need to make reference to it
  
  #action 'introduce'    
  state :ready_for_refer, "Introduced / Ready for Committee" do
    # to_begin{
    #   validates("Bill must be endorsed by some number of congressmen")
    # }
  end
    
    #action 'refer' 
    
    #state: in-commitee
    
    #committee considers
    #action 'consider'
    
    #state: in-congress
    
    #commitee reports back to congress
    #action 'report'
    
    #state: in-congress
    
    #bill is read and ammended
    #action 'amend'
    
    #state: ammeded
    
    #debated and voted on
    #action 'vote'
    
    #state: passed in congress
    
    #signed into law
    #action 'sign'
    
    #state: law
end

class UserStateDefinitionsTranslatable < StateWorkflow::StateDefinitions
  these_are_states_for :user
  
  display_name_for_state do |state_symbol|
    "At #{state_symbol.to_s}"
  end
  
  compose_validation_error_as do |validation_string, state_name|
    "Ain't no good to be #{state_name} cause #{validation_string}"
  end
  
  state :some_state do    
  end
  
  state :some_other_state, "Some Other state Is not translated because it is defined explicitly here" do
  end
  
  state :impossible_state do
    validates("Can't enter this state") do
      false
    end
  end
end

class User < ActiveRecord::Base
  state_workflow UserStateDefinitionsTranslatable
end

class Bill < ActiveRecord::Base
  state_workflow BillStateDefinitions
  
  belongs_to :locked_by_user, :class_name => "User", :foreign_key => 'locked_by_user_id'
end