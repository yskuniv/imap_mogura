# frozen_string_literal: true

require "net/imap"

module Mogura
  class IMAPMonitor
    def start(host, port = 143, usessl = false, certs = nil, verify = true,
              auth_info: nil)
      imap = Net::IMAP.new(host, port, usessl, certs, verify)
      imap.authenticate(auth_info[:auth_type], auth_info[:user], auth_info[:password]) if auth_info

      imap.idle do |resp|
        p resp
      end
    end
  end
end
