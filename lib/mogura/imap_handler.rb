# frozen_string_literal: true

require "mail"
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

    def fetch_header(mailbox, message_id)
      @imap.examine(mailbox)
      fetch_data = @imap.fetch(message_id, "BODY.PEEK[HEADER]")[0].attr["BODY[HEADER]"]
      Mail.read_from_string(fetch_data)
    end

    def touch_mailbox(mailbox)
      @imap.create(mailbox) if @imap.list("", mailbox).empty?
    end

    def move(src_mailbox, src_message_id, dst_mailbox)
      @imap.select(src_mailbox)
      @imap.copy(src_message_id, dst_mailbox)
      @imap.store(src_message_id, "+FLAGS", [:Deleted])
    end
  end
end
