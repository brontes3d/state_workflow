$:.unshift "#{File.dirname(__FILE__)}/lib"
require 'state_workflow'
require 'state_workflow/state'
require 'state_workflow/state_definitions'
require 'state_workflow/stateful_object_class_methods'
require 'state_workflow/stateful_object_instance_methods'

ActiveRecord::Base.class_eval do
  
  def self.state_workflow(state_def)
    self.class_eval do
      cattr_accessor :state_definitions
      self.state_definitions = state_def
      state_definitions.run_includes(self)
    end
  end
  
  class << self
  
    alias_method :orig_quote_bound_value, :quote_bound_value
    def quote_bound_value(value) #:nodoc:
      if value.is_a?(StateWorkflow::State)
        value = value.to_s
      end
      orig_quote_bound_value(value)
    end
  
  end
  
end
