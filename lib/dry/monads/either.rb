require 'dry/equalizer'

require 'dry/monads/right_biased'
require 'dry/monads/transformer'

module Dry
  module Monads
    # Represents a value which is either correct or an error.
    #
    # @api public
    class Either
      include Dry::Equalizer(:right, :left)
      include Transformer

      attr_reader :right, :left

      # Turns an enumerable of Either values into a single Either-wrapped
      # numerable, each element transformed by a block, eg.
      #
      # @example
      #   traverse([Right(1), Right(2), Right(3)]) { |x| x * 2 }
      #   => Right([2,4,6])
      #
      # @example
      #   traverse([Right(1), Left("1st"), Left("2nd")]) { |x| x * 2 }
      #   => Left("No")
      #
      # @param enumerable [Enumerable<Either>] the array of Either values
      # @return [Either::Right, Either::Left]
      # @api public
      def self.traverse(enumerable, &block)
        result = enumerable.map { |item|
          raise TypeError unless item.is_a? Either
          if item.left?
            break item
          else
            value = item.value
            block ? block.call(value) : value
          end
        }
        if result.is_a?(Either) && result.left?
          result
        else
          Right.new(result)
        end
      end

      # Returns self, added to keep the interface compatible with other monads.
      #
      # @return [Either::Right, Either::Left]
      def to_either
        self
      end

      # Represents a value that is in a correct state, i.e. everything went right.
      #
      # @api public
      class Right < Either
        include RightBiased::Right

        alias value right

        # @param right [Object] a value in a correct state
        def initialize(right)
          @right = right
        end

        # Apply the second function to value.
        #
        # @api public
        def either(_, f)
          f.call(value)
        end

        # Returns false
        def left?
          false
        end
        alias failure? left?

        # Returns true
        def right?
          true
        end
        alias success? right?

        # Does the same thing as #bind except it also wraps the value
        # in an instance of Either::Right monad. This allows for easier
        # chaining of calls.
        #
        # @example
        #   Dry::Monads.Right(4).fmap(&:succ).fmap(->(n) { n**2 }) # => Right(25)
        #
        # @param args [Array<Object>] arguments will be transparently passed through to #bind
        # @return [Either::Right]
        def fmap(*args, &block)
          Right.new(bind(*args, &block))
        end

        # @return [String]
        def to_s
          "Right(#{value.inspect})"
        end
        alias inspect to_s

        # @return [Maybe::Some]
        def to_maybe
          Kernel.warn 'Right(nil) transformed to None' if value.nil?
          Dry::Monads::Maybe(value)
        end
      end

      # Represents a value that is in an incorrect state, i.e. something went wrong.
      #
      # @api public
      class Left < Either
        include RightBiased::Left

        alias value left

        # @param left [Object] a value in an error state
        def initialize(left)
          @left = left
        end

        # Apply the first function to value.
        #
        # @api public
        def either(f, _)
          f.call(value)
        end

        # Returns true
        def left?
          true
        end
        alias failure? left?

        # Returns false
        def right?
          false
        end
        alias success? right?

        # If a block is given passes internal value to it and returns the result,
        # otherwise simply returns the parameter val.
        #
        # @example
        #   Dry::Monads.Left(ArgumentError.new('error message')).or(&:message) # => "error message"
        #
        # @param args [Array<Object>] arguments that will be passed to a block
        #                             if one was given, otherwise the first
        #                             value will be returned
        # @return [Object]
        def or(*args)
          if block_given?
            yield(value, *args)
          else
            args[0]
          end
        end

        # A lifted version of `#or`. Wraps the passed value or the block result with Either::Right.
        #
        # @example
        #   Dry::Monads.Left.new('no value').or_fmap('value') # => Right("value")
        #   Dry::Monads.Left.new('no value').or_fmap { 'value' } # => Right("value")
        #
        # @param args [Array<Object>] arguments will be passed to the underlying `#or` call
        # @return [Either::Right] Wrapped value
        def or_fmap(*args, &block)
          Right.new(self.or(*args, &block))
        end

        # @return [String]
        def to_s
          "Left(#{value.inspect})"
        end
        alias inspect to_s

        # @return [Maybe::None]
        def to_maybe
          Maybe::None.instance
        end
      end

      # A module that can be included for easier access to Either monads.
      module Mixin
        Right = Right
        Left = Left

        # @param value [Object] the value to be stored in the monad
        # @return [Either::Right]
        def Right(value)
          Right.new(value)
        end

        # @param value [Object] the value to be stored in the monad
        # @return [Either::Left]
        def Left(value)
          Left.new(value)
        end
      end
    end
  end
end
