# frozen_string_literal: true

require "mail"
require "net/imap"

module Mogura
  class IMAPHandler
    def initialize(host, port = 143, usessl: false, certs: nil, verify: true,
                   auth_info: nil)
      @imap = Net::IMAP.new(host, port, usessl, certs, verify)
      @imap.authenticate(auth_info[:auth_type], auth_info[:user], auth_info[:password]) if auth_info

      @selected_mailbox = [nil, nil]
    end

    def monitor_recents(mailbox, &block)
      select_mailbox(mailbox)

      loop do
        wait_event_with_idle("RECENT")

        @imap.search(["RECENT"]).each do |message_id|
          break unless block

          block[message_id]
        end
      end
    end

    def wait_event_with_idle(expected_response_name, mailbox = nil)
      select_mailbox(mailbox) if mailbox

      @imap.idle do |resp|
        @imap.idle_done if resp.name == expected_response_name
      end
    end

    def fetch_envelope(mailbox, message_id)
      select_mailbox(mailbox)
      @imap.fetch(message_id, "ENVELOPE")[0].attr["ENVELOPE"]
    end

    def fetch_header(mailbox, message_id)
      select_mailbox(mailbox)
      fetch_data = @imap.fetch(message_id, "BODY.PEEK[HEADER]")[0].attr["BODY[HEADER]"]
      Mail.read_from_string(fetch_data)
    end

    def touch_mailbox(mailbox)
      @imap.create(mailbox) if @imap.list("", mailbox).empty?
    end

    def move(src_mailbox, src_message_id, dst_mailbox, create_mailbox: false)
      touch_mailbox(dst_mailbox) if create_mailbox

      select_mailbox(src_mailbox, readonly: false)

      @imap.copy(src_message_id, dst_mailbox)
      @imap.store(src_message_id, "+FLAGS", [:Deleted])
    end

    private

    def select_mailbox(mailbox, readonly: true)
      return if @selected_mailbox == [mailbox, readonly]

      if readonly
        @imap.examine(mailbox)
      else
        @imap.select(mailbox)
      end

      @selected_mailbox = [mailbox, readonly]
    end
  end
end
