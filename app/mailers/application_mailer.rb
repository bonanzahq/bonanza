class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "bonanza@example.com").then { |v| v.empty? ? "bonanza@example.com" : v }
  layout "mailer"
end
