# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Style::ConditionalAssignment do
  subject(:cop) { described_class.new(config) }

  let(:config) do
    RuboCop::Config.new('Style/ConditionalAssignment' => {
                          'Enabled' => true,
                          'SingleLineConditionsOnly' => true,
                          'IncludeTernaryExpressions' => true,
                          'EnforcedStyle' => 'assign_to_condition',
                          'SupportedStyles' => %w[assign_to_condition
                                                  assign_inside_condition]
                        },
                        'Layout/EndAlignment' => {
                          'EnforcedStyleAlignWith' => end_alignment_align_with,
                          'Enabled' => true
                        },
                        'Metrics/LineLength' => {
                          'Max' => 80,
                          'Enabled' => true
                        })
  end

  let(:end_alignment_align_with) { 'start_of_line' }

  it 'counts array assignment when determining multiple assignment' do
    expect_no_offenses(<<~RUBY)
      if foo
        array[1] = 1
        a = 1
      else
        array[1] = 2
        a = 2
      end
    RUBY
  end

  it 'allows method calls in conditionals' do
    expect_no_offenses(<<~RUBY)
      if line.is_a?(String)
        expect(actual[ix]).to eq(line)
      else
        expect(actual[ix]).to match(line)
      end
    RUBY
  end

  it 'allows if else without variable assignment' do
    expect_no_offenses(<<~RUBY)
      if foo
        1
      else
        2
      end
    RUBY
  end

  it 'allows assignment to the result of a ternary operation' do
    expect_no_offenses('bar = foo? ? "a" : "b"')
  end

  it 'registers an offense for assignment in ternary operation' do
    expect_offense(<<~RUBY)
      foo? ? bar = "a" : bar = "b"
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use the return of the conditional for variable assignment and comparison.
    RUBY
  end

  it 'allows modifier if' do
    expect_no_offenses('return if a == 1')
  end

  it 'allows modifier if inside of if else' do
    expect_no_offenses(<<~RUBY)
      if foo
        a unless b
      else
        c unless d
      end
    RUBY
  end

  it "doesn't crash when assignment statement uses chars which have " \
     'special meaning in a regex' do
    # regression test; see GH issue 2876
    expect_offense(<<~RUBY)
      if condition
      ^^^^^^^^^^^^ Use the return of the conditional for variable assignment and comparison.
        default['key-with-dash'] << a
      else
        default['key-with-dash'] << b
      end
    RUBY
  end

  it "doesn't crash with empty braces" do
    expect_no_offenses(<<~RUBY)
      if condition
        ()
      else
        ()
      end
    RUBY
  end

  shared_examples 'comparison methods' do |method|
    it 'registers an offense for comparison methods in if else' do
      expect_offense(<<~RUBY)
        if foo
        ^^^^^^ Use the return of the conditional for variable assignment and comparison.
          a #{method} b
        else
          a #{method} d
        end
      RUBY
    end

    it 'registers an offense for comparison methods in unless else' do
      expect_offense(<<~RUBY)
        unless foo
        ^^^^^^^^^^ Use the return of the conditional for variable assignment and comparison.
          a #{method} b
        else
          a #{method} d
        end
      RUBY
    end

    it 'registers an offense for comparison methods in case when' do
      expect_offense(<<~RUBY)
        case foo
        ^^^^^^^^ Use the return of the conditional for variable assignment and comparison.
        when bar
          a #{method} b
        else
          a #{method} d
        end
      RUBY
    end
  end

  it_behaves_like('comparison methods', '==')
  it_behaves_like('comparison methods', '!=')
  it_behaves_like('comparison methods', '=~')
  it_behaves_like('comparison methods', '!~')
  it_behaves_like('comparison methods', '<=>')

  context 'empty branch' do
    it 'allows an empty if statement' do
      expect_no_offenses(<<~RUBY)
        if foo
          # comment
        else
          do_something
        end
      RUBY
    end

    it 'allows an empty elsif statement' do
      expect_no_offenses(<<~RUBY)
        if foo
          bar = 1
        elsif baz
          # empty
        else
          bar = 2
        end
      RUBY
    end

    it 'allows if elsif without else' do
      expect_no_offenses(<<~RUBY)
        if foo
          bar = 'some string'
        elsif bar
          bar = 'another string'
        end
      RUBY
    end

    it 'allows assignment in if without an else' do
      expect_no_offenses(<<~RUBY)
        if foo
          bar = 1
        end
      RUBY
    end

    it 'allows assignment in unless without an else' do
      expect_no_offenses(<<~RUBY)
        unless foo
          bar = 1
        end
      RUBY
    end

    it 'allows assignment in case when without an else' do
      expect_no_offenses(<<~RUBY)
        case foo
        when "a"
          bar = 1
        when "b"
          bar = 2
        end
      RUBY
    end

    it 'allows an empty when branch with an else' do
      expect_no_offenses(<<~RUBY)
        case foo
        when "a"
          # empty
        when "b"
          bar = 2
        else
          bar = 3
        end
      RUBY
    end

    it 'allows case with an empty else' do
      expect_no_offenses(<<~RUBY)
        case foo
        when "b"
          bar = 2
        else
          # empty
        end
      RUBY
    end
  end

  it 'allows assignment of different variables in if else' do
    expect_no_offenses(<<~RUBY)
      if foo
        bar = 1
      else
        baz = 1
      end
    RUBY
  end

  it 'allows method calls in if else' do
    expect_no_offenses(<<~RUBY)
      if foo
        bar
      else
        baz
      end
    RUBY
  end

  it 'allows if elsif else with the same assignment only in if else' do
    expect_no_offenses(<<~RUBY)
      if foo
        bar = 1
      elsif foobar
        baz = 2
      else
        bar = 1
      end
    RUBY
  end

  it 'allows if elsif else with the same assignment only in if elsif' do
    expect_no_offenses(<<~RUBY)
      if foo
        bar = 1
      elsif foobar
        bar = 2
      else
        baz = 1
      end
    RUBY
  end

  it 'allows if elsif else with the same assignment only in elsif else' do
    expect_no_offenses(<<~RUBY)
      if foo
        bar = 1
      elsif foobar
        baz = 2
      else
        baz = 1
      end
    RUBY
  end

  it 'allows assignment using different operators in if else' do
    expect_no_offenses(<<~RUBY)
      if foo
        bar = 1
      else
        bar << 2
      end
    RUBY
  end

  it 'allows assignment using different (method) operators in if..else' do
    expect_no_offenses(<<~RUBY)
      if foo
        bar[index] = 1
      else
        bar << 2
      end
    RUBY
  end

  it 'allows aref assignment with different indices in if..else' do
    expect_no_offenses(<<~RUBY)
      if foo
        bar[1] = 1
      else
        bar[2] = 2
      end
    RUBY
  end

  it 'allows assignment using different operators in if elsif else' do
    expect_no_offenses(<<~RUBY)
      if foo
        bar = 1
      elsif foobar
        bar += 2
      else
        bar << 3
      end
    RUBY
  end

  it 'allows assignment of different variables in case when else' do
    expect_no_offenses(<<~RUBY)
      case foo
      when "a"
        bar = 1
      else
        baz = 2
      end
    RUBY
  end

  it 'registers an offense in an if else if the assignment is already ' \
    'at the line length limit' do
    expect_offense(<<~RUBY)
      if foo
      ^^^^^^ Use the return of the conditional for variable assignment and comparison.
        bar = #{'a' * 72}
      else
        bar = #{'b' * 72}
      end
    RUBY
  end

  context 'correction would exceed max line length' do
    it 'allows assignment to the same variable in if else if the correction ' \
       'would create a line longer than the configured LineLength' do
      expect_no_offenses(<<~RUBY)
        if foo
          #{'a' * 78}
          bar = 1
        else
          bar = 2
        end
      RUBY
    end

    it 'allows assignment to the same variable in if else if the correction ' \
       'would cause the condition to exceed the configured LineLength' do
      expect_no_offenses(<<~RUBY)
        if #{'a' * 78}
          bar = 1
        else
          bar = 2
        end
      RUBY
    end

    it 'allows assignment to the same variable in case when else if the ' \
       'correction would create a line longer than the configured LineLength' do
      expect_no_offenses(<<~RUBY)
        case foo
        when foobar
          #{'a' * 78}
          bar = 1
        else
          bar = 2
        end
      RUBY
    end
  end

  shared_examples 'all variable types' do |variable|
    it 'registers an offense assigning any variable type in ternary' do
      source = "foo? ? #{variable} = 1 : #{variable} = 2"
      highlight = '^' * source.length
      expect_offense(<<~RUBY)
        #{source}
        #{highlight} Use the return of the conditional for variable assignment and comparison.
      RUBY
    end

    it 'registers an offense assigning any variable type in if else' do
      expect_offense(<<~RUBY)
        if foo
        ^^^^^^ Use the return of the conditional for variable assignment and comparison.
          #{variable} = 1
        else
          #{variable} = 2
        end
      RUBY
    end

    it 'registers an offense assigning any variable type in case when' do
      expect_offense(<<~RUBY)
        case foo
        ^^^^^^^^ Use the return of the conditional for variable assignment and comparison.
        when "a"
          #{variable} = 1
        else
          #{variable} = 2
        end
      RUBY
    end

    it 'allows assignment to the return of if else' do
      expect_no_offenses(<<~RUBY)
        #{variable} = if foo
                        1
                      else
                        2
                      end
      RUBY
    end

    it 'allows assignment to the return of case when' do
      expect_no_offenses(<<~RUBY)
        #{variable} = case foo
                      when bar
                        1
                      else
                        2
                      end
      RUBY
    end

    it 'allows assignment to the return of a ternary' do
      expect_no_offenses(<<~RUBY)
        #{variable} = foo? ? 1 : 2
      RUBY
    end
  end

  it_behaves_like('all variable types', 'bar')
  it_behaves_like('all variable types', 'BAR')
  it_behaves_like('all variable types', 'FOO::BAR')
  it_behaves_like('all variable types', '@bar')
  it_behaves_like('all variable types', '@@bar')
  it_behaves_like('all variable types', '$BAR')
  it_behaves_like('all variable types', 'foo.bar')

  shared_examples 'all assignment types' do |assignment|
    let(:end_alignment_align_with) { 'keyword' }

    { 'local variable' => 'bar',
      'constant' => 'CONST',
      'class variable' => '@@cvar',
      'instance variable' => '@ivar',
      'global variable' => '$gvar' }.each do |type, name|
      context "for a #{type} lval" do
        it "registers an offense for assignment using #{assignment} " \
           'in ternary' do
          source = "foo? ? #{name} #{assignment} 1 : #{name} #{assignment} 2"
          highlight = '^' * source.length
          expect_offense(<<~RUBY)
            #{source}
            #{highlight} Use the return of the conditional for variable assignment and comparison.
          RUBY
        end

        it "allows assignment using #{assignment} to ternary" do
          expect_no_offenses(<<~RUBY)
            #{name} #{assignment} foo? ? 1 : 2
          RUBY
        end

        it "registers an offense for assignment using #{assignment} in " \
           'if else' do
          expect_offense(<<~RUBY)
            if foo
            ^^^^^^ Use the return of the conditional for variable assignment and comparison.
              #{name} #{assignment} 1
            else
              #{name} #{assignment} 2
            end
          RUBY
        end

        it "registers an offense for assignment using #{assignment} in "\
        ' case when' do
          expect_offense(<<~RUBY)
            case foo
            ^^^^^^^^ Use the return of the conditional for variable assignment and comparison.
            when "a"
              #{name} #{assignment} 1
            else
              #{name} #{assignment} 2
            end
          RUBY
        end

        it "autocorrects for assignment using #{assignment} in if else" do
          expect_offense(<<~RUBY)
            if foo
            ^^^^^^ Use the return of the conditional for variable assignment and comparison.
              #{name} #{assignment} 1
            else
              #{name} #{assignment} 2
            end
          RUBY
          indent = ' ' * "#{name} #{assignment} ".length
          expect_correction(<<~RUBY)
            #{name} #{assignment} if foo
              1
            else
              2
            #{indent}end
          RUBY
        end
      end
    end
  end

  it_behaves_like('all assignment types', '=')
  it_behaves_like('all assignment types', '==')
  it_behaves_like('all assignment types', '===')
  it_behaves_like('all assignment types', '+=')
  it_behaves_like('all assignment types', '-=')
  it_behaves_like('all assignment types', '*=')
  it_behaves_like('all assignment types', '**=')
  it_behaves_like('all assignment types', '/=')
  it_behaves_like('all assignment types', '%=')
  it_behaves_like('all assignment types', '^=')
  it_behaves_like('all assignment types', '&=')
  it_behaves_like('all assignment types', '|=')
  it_behaves_like('all assignment types', '<=')
  it_behaves_like('all assignment types', '>=')
  it_behaves_like('all assignment types', '<<=')
  it_behaves_like('all assignment types', '>>=')
  it_behaves_like('all assignment types', '||=')
  it_behaves_like('all assignment types', '&&=')
  it_behaves_like('all assignment types', '+=')
  it_behaves_like('all assignment types', '<<')
  it_behaves_like('all assignment types', '-=')

  it 'registers an offense for assignment in if elsif else' do
    expect_offense(<<~RUBY)
      if foo
      ^^^^^^ Use the return of the conditional for variable assignment and comparison.
        bar = 1
      elsif baz
        bar = 2
      else
        bar = 3
      end
    RUBY
  end

  it 'registers an offense for assignment in if elsif elsif else' do
    expect_offense(<<~RUBY)
      if foo
      ^^^^^^ Use the return of the conditional for variable assignment and comparison.
        bar = 1
      elsif baz
        bar = 2
      elsif foobar
        bar = 3
      else
        bar = 4
      end
    RUBY
  end

  it 'registers an offense for assignment in if else when the assignment ' \
    'spans multiple lines' do
    expect_offense(<<~RUBY)
      if foo
      ^^^^^^ Use the return of the conditional for variable assignment and comparison.
        foo = {
          a: 1,
          b: 2,
          c: 2,
          d: 2,
          e: 2,
          f: 2,
          g: 2,
          h: 2
        }
      else
        foo = { }
      end
    RUBY
  end

  it 'autocorrects assignment in if else when the assignment ' \
    'spans multiple lines' do
    source = <<~RUBY
      if foo
        foo = {
          a: 1,
          b: 2,
          c: 2,
          d: 2,
          e: 2,
          f: 2,
          g: 2,
          h: 2
        }
      else
        foo = { }
      end
    RUBY
    new_source = autocorrect_source(source)

    expect(new_source).to eq(<<~RUBY)
      foo = if foo
        {
          a: 1,
          b: 2,
          c: 2,
          d: 2,
          e: 2,
          f: 2,
          g: 2,
          h: 2
        }
      else
        { }
      end
    RUBY
  end

  shared_examples 'allows out of order multiple assignment in if elsif else' do
    it 'allows out of order multiple assignment in if elsif else' do
      expect_no_offenses(<<~RUBY)
        if baz
          bar = 1
          foo = 1
        elsif foobar
          foo = 2
          bar = 2
        else
          foo = 3
          bar = 3
        end
      RUBY
    end
  end

  context 'assignment as the last statement' do
    it 'allows more than variable assignment in if else' do
      expect_no_offenses(<<~RUBY)
        if foo
          method_call
          bar = 1
        else
          method_call
          bar = 2
        end
      RUBY
    end

    it 'allows more than variable assignment in if elsif else' do
      expect_no_offenses(<<~RUBY)
        if foo
          method_call
          bar = 1
        elsif foobar
          method_call
          bar = 2
        else
          method_call
          bar = 3
        end
      RUBY
    end

    it 'allows multiple assignment in if else' do
      expect_no_offenses(<<~RUBY)
        if baz
          foo = 1
          bar = 1
        else
          foo = 2
          bar = 2
        end
      RUBY
    end

    it 'allows multiple assignment in if elsif else' do
      expect_no_offenses(<<~RUBY)
        if baz
          foo = 1
          bar = 1
        elsif foobar
          foo = 2
          bar = 2
        else
          foo = 3
          bar = 3
        end
      RUBY
    end

    it 'allows multiple assignment in if elsif elsif else' do
      expect_no_offenses(<<~RUBY)
        if baz
          foo = 1
          bar = 1
        elsif foobar
          foo = 2
          bar = 2
        elsif barfoo
          foo = 3
          bar = 3
        else
          foo = 4
          bar = 4
        end
      RUBY
    end

    it 'allows multiple assignment in if elsif else when the last ' \
       'assignment is the same and the earlier assignments do not appear in ' \
       'all branches' do
      expect_no_offenses(<<~RUBY)
        if baz
          foo = 1
          bar = 1
        elsif foobar
          baz = 2
          bar = 2
        else
          boo = 3
          bar = 3
        end
      RUBY
    end

    it 'allows multiple assignment in case when else when the last ' \
       'assignment is the same and the earlier assignments do not appear ' \
       'in all branches' do
      expect_no_offenses(<<~RUBY)
        case foo
        when foobar
          baz = 1
          bar = 1
        when foobaz
          boo = 2
          bar = 2
        else
          faz = 3
          bar = 3
        end
      RUBY
    end

    it_behaves_like 'allows out of order multiple assignment in if elsif else'

    it 'allows multiple assignment in unless else' do
      expect_no_offenses(<<~RUBY)
        unless baz
          foo = 1
          bar = 1
        else
          foo = 2
          bar = 2
        end
      RUBY
    end

    it 'allows multiple assignments in case when with only one when' do
      expect_no_offenses(<<~RUBY)
        case foo
        when foobar
          foo = 1
          bar = 1
        else
          foo = 3
          bar = 3
        end
      RUBY
    end

    it 'allows multiple assignments in case when with multiple whens' do
      expect_no_offenses(<<~RUBY)
        case foo
        when foobar
          foo = 1
          bar = 1
        when foobaz
          foo = 2
          bar = 2
        else
          foo = 3
          bar = 3
        end
      RUBY
    end

    it 'allows multiple assignments in case when if there are uniq ' \
       'variables in the when branches' do
      expect_no_offenses(<<~RUBY)
        case foo
        when foobar
          foo = 1
          baz = 1
          bar = 1
        when foobaz
          foo = 2
          baz = 2
          bar = 2
        else
          foo = 3
          bar = 3
        end
      RUBY
    end

    it 'allows multiple assignment in case statements when the last ' \
       'assignment is the same and the earlier assignments do not appear in ' \
       'all branches' do
      expect_no_offenses(<<~RUBY)
        case foo
        when foobar
          foo = 1
          bar = 1
        when foobaz
          baz = 2
          bar = 2
        else
          boo = 3
          bar = 3
        end
      RUBY
    end

    it 'allows assignment in if elsif else with some branches only ' \
       'containing variable assignment and others containing more than ' \
       'variable assignment' do
      expect_no_offenses(<<~RUBY)
        if foo
          bar = 1
        elsif foobar
          method_call
          bar = 2
        elsif baz
          bar = 3
        else
          method_call
          bar = 4
        end
      RUBY
    end

    it 'allows variable assignment in unless else with more than ' \
       'variable assignment' do
      expect_no_offenses(<<~RUBY)
        unless foo
          method_call
          bar = 1
        else
          method_call
          bar = 2
        end
      RUBY
    end

    it 'allows variable assignment in case when else with more than ' \
       'variable assignment' do
      expect_no_offenses(<<~RUBY)
        case foo
        when foobar
          method_call
          bar = 1
        else
          method_call
          bar = 2
        end
      RUBY
    end

    context 'multiple assignment in only one branch' do
      it 'allows multiple assignment is in if' do
        expect_no_offenses(<<~RUBY)
          if foo
            baz = 1
            bar = 1
          elsif foobar
            method_call
            bar = 2
          else
            other_method
            bar = 3
          end
        RUBY
      end

      it 'allows multiple assignment is in elsif' do
        expect_no_offenses(<<~RUBY)
          if foo
            method_call
            bar = 1
          elsif foobar
            baz = 2
            bar = 2
          else
            other_method
            bar = 3
          end
        RUBY
      end

      it 'registers an offense when multiple assignment is in else' do
        expect_no_offenses(<<~RUBY)
          if foo
            method_call
            bar = 1
          elsif foobar
            other_method
            bar = 2
          else
            baz = 3
            bar = 3
          end
        RUBY
      end
    end
  end

  it 'registers an offense for assignment in if then else' do
    expect_offense(<<~RUBY)
      if foo then bar = 1
      ^^^^^^^^^^^^^^^^^^^ Use the return of the conditional for variable assignment and comparison.
      else bar = 2
      end
    RUBY
  end

  it 'registers an offense for assignment in unless else' do
    expect_offense(<<~RUBY)
      unless foo
      ^^^^^^^^^^ Use the return of the conditional for variable assignment and comparison.
        bar = 1
      else
        bar = 2
      end
    RUBY
  end

  it 'registers an offense for assignment in case when then else' do
    expect_offense(<<~RUBY)
      case foo
      ^^^^^^^^ Use the return of the conditional for variable assignment and comparison.
      when bar then baz = 1
      else baz = 2
      end
    RUBY
  end

  it 'registers an offense for assignment in case with when when else' do
    expect_offense(<<~RUBY)
      case foo
      ^^^^^^^^ Use the return of the conditional for variable assignment and comparison.
      when foobar
        bar = 1
      when baz
        bar = 2
      else
        bar = 3
      end
    RUBY
  end

  it 'allows different assignment types in case with when when else' do
    expect_no_offenses(<<~RUBY)
      case foo
      when foobar
        bar = 1
      else
        bar << 2
      end
    RUBY
  end

  it 'allows assignment in multiple branches when it is ' \
     'wrapped in a modifier' do
    expect_no_offenses(<<~RUBY)
      if foo
        bar << 1
      else
        bar << 2 if foobar
      end
    RUBY
  end

  context 'auto-correct' do
    shared_examples 'comparison correction' do |method|
      let(:end_alignment_align_with) { 'keyword' }

      it 'corrects comparison methods in if elsif else' do
        source = <<~RUBY
          if foo
            a #{method} b
          elsif bar
            a #{method} c
          else
            a #{method} d
          end
        RUBY

        new_source = autocorrect_source(source)

        indent = ' ' * "a #{method} ".length
        expect(new_source).to eq(<<~RUBY)
          a #{method} if foo
            b
          elsif bar
            c
          else
            d
          #{indent}end
        RUBY
      end

      it 'corrects comparison methods in unless else' do
        source = <<~RUBY
          unless foo
            a #{method} b
          else
            a #{method} d
          end
        RUBY

        new_source = autocorrect_source(source)

        indent = ' ' * "a #{method} ".length
        expect(new_source).to eq(<<~RUBY)
          a #{method} unless foo
            b
          else
            d
          #{indent}end
        RUBY
      end

      it 'corrects comparison methods in case when' do
        source = <<~RUBY
          case foo
          when bar
            a #{method} b
          else
            a #{method} d
          end
        RUBY

        new_source = autocorrect_source(source)

        indent = ' ' * "a #{method} ".length
        expect(new_source).to eq(<<~RUBY)
          a #{method} case foo
          when bar
            b
          else
            d
          #{indent}end
        RUBY
      end
    end

    it_behaves_like('comparison correction', '==')
    it_behaves_like('comparison correction', '!=')
    it_behaves_like('comparison correction', '=~')
    it_behaves_like('comparison correction', '!~')
    it_behaves_like('comparison correction', '<=>')

    it 'corrects assignment in ternary operations' do
      new_source = autocorrect_source('foo? ? bar = 1 : bar = 2')

      expect(new_source).to eq('bar = foo? ? 1 : 2')
    end

    it 'corrects assignment in ternary operations using strings' do
      new_source = autocorrect_source('foo? ? bar = "1" : bar = "2"')

      expect(new_source).to eq('bar = foo? ? "1" : "2"')
    end

    it 'corrects =~ in ternary operations' do
      new_source = autocorrect_source('foo? ? bar =~ /a/ : bar =~ /b/')
      expect(new_source).to eq('bar =~ (foo? ? /a/ : /b/)')
    end

    it 'corrects aref assignment in ternary operations' do
      new_source = autocorrect_source('foo? ? bar[1] = 1 : bar[1] = 2')
      expect(new_source).to eq('bar[1] = foo? ? 1 : 2')
    end

    it 'corrects << in ternary operations' do
      new_source = autocorrect_source('foo? ? bar << 1 : bar << 2')
      expect(new_source).to eq('bar << (foo? ? 1 : 2)')
    end

    it 'corrects assignment in if else' do
      source = <<~RUBY
        if foo
          bar = 1
        else
          bar = 2
        end
      RUBY

      new_source = autocorrect_source(source)

      expect(new_source).to eq(<<~RUBY)
        bar = if foo
          1
        else
          2
        end
      RUBY
    end

    it 'corrects assignment to unbracketed array in if else' do
      source = <<~RUBY
        if foo
          bar = 1
        else
          bar = 2, 5, 6
        end
      RUBY

      new_source = autocorrect_source(source)

      expect(new_source).to eq(<<~RUBY)
        bar = if foo
          1
        else
          [2, 5, 6]
        end
      RUBY
    end

    it 'corrects assignment in if elsif else' do
      source = <<~RUBY
        if foo
          bar = 1
        elsif baz
          bar = 2
        else
          bar = 3
        end
      RUBY

      new_source = autocorrect_source(source)

      expect(new_source).to eq(<<~RUBY)
        bar = if foo
          1
        elsif baz
          2
        else
          3
        end
      RUBY
    end

    shared_examples '2 or 3 character assignment types' do |asgn|
      it "corrects assignment using #{asgn} in if elsif else" do
        source = <<~RUBY
          if foo
            bar #{asgn} 1
          elsif baz
            bar #{asgn} 2
          else
            bar #{asgn} 3
          end
        RUBY

        new_source = autocorrect_source(source)

        expect(new_source).to eq(<<~RUBY)
          bar #{asgn} if foo
            1
          elsif baz
            2
          else
            3
          end
        RUBY
      end

      it "corrects assignment using #{asgn} in case when else" do
        source = <<~RUBY
          case foo
          when bar
            baz #{asgn} 1
          else
            baz #{asgn} 2
          end
        RUBY

        new_source = autocorrect_source(source)

        expect(new_source).to eq(<<~RUBY)
          baz #{asgn} case foo
          when bar
            1
          else
            2
          end
        RUBY
      end

      it "corrects assignment using #{asgn} in unless else" do
        source = <<~RUBY
          unless foo
            bar #{asgn} 1
          else
            bar #{asgn} 2
          end
        RUBY

        new_source = autocorrect_source(source)

        expect(new_source).to eq(<<~RUBY)
          bar #{asgn} unless foo
            1
          else
            2
          end
        RUBY
      end
    end

    it_behaves_like('2 or 3 character assignment types', '+=')
    it_behaves_like('2 or 3 character assignment types', '-=')
    it_behaves_like('2 or 3 character assignment types', '<<')

    it_behaves_like('2 or 3 character assignment types', '&&=')
    it_behaves_like('2 or 3 character assignment types', '||=')

    it 'corrects assignment in if elsif else with multiple elsifs' do
      source = <<~RUBY
        if foo
          bar = 1
        elsif baz
          bar = 2
        elsif foobar
          bar = 3
        else
          bar = 4
        end
      RUBY

      new_source = autocorrect_source(source)

      expect(new_source).to eq(<<~RUBY)
        bar = if foo
          1
        elsif baz
          2
        elsif foobar
          3
        else
          4
        end
      RUBY
    end

    it 'corrects assignment in unless else' do
      source = <<~RUBY
        unless foo
          bar = 1
        else
          bar = 2
        end
      RUBY

      new_source = autocorrect_source(source)

      expect(new_source).to eq(<<~RUBY)
        bar = unless foo
          1
        else
          2
        end
      RUBY
    end

    it 'corrects assignment in case when else' do
      source = <<~RUBY
        case foo
        when bar
          baz = 1
        else
          baz = 2
        end
      RUBY

      new_source = autocorrect_source(source)

      expect(new_source).to eq(<<~RUBY)
        baz = case foo
        when bar
          1
        else
          2
        end
      RUBY
    end

    it 'corrects assignment in case when else with multiple whens' do
      source = <<~RUBY
        case foo
        when bar
          baz = 1
        when foobar
          baz = 2
        else
          baz = 3
        end
      RUBY

      new_source = autocorrect_source(source)

      expect(new_source).to eq(<<~RUBY)
        baz = case foo
        when bar
          1
        when foobar
          2
        else
          3
        end
      RUBY
    end

    context 'assignment from a method' do
      it 'corrects if else' do
        source = <<~RUBY
          if foo?(scope.node)
            bar << foobar(var, all)
          else
            bar << baz(var, all)
          end
        RUBY

        new_source = autocorrect_source(source)

        expect(new_source).to eq(<<~RUBY)
          bar << if foo?(scope.node)
            foobar(var, all)
          else
            baz(var, all)
          end
        RUBY
      end

      it 'corrects unless else' do
        source = <<~RUBY
          unless foo?(scope.node)
            bar << foobar(var, all)
          else
            bar << baz(var, all)
          end
        RUBY

        new_source = autocorrect_source(source)

        expect(new_source).to eq(<<~RUBY)
          bar << unless foo?(scope.node)
            foobar(var, all)
          else
            baz(var, all)
          end
        RUBY
      end

      it 'corrects case when' do
        source = <<~RUBY
          case foo
          when foobar
            bar << foobar(var, all)
          else
            bar << baz(var, all)
          end
        RUBY

        new_source = autocorrect_source(source)

        expect(new_source).to eq(<<~RUBY)
          bar << case foo
          when foobar
            foobar(var, all)
          else
            baz(var, all)
          end
        RUBY
      end
    end

    context 'then' do
      it 'corrects if then elsif then else' do
        source = <<~RUBY
          if cond then bar = 1
          elsif cond then bar = 2
          else bar = 3
          end
        RUBY

        new_source = autocorrect_source(source)

        expect(new_source).to eq(<<~RUBY)
          bar = if cond then 1
          elsif cond then 2
          else 3
          end
        RUBY
      end

      it 'corrects case when then else' do
        source = <<~RUBY
          case foo
          when baz then bar = 1
          else bar = 2
          end
        RUBY

        new_source = autocorrect_source(source)

        expect(new_source).to eq(<<~RUBY)
          bar = case foo
          when baz then 1
          else 2
          end
        RUBY
      end
    end

    it 'preserves comments during correction in if else' do
      source = <<~RUBY
        if foo
          # comment in if
          bar = 1
        else
          # comment in else
          bar = 2
        end
      RUBY

      new_source = autocorrect_source(source)

      expect(new_source).to eq(<<~RUBY)
        bar = if foo
          # comment in if
          1
        else
          # comment in else
          2
        end
      RUBY
    end

    it 'preserves comments during correction in case when else' do
      source = <<~RUBY
        case foo
        when foobar
          # comment in when
          bar = 1
        else
          # comment in else
          bar = 2
        end
      RUBY

      new_source = autocorrect_source(source)

      expect(new_source).to eq(<<~RUBY)
        bar = case foo
        when foobar
          # comment in when
          1
        else
          # comment in else
          2
        end
      RUBY
    end

    context 'aref assignment' do
      it 'corrects if..else' do
        new_source = autocorrect_source(<<~RUBY)
          if something
            array[1] = 1
          else
            array[1] = 2
          end
        RUBY
        expect(new_source).to eq(<<~RUBY)
          array[1] = if something
            1
          else
            2
          end
        RUBY
      end

      context 'with different indices' do
        it "doesn't register an offense" do
          expect_no_offenses(<<~RUBY)
            if something
              array[1, 2] = 1
            else
              array[1, 3] = 2
            end
          RUBY
        end
      end
    end

    context 'self.attribute= assignment' do
      it 'corrects if..else' do
        new_source = autocorrect_source(<<~RUBY)
          if something
            self.attribute = 1
          else
            self.attribute = 2
          end
        RUBY
        expect(new_source).to eq(<<~RUBY)
          self.attribute = if something
            1
          else
            2
          end
        RUBY
      end

      context 'with different receivers' do
        it "doesn't register an offense" do
          expect_no_offenses(<<~RUBY)
            if something
              obj1.attribute = 1
            else
              obj2.attribute = 2
            end
          RUBY
        end
      end
    end

    context 'multiple assignment' do
      it 'does not register an offense in if else' do
        expect_no_offenses(<<~RUBY)
          if something
            a, b = 1, 2
          else
            a, b = 2, 1
          end
        RUBY
      end

      it 'does not register an offense in case when' do
        expect_no_offenses(<<~RUBY)
          case foo
          when bar
            a, b = 1, 2
          else
            a, b = 2, 1
          end
        RUBY
      end
    end
  end

  context 'configured to check conditions with multiple statements' do
    subject(:cop) { described_class.new(config) }

    let(:config) do
      RuboCop::Config.new('Style/ConditionalAssignment' => {
                            'Enabled' => true,
                            'SingleLineConditionsOnly' => false,
                            'IncludeTernaryExpressions' => true,
                            'EnforcedStyle' => 'assign_to_condition',
                            'SupportedStyles' => %w[assign_to_condition
                                                    assign_inside_condition]
                          },
                          'Layout/EndAlignment' => {
                            'EnforcedStyleAlignWith' => 'keyword',
                            'Enabled' => true
                          },
                          'Metrics/LineLength' => {
                            'Max' => 80,
                            'Enabled' => true
                          })
    end

    context 'assignment as the last statement' do
      it 'registers an offense in if else with more than variable assignment' do
        expect_offense(<<~RUBY)
          if foo
          ^^^^^^ Use the return of the conditional for variable assignment and comparison.
            method_call
            bar = 1
          else
            method_call
            bar = 2
          end
        RUBY
      end

      it 'registers an offense in if elsif else with more than ' \
         'variable assignment' do
        expect_offense(<<~RUBY)
          if foo
          ^^^^^^ Use the return of the conditional for variable assignment and comparison.
            method_call
            bar = 1
          elsif foobar
            method_call
            bar = 2
          else
            method_call
            bar = 3
          end
        RUBY
      end

      it 'register an offense for multiple assignment in if else' do
        expect_offense(<<~RUBY)
          if baz
          ^^^^^^ Use the return of the conditional for variable assignment and comparison.
            foo = 1
            bar = 1
          else
            foo = 2
            bar = 2
          end
        RUBY
      end

      it 'registers an offense for multiple assignment in if elsif else' do
        expect_offense(<<~RUBY)
          if baz
          ^^^^^^ Use the return of the conditional for variable assignment and comparison.
            foo = 1
            bar = 1
          elsif foobar
            foo = 2
            bar = 2
          else
            foo = 3
            bar = 3
          end
        RUBY
      end

      it 'allows multiple assignment in if elsif elsif else' do
        expect_offense(<<~RUBY)
          if baz
          ^^^^^^ Use the return of the conditional for variable assignment and comparison.
            foo = 1
            bar = 1
          elsif foobar
            foo = 2
            bar = 2
          elsif barfoo
            foo = 3
            bar = 3
          else
            foo = 4
            bar = 4
          end
        RUBY
      end

      it_behaves_like 'allows out of order multiple assignment in if elsif else'

      it 'allows multiple assignment in unless else' do
        expect_offense(<<~RUBY)
          unless baz
          ^^^^^^^^^^ Use the return of the conditional for variable assignment and comparison.
            foo = 1
            bar = 1
          else
            foo = 2
            bar = 2
          end
        RUBY
      end

      it 'allows multiple assignments in case when with only one when' do
        expect_offense(<<~RUBY)
          case foo
          ^^^^^^^^ Use the return of the conditional for variable assignment and comparison.
          when foobar
            foo = 1
            bar = 1
          else
            foo = 3
            bar = 3
          end
        RUBY
      end

      it 'allows multiple assignments in case when with multiple whens' do
        expect_offense(<<~RUBY)
          case foo
          ^^^^^^^^ Use the return of the conditional for variable assignment and comparison.
          when foobar
            foo = 1
            bar = 1
          when foobaz
            foo = 2
            bar = 2
          else
            foo = 3
            bar = 3
          end
        RUBY
      end

      it 'registers an offense in if elsif else with some branches only ' \
          'containing variable assignment and others containing more than ' \
          'variable assignment' do
        expect_offense(<<~RUBY)
          if foo
          ^^^^^^ Use the return of the conditional for variable assignment and comparison.
            bar = 1
          elsif foobar
            method_call
            bar = 2
          elsif baz
            bar = 3
          else
            method_call
            bar = 4
          end
        RUBY
      end

      it 'registers an offense in unless else with more than ' \
         'variable assignment' do
        expect_offense(<<~RUBY)
          unless foo
          ^^^^^^^^^^ Use the return of the conditional for variable assignment and comparison.
            method_call
            bar = 1
          else
            method_call
            bar = 2
          end
        RUBY
      end

      it 'registers an offense in case when else with more than ' \
         'variable assignment' do
        expect_offense(<<~RUBY)
          case foo
          ^^^^^^^^ Use the return of the conditional for variable assignment and comparison.
          when foobar
            method_call
            bar = 1
          else
            method_call
            bar = 2
          end
        RUBY
      end

      context 'multiple assignment in only one branch' do
        it 'registers an offense when multiple assignment is in if' do
          expect_offense(<<~RUBY)
            if foo
            ^^^^^^ Use the return of the conditional for variable assignment and comparison.
              baz = 1
              bar = 1
            elsif foobar
              method_call
              bar = 2
            else
              other_method
              bar = 3
            end
          RUBY
        end

        it 'registers an offense when multiple assignment is in elsif' do
          expect_offense(<<~RUBY)
            if foo
            ^^^^^^ Use the return of the conditional for variable assignment and comparison.
              method_call
              bar = 1
            elsif foobar
              baz = 2
              bar = 2
            else
              other_method
              bar = 3
            end
          RUBY
        end

        it 'registers an offense when multiple assignment is in else' do
          expect_offense(<<~RUBY)
            if foo
            ^^^^^^ Use the return of the conditional for variable assignment and comparison.
              method_call
              bar = 1
            elsif foobar
              other_method
              bar = 2
            else
              baz = 3
              bar = 3
            end
          RUBY
        end
      end
    end

    it 'allows assignment in multiple branches when it is ' \
       'wrapped in a modifier' do
      expect_no_offenses(<<~RUBY)
        if foo
          bar << 1
          bar << 2
        else
          bar << 3
          bar << 4 if foobar
        end
      RUBY
    end

    it 'registers an offense for multiple assignment when an earlier ' \
       'assignment is is protected by a modifier' do
      expect_offense(<<~RUBY)
        if foo
        ^^^^^^ Use the return of the conditional for variable assignment and comparison.
          bar << 1
          bar << 2
        else
          bar << 3 if foobar
          bar << 4
        end
      RUBY
    end

    context 'auto-correct' do
      it 'corrects multiple assignment in if else' do
        source = <<~RUBY
          if foo
            baz = 1
            bar = 1
          else
            baz = 3
            bar = 3
          end
        RUBY
        new_source = autocorrect_source(source)

        expect(new_source).to eq(<<~RUBY)
          bar = if foo
            baz = 1
            1
          else
            baz = 3
            3
                end
        RUBY
      end

      it 'corrects multiple assignment in if elsif else' do
        source = <<~RUBY
          if foo
            baz = 1
            bar = 1
          elsif foobar
            baz = 2
            bar = 2
          else
            baz = 3
            bar = 3
          end
        RUBY
        new_source = autocorrect_source(source)

        expect(new_source).to eq(<<~RUBY)
          bar = if foo
            baz = 1
            1
          elsif foobar
            baz = 2
            2
          else
            baz = 3
            3
                end
        RUBY
      end

      it 'corrects multiple assignment in if elsif else with multiple elsifs' do
        source = <<~RUBY
          if foo
            baz = 1
            bar = 1
          elsif foobar
            baz = 2
            bar = 2
          elsif foobaz
            baz = 3
            bar = 3
          else
            baz = 4
            bar = 4
          end
        RUBY
        new_source = autocorrect_source(source)

        expect(new_source).to eq(<<~RUBY)
          bar = if foo
            baz = 1
            1
          elsif foobar
            baz = 2
            2
          elsif foobaz
            baz = 3
            3
          else
            baz = 4
            4
                end
        RUBY
      end

      it 'corrects multiple assignment in case when' do
        source = <<~RUBY
          case foo
          when foobar
            baz = 1
            bar = 1
          else
            baz = 2
            bar = 2
          end
        RUBY
        new_source = autocorrect_source(source)

        expect(new_source).to eq(<<~RUBY)
          bar = case foo
          when foobar
            baz = 1
            1
          else
            baz = 2
            2
                end
        RUBY
      end

      it 'corrects multiple assignment in case when with multiple whens' do
        source = <<~RUBY
          case foo
          when foobar
            baz = 1
            bar = 1
          when foobaz
            baz = 2
            bar = 2
          else
            baz = 3
            bar = 3
          end
        RUBY
        new_source = autocorrect_source(source)

        expect(new_source).to eq(<<~RUBY)
          bar = case foo
          when foobar
            baz = 1
            1
          when foobaz
            baz = 2
            2
          else
            baz = 3
            3
                end
        RUBY
      end

      it 'corrects multiple assignment in unless else' do
        source = <<~RUBY
          unless foo
            baz = 1
            bar = 1
          else
            baz = 2
            bar = 2
          end
        RUBY
        new_source = autocorrect_source(source)

        expect(new_source).to eq(<<~RUBY)
          bar = unless foo
            baz = 1
            1
          else
            baz = 2
            2
                end
        RUBY
      end

      it 'corrects assignment in an if statement that is nested ' \
        'in unless else' do
        source = <<~RUBY
          unless foo
            if foobar
              baz = 1
            elsif qux
              baz = 2
            else
              baz = 3
            end
          else
            baz = 4
          end
        RUBY

        new_source = autocorrect_source(source)

        expect(new_source).to eq(<<~RUBY)
          unless foo
            baz = if foobar
              1
            elsif qux
              2
            else
              3
                  end
          else
            baz = 4
          end
        RUBY
      end
    end
  end

  context 'EndAlignment configured to start_of_line' do
    subject(:cop) { described_class.new(config) }

    context 'auto-correct' do
      it 'uses proper end alignment in if' do
        source = <<~RUBY
          if foo
            a =  b
          elsif bar
            a = c
          else
            a = d
          end
        RUBY

        new_source = autocorrect_source(source)

        expect(new_source).to eq(<<~RUBY)
          a = if foo
            b
          elsif bar
            c
          else
            d
          end
        RUBY
      end

      it 'uses proper end alignment in unless' do
        source = <<~RUBY
          unless foo
            a = b
          else
            a = d
          end
        RUBY

        new_source = autocorrect_source(source)

        expect(new_source).to eq(<<~RUBY)
          a = unless foo
            b
          else
            d
          end
        RUBY
      end

      it 'uses proper end alignment in case' do
        source = <<~RUBY
          case foo
          when bar
            a = b
          when baz
            a = c
          else
            a = d
          end
        RUBY

        new_source = autocorrect_source(source)

        expect(new_source).to eq(<<~RUBY)
          a = case foo
          when bar
            b
          when baz
            c
          else
            d
          end
        RUBY
      end
    end
  end

  context 'IncludeTernaryExpressions false' do
    let(:config) do
      RuboCop::Config.new('Style/ConditionalAssignment' => {
                            'Enabled' => true,
                            'SingleLineConditionsOnly' => true,
                            'IncludeTernaryExpressions' => false,
                            'EnforcedStyle' => 'assign_to_condition',
                            'SupportedStyles' => %w[assign_to_condition
                                                    assign_inside_condition]
                          },
                          'Layout/EndAlignment' => {
                            'EnforcedStyleAlignWith' => 'keyword',
                            'Enabled' => true
                          },
                          'Metrics/LineLength' => {
                            'Max' => 80,
                            'Enabled' => true
                          })
    end

    it 'allows assignment in ternary operation' do
      expect_no_offenses('foo? ? bar = "a" : bar = "b"')
    end
  end

  context 'with nested conditionals' do
    # No offense for `if outer`
    let(:annotated_source) { <<~RUBY }
      if outer
        bar = 1
      else
        if inner
        ^^^^^^^^ Use the return of the conditional for variable assignment and comparison.
          bar = 2
        else
          bar = 3
        end
      end
    RUBY

    it 'does not consider branches of nested ifs' do
      expect_offense(annotated_source)

      expect_correction(<<~RUBY)
        if outer
          bar = 1
        else
          bar = if inner
            2
          else
            3
          end
        end
      RUBY
    end

    it 'eventually autocorrects all branches' do
      source = annotated_source.lines.reject { |line| line =~ /^ *\^/}.join
      corrected = autocorrect_source_with_loop(source)

      expect(corrected).to eq(<<~RUBY)
        bar = if outer
          1
        else
          if inner
            2
          else
            3
          end
        end
      RUBY
    end
  end
end
