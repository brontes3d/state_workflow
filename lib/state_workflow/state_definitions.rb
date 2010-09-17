class StateWorkflow::StateDefinitions
  
  #Specify the name of the var/method to be available in validations for reference the thing on which these state apply
  def self.these_are_states_for(stateful_object_name)
    self.class_eval do
      cattr_accessor :stateful_object_name
    end
    self.stateful_object_name = stateful_object_name
  end
    
  #Specify the intial state that should be set on new instances of this object (State is expected to be required)
  def self.initial_state(initial_state_name)
    self.class_eval do
      cattr_accessor :initial_state_name
    end
    self.initial_state_name = initial_state_name    
  end
  
  def self.run_includes(on_class)
    on_class.class_eval do
      class << self
        include StateWorkflow::StatefulObjectClassMethods
      end
      include StateWorkflow::StatefulObjectInstanceMethods
    end
  end
  
  def self.definition_context_class
    StateWorkflow::State::DefinitionContext
  end
  
  #Define a new state
  def self.state(state_name, human_name = nil, &block)
    human_name_proc = nil
    if human_name
      human_name_proc = Proc.new{ human_name.to_s }
    elsif self.respond_to?(:display_proc_for_state_name)
      human_name_proc = Proc.new{ self.display_proc_for_state_name.call(state_name).to_s }
    else
      human_name_proc = Proc.new{ state_name.to_s.humanize }
    end
    self.class_eval do
      cattr_accessor :all_states
      cattr_accessor :states_in_order
    end
    self.all_states ||= {}
    self.states_in_order ||= []
    new_state = StateWorkflow::State.new(state_name.to_sym, human_name_proc, self)
    context = self.definition_context_class.new(new_state, @just_defined_state)
    context.instance_eval(&block)
    context.apply_to_state_definition!
    self.all_states[state_name.to_sym] = new_state
    self.states_in_order << new_state
    @just_defined_state = new_state
  end
  
  def self.non_workflow_state(state_name, human_name = nil, &block)
    state(state_name, human_name, &block)
    @just_defined_state.previous_state = nil
    @just_defined_state.next_state = nil
    @just_defined_state = nil
  end
  
  def self.display_name_for_state(&block)
    self.class_eval do
      cattr_accessor :display_proc_for_state_name
    end
    self.display_proc_for_state_name = block
  end

  def self.compose_validation_error_as(&block)
    self.class_eval do
      cattr_accessor :compose_proc_for_validation_errors
    end
    self.compose_proc_for_validation_errors = block
  end
    
end