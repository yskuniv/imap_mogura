# frozen_string_literal: true

require "net/imap"

module Mogura
  class IMAPHandler
    def initialize(host, port = 143, usessl = false, certs = nil, verify = true,
                   auth_info: nil)
      @imap = Net::IMAP.new(host, port, usessl, certs, verify)
      @imap.authenticate(auth_info[:auth_type], auth_info[:user], auth_info[:password]) if auth_info
    end

    def monitor_recents(mailbox, &block)
      @imap.examine(mailbox)

      loop do
        @imap.idle do |resp|
          @imap.idle_done if resp.is_a?(Net::IMAP::UntaggedResponse) && resp.name == "RECENT"
        end

        @imap.search(["RECENT"]).each do |message_id|
          break unless block

          block[message_id]
        end
      end
    end

    def fetch_envelope(mailbox, message_id)
      @imap.examine(mailbox)
      @imap.fetch(message_id, "ENVELOPE")[0].attr["ENVELOPE"]
    end
  end
end
