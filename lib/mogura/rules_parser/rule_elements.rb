# frozen_string_literal: true

module Mogura
  class RuleElement
    def match?(mail)
      raise NotImplementedError
    end
  end

  class LogicalOperator < RuleElement
    def initialize(operands)
      @operands = operands

      super()
    end

    def to_s
      "#<#{self.class} operands=#{@operands}>"
    end

    attr_reader :operands
  end

  class AndOperator < LogicalOperator
    def match?(mail)
      @operands.all? { |elm| elm.match?(mail) }
    end
  end

  class OrOperator < LogicalOperator
    def match?(mail)
      @operands.any? { |elm| elm.match?(mail) }
    end
  end

  class FieldMatcher < RuleElement
    def initialize(regexp)
      @regexp = regexp

      super()
    end

    attr_reader :regexp
  end

  class SpecialFieldMatcher < FieldMatcher; end

  class FromMatcher < SpecialFieldMatcher
    def match?(mail)
      mail.from.addresses.any? { |address| address.match?(@regexp) }
    end
  end

  class SenderMatcher < SpecialFieldMatcher
    def match?(mail)
      mail.sender.address.match?(@regexp)
    end
  end

  class ToMatcher < SpecialFieldMatcher
    def match?(mail)
      mail.to.match?(@regexp)
    end
  end

  class CcMatcher < SpecialFieldMatcher
    def match?(mail)
      mail.cc.match?(@regexp)
    end
  end

  class SubjectMatcher < SpecialFieldMatcher
    def match?(mail)
      mail.subject.match?(@regexp)
    end
  end

  class DateMatcher < SpecialFieldMatcher
    def match?(mail)
      # TODO: impl
      raise NotImplementedError
    end
  end

  class GeneralFieldMatcher < FieldMatcher
    def initialize(field_name, regexp)
      @field_name = field_name

      super(regexp)
    end

    def match?(mail)
      mail.header[@field_name].value.match?(@regexp)
    end
  end
end
