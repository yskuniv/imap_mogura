# frozen_string_literal: true

module Mogura
  module RuleMatcher
    class << self
      def match?(rule, mail)
        raise NotImplementedError
      end
    end
  end
end
