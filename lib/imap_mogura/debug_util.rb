# frozen_string_literal: true

module ImapMogura
  module DebugUtil
    class << self
      def enable_debug
        $DEBUG = true
      end

      def debug(msg)
        warn msg if $DEBUG
      end
    end
  end
end
