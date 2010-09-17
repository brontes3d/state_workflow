module StateWorkflow::StatefulObjectInstanceMethods
  
  def self.included(base)
    base.validate do |record|
      record.do_state_validation
    end
    base.class_eval do
      attr_accessor :state_validation_context
      after_save :run_entry_and_exit_blocks_after_save
      before_save :run_entry_and_exit_blocks_before_save
    end
  end
  
  def initial_state
    StateWorkflow::State::ReadyForAction.new(self, self.class.initial_state)    
  end
  
  def workflow_state_named(called, opts = {})
    StateWorkflow::State::ReadyForAction.new(self, self.class.state_named(called.to_sym, opts))
  end
  
  def workflow_state(called)
    StateWorkflow::State::ReadyForAction.new(self, self.class.state(called.to_sym))
  end
  
  def state_before(called)
    StateWorkflow::State::ReadyForAction.new(self, self.class.state_before(called.to_sym))
  end
  
  def state_after(called)
    StateWorkflow::State::ReadyForAction.new(self, self.class.state_after(called.to_sym))
  end
  
  def do_state_validation
    if current_state = self.state
      current_state.run_validation_blocks(self)
    end
  end
  
  def state=(val)
    state_to_set = self.class.state(val.to_s)
    self.write_attribute(:state, state_to_set.to_s)
    run_entry_and_exit_blocks(:on_assign)
  end
  
  def state
    if read_val = self.read_attribute(:state)
      if read_val.blank?
        nil
      else
        begin
          self.class.state(read_val.to_sym)
        rescue ArgumentError => e
          read_val.to_s
        end
      end
    end
  end
  
  def run_entry_and_exit_blocks_after_save
    run_entry_and_exit_blocks(:after_save)
  end
  def run_entry_and_exit_blocks_before_save
    run_entry_and_exit_blocks(:before_save)
  end
  
  def run_entry_and_exit_blocks(on_when)
    if state_change = self.changes['state']
      # STDERR.puts "state changed: " + state_change.inspect
      if state_before = self.class.state(state_change[0])
        state_before.run_on_exit_blocks(self, on_when)
      end
      if state_after = self.class.state(state_change[1])
        state_after.run_on_entry_blocks(self, on_when)
      end
      
      self.class.state_change_callbacks[on_when].each do |callback|
        callback.call(self, state_before, state_after)
      end
    end
  end
  
end