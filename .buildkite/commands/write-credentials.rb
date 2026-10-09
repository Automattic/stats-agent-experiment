#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'

abort 'Usage: write-credentials.rb COMMAND [ARGS...]' if ARGV.empty?

client_id = ENV.fetch('WP_COM_CLIENT_ID', '')
client_secret = ENV.fetch('WP_COM_CLIENT_SECRET', '')
unless client_id.match?(/\A[1-9][0-9]*\z/) && client_id.to_i <= (2**64 - 1)
  abort 'WP_COM_CLIENT_ID must be a positive UInt64 integer.'
end
abort 'WP_COM_CLIENT_SECRET must be nonempty.' if client_secret.empty?

credentials_path = File.expand_path('../../wp_com_credentials.json', __dir__)

# Ensure also runs on CI cancellation. SIGKILL cannot be handled; agents use disposable checkouts.
Signal.trap('TERM') { exit 143 }
Signal.trap('INT') { exit 130 }

begin
  contents = JSON.generate(client_id: client_id.to_i, client_secret: client_secret)
  # EXCL also rejects symlinks, so a developer's existing credentials are never overwritten or removed.
  File.open(credentials_path, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
    begin
      file.write(contents)
      file.close
      system(*ARGV)
      exit($?&.exitstatus || 1)
    ensure
      File.unlink(credentials_path)
    end
  end
rescue Errno::EEXIST
  abort 'Refusing to overwrite existing wp_com_credentials.json.'
rescue StandardError => error
  # Do not print exception details: they can contain credential data.
  abort "Credential preparation or release failed (#{error.class})."
end
