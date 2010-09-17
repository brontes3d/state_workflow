module StateWorkflow::StatefulObjectClassMethods
  
  def hash_of_states
    self.state_definitions.all_states
  end

  def all_states
    self.state_definitions.states_in_order
  end

  def all_workflow_states
    self.all_states.reject{ |state| state.previous_state.nil? && state.next_state.nil? }
  end
  
  def all_state_names
    self.all_states.collect{ |state| state.db_name }
  end
  
  def state_names_from_to(from_name, to_name)
    nams = all_state_names
    to_return = []
    in_range = false
    nams.each do |nam|
      if nam.to_s == from_name.to_s
        in_range = true
      end
      if in_range
        to_return << nam
      end
      if nam.to_s == to_name.to_s
        in_range = false
      end
    end
    to_return
  end
  
  def all_state_human_names
    self.all_states.collect{ |state| state.human_name }
  end

  def all_state_name_pairs_for_html_select
    self.all_states.collect do |state|
      [state.human_name, state.db_name]
    end
  end
  
  def all_state_name_pairs
    self.all_states.collect do |state|
      [state.db_name, state.human_name]
    end
  end
  
  def alternate_state_names
    all_states.collect{ |st| st.alternate_state_names }.flatten
  end
  
  def state_named(named, options = {})
    alternate_state_names.each do |alt_name_hash|
      if alt_name_hash[:alternative_name].to_s == named.to_s
        all_opts_match = true
        options.each do |key, value|
          unless alt_name_hash[key] == value
            all_opts_match = false
          end
        end
        if all_opts_match
          return alt_name_hash[:state]
        end
      end
    end
    #if nothing was found (returned), then nil
    nil
  end
  
  def state(called)
    if called.blank?
      nil
    else
      hash_of_states[called.to_sym] or (raise ArgumentError.new("No states on #{self} are called '#{called}'"))
    end
  end
  
  def state_range(from, to)
    self.state(from).all_states_from_this_through(self.state(to))
  end
  
  def state_before(called)
    state(called).previous_state
  end

  def state_after(called)
    state(called).next_state
  end
  
  def reject_state_for(called)
    state(called).reject_to_state
  end
  
  def initial_state
    state(self.state_definitions.initial_state_name)
  end
  
  def state_change_callbacks
    @state_change_callbacks ||= {:after_save => [], :before_save => [], :on_assign => []}
  end
  
  def clear_state_change_callbacks!
    @state_change_callbacks = nil
    self.state_change_callbacks
  end
  
  def register_state_change_callback(on_type_of_change, &block)
    self.state_change_callbacks[on_type_of_change] << block
  end
  
end