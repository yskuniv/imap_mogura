# frozen_string_literal: true

require "mail"
require "net/imap"

module Mogura
  class IMAPHandler
    # TODO: support starttls
    def initialize(host, port = 143, starttls: true, usessl: false, certs: nil, verify: true,
                   auth_info: nil)
      @imap = Net::IMAP.new(host, port, usessl, certs, verify)

      if usessl || starttls
        @imap.starttls(certs, verify) if !usessl && starttls

        # in case with TLS, just authenticate with LOGIN command
        @imap.login(auth_info[:user], auth_info[:password])
      else
        # in plain text session, use AUTHENTICATE command
        @imap.authenticate(auth_info[:auth_type], auth_info[:user], auth_info[:password])
      end

      @selected_mailbox = nil
    end

    def close
      close_mailbox
      @imap.disconnect
    end

    def monitor_recents(mailbox, &block)
      loop do
        wait_event_with_idle(mailbox, ["RECENT"])

        @imap.search(["RECENT"]).each do |message_id|
          break unless block

          block[message_id]
        end
      end
    end

    def wait_event_with_idle(mailbox, expected_response_names)
      select_mailbox(mailbox)

      @imap.idle do |resp|
        @imap.idle_done if expected_response_names.include? resp.name
      end
    end

    def all_mailbox_list
      @imap.list("", "*").map(&:name)
    end

    def handle_all_mails(mailbox, &block)
      select_mailbox(mailbox)
      @imap.search(["ALL"]).each do |message_id|
        break unless block

        block[message_id]
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
      return if src_mailbox == dst_mailbox # skip moving if src_mailbox is the same with dst_mailbox

      touch_mailbox(dst_mailbox) if create_mailbox

      select_mailbox(src_mailbox, readonly: false)

      @imap.copy([src_message_id], dst_mailbox)
      @imap.store(src_message_id, "+FLAGS", [:Deleted])

      dst_mailbox
    end

    private

    def with_mailbox_selected(mailbox, readonly: true, &block)
      select_mailbox(mailbox, readonly: readonly)

      block[]
    end

    def initialize_selected_mailbox
      @selected_mailbox = nil
    end

    def select_mailbox(mailbox, readonly: true)
      return if @selected_mailbox == [mailbox, readonly]

      close_mailbox

      if readonly
        @imap.examine(mailbox)
      else
        @imap.select(mailbox)
      end

      @selected_mailbox = [mailbox, readonly]
    end

    def close_mailbox
      return unless @selected_mailbox

      @imap.close
      @selected_mailbox = nil
    end
  end
end
