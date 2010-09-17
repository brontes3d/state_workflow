class StateWorkflow::State
  
  class DefinitionContext
    attr_reader :state
    
    def initialize(state, state_just_defined)
      @state = state
      @validations = []
      @subsequent_state_validations = []
      @preceding_state_validations = []
      @begin_blocks = []
      @finish_blocks = []
      @reject_blocks = []
      @entry_blocks = []
      @exit_blocks = []
      @alternate_names = []
      if state_just_defined
        state_just_defined.next_state = @state
      end
      @state.previous_state = state_just_defined
    end
    
    def validates(validation_name, options = {}, &validation_proc)
      if options[:and_on_all_subsequent_states]
        @subsequent_state_validations << [validation_name, validation_proc]
      end
      if options[:and_on_all_preceding_states]
        @preceding_state_validations << [validation_name, validation_proc]
      end
      @validations << [validation_name, validation_proc]
    end
    
    def on_entry(name, when_run = :after_save, &block)
      @entry_blocks << [name, when_run, block]
    end

    def on_exit(name, when_run = :after_save, &block)
      @exit_blocks << [name, when_run, block]
    end
    
    def to_begin(name, when_run = :run_before_yield, &block)
      @begin_blocks << [name, when_run, block]
    end
    
    def to_finish(name, when_run = :run_before_yield, &block)
      @finish_blocks << [name, when_run, block]
    end
    
    def when_rejecting_to_here(name, when_run = :run_after_yield, &block)
      @reject_blocks << [name, when_run, block]
    end
    
    def alternate_name(name, options = {})
      @alternate_names << {:state => @state, :alternative_name => name}.merge(options)
    end
    
    def rejects_back_to(state_name)
      @rejects_back_to_state_named = state_name
    end
    
    def apply_to_state_definition!
      @state.begin_blocks = @begin_blocks
      @state.validations = @validations
      @state.subsequent_state_validations = @subsequent_state_validations
      @state.preceding_state_validations = @preceding_state_validations
      @state.finish_blocks = @finish_blocks
      @state.reject_blocks = @reject_blocks
      @state.on_entry_blocks = @entry_blocks
      @state.on_exit_blocks = @exit_blocks
      @state.alternate_state_names = @alternate_names
      if @rejects_back_to_state_named
        if reject_to_state = @state.definitions.all_states[@rejects_back_to_state_named.to_sym]
          @state.reject_to_state = reject_to_state
        else
          raise ArgumentError, "Can't set reject state to '#{@rejects_back_to_state_named}', no such state"
        end
      else
        @state.reject_to_state = @state.previous_state
      end
    end
  end
  
  class EvalContext
    attr_accessor :stateful_object
    def initialize(stateful_object, definition)
      stateful_object_name = definition.stateful_object_name
      self.stateful_object = stateful_object
      make_accessor(stateful_object_name, stateful_object)
    end
    
    # define a method _called_ only on this instance of the context
    # that method should return the object: with_object
    def make_accessor(called, with_object)
      class << self
        self
      end.send(:define_method, called.to_s) do
        with_object
      end
    end
  end
  
  class ReadyForAction
    def initialize(stateful_object, state_def)
      @stateful_object = stateful_object
      @state_def = state_def
      @stateful_object.state_validation_context = EvalContext.new(stateful_object, state_def.definitions)
    end
    
    def begin_or_continue!(locals = {})
      if @stateful_object.state == @state_def.previous_state
        begin!(locals)
      elsif @stateful_object.state == @state_def
        continue!(locals)
      else
        raise ArgumentError, "Cannot begin or continue '#{@state_def}' without first being '#{@state_def.previous_state}' or '#{@state_def}'"
      end
    end
    
    def begin!(locals = {})
      locals.each do |key, value|
        @stateful_object.state_validation_context.make_accessor(key.to_sym, value)
      end
      
      #check that the current state of stateful object is the one that comes before this state
      unless @stateful_object.state == @state_def.previous_state
        raise ArgumentError, "Cannot finish '#{@state_def.previous_state}' and begin '#{@state_def}' without first being '#{@state_def.previous_state}'"
      end
      
      #run finish actions on the previous state
      if @state_def.previous_state
        @state_def.previous_state.run_finish_blocks(@stateful_object, :run_before_yield)
      end
      
      #run begin actions on the new state
      @state_def.run_begin_blocks(@stateful_object, :run_before_yield)
      
      #set the new state
      @stateful_object.state = @state_def
      
      yield if block_given?
      
      #run finish actions on the previous state
      if @state_def.previous_state
        @state_def.previous_state.run_finish_blocks(@stateful_object, :run_after_yield)
      end
      
      #run begin actions on the new state
      @state_def.run_begin_blocks(@stateful_object, :run_after_yield)
      
      @stateful_object.save!
    end
    
    def continue!(locals = {})
      locals.each do |key, value|
        @stateful_object.state_validation_context.make_accessor(key.to_sym, value)
      end
      
      #check that the current state of stateful object is the same as the state to continue
      unless @stateful_object.state == @state_def
        raise ArgumentError, "Cannot continue '#{@state_def}' without already being '#{@state_def}'"
      end
      
      yield if block_given?
      @stateful_object.save!
    end
    
    def finish!(locals = {}, &block)
      @stateful_object.workflow_state(@state_def.next_state.to_s).begin!(locals, &block)      
      
      # locals.each do |key, value|
      #   @stateful_object.state_validation_context.make_accessor(key.to_sym, value)
      # end
      # 
      # #check that the current state of stateful object is the same as the state asked to finish
      # unless @stateful_object.state == @state_def
      #   raise ArgumentError, "Cannot finish #{@state_def} without already being #{@state_def}"
      # end
      # 
      # #run finish actions on this state state
      # @state_def.run_finish_blocks(@stateful_object)
      # 
      # #run begin actions on the next state
      # if @state_def.next_state
      #   @state_def.next_state.run_begin_blocks(@stateful_object)
      # end
      # 
      # #set to the new state
      # @stateful_object.state = @state_def.next_state      
      # 
      # yield if block_given?
      # @stateful_object.save!
    end
    
    def reject!(locals = {})
      locals.each do |key, value|
        @stateful_object.state_validation_context.make_accessor(key.to_sym, value)
      end
      
      #check that the current state of stateful object is the same as the state asked to reject from
      unless @stateful_object.state == @state_def
        raise ArgumentError, "Cannot reject from '#{@state_def}' without already being '#{@state_def}'"
      end
      
      #run reject actions on this state state
      @state_def.reject_to_state.run_reject_blocks(@stateful_object, :run_before_yield)
      
      #set to the new state
      @stateful_object.state = @state_def.reject_to_state
      
      yield if block_given?

      #run reject actions on this state state
      @state_def.reject_to_state.run_reject_blocks(@stateful_object, :run_after_yield)

      @stateful_object.save!
    end
        
  end
  
  attr_reader :db_name
  attr_reader :human_name_proc
  attr_reader :definitions
  
  attr_accessor :next_state
  attr_accessor :previous_state
  attr_accessor :reject_to_state

  attr_accessor :begin_blocks
  attr_accessor :validations
  attr_accessor :subsequent_state_validations
  attr_accessor :preceding_state_validations
  attr_accessor :finish_blocks
  attr_accessor :reject_blocks
  attr_accessor :on_exit_blocks
  attr_accessor :on_entry_blocks
  attr_accessor :alternate_state_names
  
  def initialize(db_name, human_name_proc, definitions)
    @db_name = db_name
    @human_name_proc = human_name_proc
    @definitions = definitions
  end
  
  def human_name
    self.human_name_proc.call
  end
  
  def terminal?
    self.next_state.nil?
  end
  
  def previous_states
    if self.previous_state
      [self.previous_state] + self.previous_state.previous_states
    else
      []
    end
  end
  
  def next_states
    if self.next_state
      [self.next_state] + self.next_state.next_states
    else
      []
    end
  end
  
  def all_validations
    to_return = self.validations.dup
    previous_states.each do |pvs|
      to_return += pvs.subsequent_state_validations
    end
    next_states.each do |nxs|
      to_return += nxs.preceding_state_validations
    end
    to_return
  end
  
  def to_s
    self.db_name.to_s
  end
  
  def to_sym
    self.db_name.to_sym
  end
  
  def inspect
    "#<StateWorkflow::State (#{db_name}) '#{human_name}'"+
    " --next:#{next_state && next_state.db_name}"+
    " --previous:#{previous_state && previous_state.db_name}>"
  end
  
  def run_begin_blocks(on_object, for_when)
    (self.begin_blocks || []).each do |name, when_run, block|
      if for_when == when_run
        on_object.state_validation_context.instance_eval(&block)
      end
    end
  end
  
  def run_finish_blocks(on_object, for_when)
    (self.finish_blocks || []).each do |name, when_run, block|
      if for_when == when_run
        on_object.state_validation_context.instance_eval(&block)
      end
    end
  end
  
  def run_reject_blocks(on_object, for_when)
    (self.reject_blocks || []).each do |name, when_run, block|
      if for_when == when_run
        on_object.state_validation_context.instance_eval(&block)
      end
    end
  end
    
  def run_on_exit_blocks(on_object, for_when)
    on_object.state_validation_context ||= EvalContext.new(on_object, self.definitions)
    (self.on_exit_blocks || []).each do |name, when_run, block|
      if for_when == when_run
        on_object.state_validation_context.instance_eval(&block)
      end
    end
  end

  def run_on_entry_blocks(on_object, for_when)
    on_object.state_validation_context ||= EvalContext.new(on_object, self.definitions)
    (self.on_entry_blocks || []).each do |name, when_run, block|
      if for_when == when_run
        on_object.state_validation_context.instance_eval(&block)
      end
    end
  end

  def run_validation_blocks(on_object)
    on_object.state_validation_context ||= EvalContext.new(on_object, self.definitions)
    (self.all_validations || []).each do |validation_message, block|
      unless on_object.state_validation_context.instance_eval(&block)
        error_message = 
          if self.definitions.respond_to?(:compose_proc_for_validation_errors)
            self.definitions.compose_proc_for_validation_errors.call(validation_message, on_object.state.human_name)
          else
            "Cannot be #{on_object.state.human_name}, #{validation_message}"
          end
        on_object.errors.add(:state, error_message)
      end
    end
  end
  
  def >=(other_state)
    self.on_or_after?(other_state)    
  end
  
  def on_or_after?(other_state)
    all_states = self.definitions.states_in_order
    all_states.index(self) >= all_states.index(other_state)
  end
  
  def <=(other_state)
    self.on_or_before?(other_state)
  end
  
  def on_or_before?(other_state)
    all_states = self.definitions.states_in_order
    all_states.index(self) <= all_states.index(other_state)
  end
  
  def <(other_state)
    self.is_before?(other_state)
  end
  
  def is_before?(other_state)
    all_states = self.definitions.states_in_order
    all_states.index(self) < all_states.index(other_state)
  end
  
  def >(other_state)
    self.is_after?(other_state)
  end
  
  def is_after?(other_state)
    all_states = self.definitions.states_in_order
    all_states.index(self) > all_states.index(other_state)
  end
  
  def is_between?(starting_state, ending_state)
    all_states = self.definitions.states_in_order
    if self.is_after?(starting_state) && self.is_before?(ending_state)
      true
    else
      false
    end
  end
  
  def all_states_before
    self.definitions.states_in_order.reject {|state| state.on_or_after?(self)}
  end
  
  def all_states_after
    self.definitions.states_in_order.reject {|state| state.on_or_before?(self)}
  end

  def all_states_from_this_through(ending_state)
    [self] + all_states_after.reject {|state| state.is_after?(ending_state)}
  end
  
  def all_states_between_this_and(ending_state)
    all_states_after.reject {|state| state.on_or_after?(ending_state)}
  end
  
  def to_yaml(*args)
    self.to_s.to_yaml(*args)
  end
  
  def to_json(*args)
    self.to_s.to_json(*args)
  end
  
end
