require 'test/unit'
require 'rubygems'
require 'active_record'

require "#{File.dirname(__FILE__)}/my_paramix.rb"

RAILS_ENV = 'test' unless defined?(RAILS_ENV)

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")

#require this plugin
require "#{File.dirname(__FILE__)}/../init"

class StateWorkflowTest < Test::Unit::TestCase

  @@already_setup = false
  def setup
    unless @@already_setup
      #load the database schema for this test
      load File.expand_path(File.dirname(__FILE__) + "/mocks/schema.rb")
      #require the mock models for this test
      require File.expand_path(File.dirname(__FILE__) + '/mocks/models.rb')
      @@already_setup = true
    end
    Bill.clear_state_change_callbacks!
  end
  
  def test_state_human_names
    assert_equal("Written / Ready to Introduce", Bill.state(:ready_to_introduce).human_name)
    assert_equal("Writing", Bill.state(:writing).human_name)
    
    assert_equal("Some Other state Is not translated because it is defined explicitly here", User.state(:some_other_state).human_name)
    assert_equal("At some_state", User.state(:some_state).human_name)
  end
    
  def write_bill(bill)
    user = User.new
    user.username = "boo"
    user.user_type = "congressman"
    user.save!    
    bill.initial_state.begin!(:actor => user) do
      bill.contents = "hi"
    end
    bill.workflow_state(:writing).finish!(:actor => user)
  end
    
  def test_register_for_notification_of_state_changes
    bill = Bill.new
    write_bill(bill)

    @on_assign_runs = 0
    Bill.register_state_change_callback(:on_assign) do |b, from_state, to_state|
      @on_assign_runs += 1
      assert_equal(bill, b)
      assert_equal(Bill.state(:ready_to_introduce), from_state)
      assert_equal(Bill.state(:ready_for_refer), to_state)
    end
    @before_save_runs = 0
    Bill.register_state_change_callback(:before_save) do |b, from_state, to_state|
      @before_save_runs += 1
    end
    @after_save_runs = 0
    Bill.register_state_change_callback(:after_save) do |b, from_state, to_state|
      @after_save_runs += 1
    end
    
    bill.state = Bill.state(:ready_for_refer)
    assert_equal(1, @on_assign_runs)

    bill.save!
    assert_equal(1, @before_save_runs)
    assert_equal(1, @after_save_runs)    
  end
  
  def test_impossible_state_validates_translatable
    user = User.new
    user.username = "boo"
    user.state = User.state(:impossible_state)
    user.user_type = "congressman"
    
    assert_raises(ActiveRecord::RecordInvalid){    
      user.save!
    }
    assert_equal("Ain't no good to be At impossible_state cause Can't enter this state", user.errors.on(:state))
  end
  
  
  def test_validates
    # puts Bill.all_state_names.inspect
    # puts Bill.all_state_human_names.inspect
    # puts Bill.all_state_name_pairs.inspect
    
    user = User.new
    user.username = "boo"
    user.user_type = "congressman"
    user.save!
    bill = Bill.new
    bill.initial_state.begin!(:actor => user)
    bill = Bill.find(bill.id)
    
    assert_raises(ActiveRecord::RecordInvalid){
      bill.workflow_state(:ready_to_introduce).begin!(:actor => user)      
    }
    assert_equal("Cannot be Written / Ready to Introduce, Bill must have some content written", bill.errors.on(:state))
  end
  
  def test_basic_state_methods
    user = User.new
    user.username = "boo"
    user.user_type = "congressman"
    user.save!
    
    assert_equal(nil, Bill.state_before(:writing))
    assert_equal(Bill.state(:ready_to_introduce), Bill.state_after(:writing))
    assert_equal(Bill.state(:writing), Bill.state_before(:ready_to_introduce))
    
    bill = Bill.new
    
    assert_equal(Bill.state(:writing), Bill.initial_state)
    
    assert_equal(nil, bill.state)
    
    bill.initial_state.begin!(:actor => user) do
      assert_equal(Bill.state(:writing), bill.state)
    end
    
    assert_equal(Bill.state(:writing), bill.state)
    bill.save!
    bill.reload
    assert_equal(Bill.state(:writing), bill.state)    
  end
  
  def test_write_state
    bill = Bill.new
    user = User.new
    user.username = "boo"
    user.user_type = "congressman"
    user.save!
      
    #bill should be in the nil state
    assert_equal(nil, bill.state)
    
    bill.workflow_state(:writing).begin!(:actor => user) do
      bill.contents = %Q{
        This is going to be the best law EVER!
      }     
    end
        
    #bill should be in the writing state
    assert_equal(Bill.state(:writing), bill.state)
    
    bill.workflow_state(:writing).continue!(:actor => user) do
      bill.contents = %Q{
        Second cousins of people named John shall be exempt from sales tax on articles of clothing purchased during full moons.
      }
    end
      
    #bill should be in the writing state
    assert_equal(Bill.state(:writing), bill.state)
    
    bill.workflow_state(:writing).finish!(:actor => user)
    
    #bill should be in the ready_to_introduce state
    assert_equal(Bill.state(:ready_to_introduce), bill.state)
    
  end
  
  def test_before_and_afters
    middle_state = Bill.state(:ready_to_introduce)
    assert middle_state.is_after?(Bill.state(:writing))
    assert !middle_state.is_after?(Bill.state(:ready_for_refer))
    assert middle_state.is_before?(Bill.state(:ready_for_refer))
    assert !middle_state.is_before?(Bill.state(:writing))
    assert middle_state.is_between?(Bill.state(:writing),Bill.state(:ready_for_refer))
    first_state = Bill.state(:writing)
    last_state = Bill.state(:ready_for_refer)
    assert_equal [first_state,middle_state], last_state.all_states_before, "there is a problem with all_states_before"
    assert_equal [middle_state,last_state], first_state.all_states_after, "there is a problem with all_states_after"
    assert_equal [middle_state], first_state.all_states_between_this_and(Bill.state(:ready_for_refer)), "there is a problem with all_states_between_this_and"
  end

end
