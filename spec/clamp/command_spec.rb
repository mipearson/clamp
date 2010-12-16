require 'spec_helper'
require 'stringio'

describe Clamp::Command do

  include OutputCapture

  def self.given_command(name, &block)
    before do
      @command = Class.new(Clamp::Command, &block).new(name)
    end
  end

  given_command("cmd") do

    def execute
      puts "Hello, world"
    end

  end

  describe "#help" do

    it "describes usage" do
      @command.help.should include("Usage: cmd\n")
    end

  end

  describe "#run" do

    before do
      @command.run([])
    end

    it "executes the #execute method" do
      stdout.should_not be_empty
    end

  end

  describe ".option" do

    it "declares option argument accessors" do
      @command.class.option "--flavour", "FLAVOUR", "Flavour of the month"
      @command.flavour.should == nil
      @command.flavour = "chocolate"
      @command.flavour.should == "chocolate"
    end

    describe "with type :flag" do

      before do
        @command.class.option "--verbose", :flag, "Be heartier"
      end

      it "declares a predicate-style reader" do
        @command.should respond_to(:verbose?)
        @command.should_not respond_to(:verbose)
      end

    end
    
    describe "with explicit :attribute_name" do

      before do
        @command.class.option "--foo", "FOO", "A foo", :attribute_name => :bar
      end

      it "uses the specified attribute_name name to name accessors" do
        @command.bar = "chocolate"
        @command.bar.should == "chocolate"
      end

      it "does not attempt to create the default accessors" do
        @command.should_not respond_to(:foo)
        @command.should_not respond_to(:foo=)
      end

    end

    describe "with :default value" do

      given_command("cmd") do
        option "--nodes", "N", "number of nodes", :default => 2
      end

      it "sets the specified default value" do
        @command.nodes.should == 2
      end

      describe "#help" do
        
        it "describes the default value" do
          @command.help.should include("number of nodes (default: 2)")
        end
        
      end
      
    end

    describe "with a block" do

      before do
        @command.class.option "--port", "PORT", "Port to listen on" do |port|
          Integer(port)
        end
      end

      it "uses the block to validate and convert the option argument" do
        lambda do
          @command.port = "blah"
        end.should raise_error(ArgumentError)
        @command.port = "1234"
        @command.port.should == 1234
      end

    end

  end
  
  describe "with options declared" do

    before do
      @command.class.option ["-f", "--flavour"], "FLAVOUR", "Flavour of the month"
      @command.class.option ["-c", "--color"], "COLOR", "Preferred hue"
      @command.class.option ["-n", "--[no-]nuts"], :flag, "Nuts (or not)"
      @command.class.parameter "[ARG] ...", "extra arguments", :attribute_name => :arguments
    end

    describe "#parse" do

      describe "with an unrecognised option" do

        it "raises a UsageError" do
          lambda do
            @command.parse(%w(--foo bar))
          end.should raise_error(Clamp::UsageError)
        end

      end

      describe "with options" do

        before do
          @command.parse(%w(--flavour strawberry --nuts --color blue))
        end

        it "maps the option values onto the command object" do
          @command.flavour.should == "strawberry"
          @command.color.should == "blue"
          @command.nuts?.should == true
        end

      end

      describe "with short options" do

        before do
          @command.parse(%w(-f strawberry -c blue))
        end

        it "recognises short options as aliases" do
          @command.flavour.should == "strawberry"
          @command.color.should == "blue"
        end
        
      end

      describe "with combined short options" do

        before do
          @command.parse(%w(-nf strawberry))
        end

        it "works as though the options were separate" do
          @command.flavour.should == "strawberry"
          @command.nuts?.should == true
        end
        
      end
      
      describe "with option arguments attached using equals sign" do

        before do
          @command.parse(%w(--flavour=strawberry --color=blue))
        end

        it "works as though the option arguments were separate" do
          @command.flavour.should == "strawberry"
          @command.color.should == "blue"
        end
      
      end
      
      describe "with option-like things beyond the arguments" do

        it "treats them as positional arguments" do
          @command.parse(%w(a b c --flavour strawberry))
          @command.arguments.should == %w(a b c --flavour strawberry)
        end

      end

      describe "with an option terminator" do

        it "considers everything after the terminator to be an argument" do
          @command.parse(%w(--color blue -- --flavour strawberry))
          @command.arguments.should == %w(--flavour strawberry)
        end

      end

      describe "with --flag" do

        before do
          @command.parse(%w(--nuts))
        end

        it "sets the flag" do
          @command.nuts?.should be_true
        end

      end

      describe "with --no-flag" do

        before do
          @command.nuts = true
          @command.parse(%w(--no-nuts))
        end

        it "clears the flag" do
          @command.nuts?.should be_false
        end

      end

      describe "when option-writer raises an ArgumentError" do
        
        before do
          @command.class.class_eval do
            
            def color=(c)
              unless c == "black"
                raise ArgumentError, "sorry, we're out of #{c}"
              end
            end
            
          end
        end
          
        it "re-raises it as a UsageError" do
          lambda do
            @command.parse(%w(--color red))
          end.should raise_error(Clamp::UsageError, /^option '--color': sorry, we're out of red/)
        end

      end

    end

    describe "#help" do

      it "indicates that there are options" do
        @command.help.should include("cmd [OPTIONS]")
      end

      it "includes option details" do
        @command.help.should =~ %r(--flavour FLAVOUR +Flavour of the month)
        @command.help.should =~ %r(--color COLOR +Preferred hue)
      end

    end

  end

  describe ".parameter" do

    it "declares option argument accessors" do
      @command.class.parameter "FLAVOUR", "flavour of the month"
      @command.flavour.should == nil
      @command.flavour = "chocolate"
      @command.flavour.should == "chocolate"
    end

    describe "with explicit :attribute_name" do

      before do
        @command.class.parameter "FOO", "a foo", :attribute_name => :bar
      end

      it "uses the specified attribute_name name to name accessors" do
        @command.bar = "chocolate"
        @command.bar.should == "chocolate"
      end

    end

    describe "with a block" do

      before do
        @command.class.parameter "PORT", "port to listen on" do |port|
          Integer(port)
        end
      end

      it "uses the block to validate and convert the argument" do
        lambda do
          @command.port = "blah"
        end.should raise_error(ArgumentError)
        @command.port = "1234"
        @command.port.should == 1234
      end

    end

  end

  describe "with no parameters declared" do

    describe "#parse" do
    
      describe "with arguments" do
        
        it "raises a UsageError" do
          lambda do
            @command.parse(["crash"])
          end.should raise_error(Clamp::UsageError, "too many arguments")
        end
        
      end
      
    end
    
  end

  describe "with parameters declared" do
    
    before do
      @command.class.parameter "X", "x"
      @command.class.parameter "Y", "y"
      @command.class.parameter "[Z]", "z"
    end

    describe "#parse" do
      
      describe "with arguments for all parameters" do
        
        before do
          @command.parse(["crash", "bang", "wallop"])
        end

        it "maps arguments onto the command object" do
          @command.x.should == "crash"
          @command.y.should == "bang"
          @command.z.should == "wallop"
        end

      end

      describe "with insufficient arguments" do
        
        it "raises a UsageError" do
          lambda do
            @command.parse(["crash"])
          end.should raise_error(Clamp::UsageError, "parameter 'Y': no value provided")
        end
        
      end

      describe "with optional argument omitted" do

        it "defaults the optional argument to nil" do
          @command.parse(["crash", "bang"])
          @command.x.should == "crash"
          @command.y.should == "bang"
          @command.z.should == nil
        end
        
      end

      describe "with too many arguments" do
        
        it "raises a UsageError" do
          lambda do
            @command.parse(["crash", "bang", "wallop", "kapow"])
          end.should raise_error(Clamp::UsageError, "too many arguments")
        end
        
      end
      
    end
    
  end
  
  describe "with explicit usage" do

    given_command("blah") do

      usage "FOO BAR ..."

    end

    describe "#help" do

      it "includes the explicit usage" do
        @command.help.should include("blah FOO BAR ...\n")
      end

    end

  end

  describe "with multiple usages" do

    given_command("put") do

      usage "THIS HERE"
      usage "THAT THERE"

    end

    describe "#help" do

      it "includes both potential usages" do
        @command.help.should include("put THIS HERE\n")
        @command.help.should include("put THAT THERE\n")
      end

    end

  end

  describe "with a description" do

    given_command("punt") do

      self.description = <<-EOF
        Punt is an example command.  It doesn't do much, really.
        
        The prefix at the beginning of this description should be normalised
        to flush left.
      EOF
      
    end

    describe "#help" do

      it "includes the description" do
        @command.help.should =~ /^Punt is an example command/
        @command.help.should =~ /^The prefix/
      end

    end

  end
  describe ".run" do

    it "creates a new Command instance and runs it" do
      @command.class.class_eval do
        parameter "WORD ...", "words"
        def execute
          print word_list.inspect
        end
      end
      @xyz = %w(x y z)
      @command.class.run("cmd", @xyz)
      stdout.should == @xyz.inspect
    end

    describe "invoked with a context hash" do
      
      it "makes the context available within the command" do
        @command.class.class_eval do
          def execute
            print context[:foo]
          end
        end
        @command.class.run("xyz", [], :foo => "bar")
        stdout.should == "bar"        
      end
      
    end
    
    describe "when there's a UsageError" do

      before do

        @command.class.class_eval do
          def execute
            signal_usage_error "bad dog!"
          end
        end

        begin 
          @command.class.run("cmd", [])
        rescue SystemExit => e
          @system_exit = e
        end

      end

      it "outputs the error message" do
        stderr.should include "ERROR: bad dog!"
      end

      it "outputs help" do
        stderr.should include "See: 'cmd --help'"
      end

      it "exits with a non-zero status" do
        @system_exit.should_not be_nil
        @system_exit.status.should == 1
      end

    end

    describe "when help is requested" do

      it "outputs help" do
        @command.class.run("cmd", ["--help"])
        stdout.should include "Usage:"
      end

    end

  end

  describe "subclass" do
    
    before do
      @parent_command_class = Class.new(Clamp::Command) do
        option "--verbose", :flag, "be louder"
      end
      @derived_command_class = Class.new(@parent_command_class) do
        option "--iterations", "N", "number of times to go around"
      end
      @command = @derived_command_class.new("cmd")
    end
    
    it "inherits options from it's superclass" do
      @command.parse(["--verbose"])
      @command.should be_verbose
    end

  end
  
end
