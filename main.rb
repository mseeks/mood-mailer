require "dotenv"

Dotenv.load

require "awesome_print"
require "mailgun"
require "rest-client"
require "rufus-scheduler"

ENV["TZ"] = "America/Chicago"

scheduler = Rufus::Scheduler.new

# First, instantiate the Mailgun Client with your API key
mg_client = Mailgun::Client.new ENV["MAILGUN_API_KEY"]
mg_events = Mailgun::Events.new(mg_client, ENV["EMAIL_DOMAIN"])

scheduler.cron "0 9,13,17 * * 1,2,3,4,5" do
  message_params =  {
    from:    ENV["FROM_EMAIL_ADDRESS"],
    to:      ENV["TO_EMAIL_ADDRESS"],
    subject: "How are you feeling?",
    text:    "Reply with a word of how you're feeling right now."
  }

  # Send your message through the client
  mg_client.send_message ENV["EMAIL_DOMAIN"], message_params
end

scheduler.every "5m" do
  result = mg_events.get({
    event: "stored"
  })

  # To Ruby standard Hash.
  result.to_h["items"].each do |item|
    response = JSON.parse(
      RestClient::Request.new(
        method: :get,
        url: item["storage"]["url"],
        user: "api",
        password: ENV["MAILGUN_API_KEY"]
      ).execute.body
    )

    if response
      file_path = File.join(Dir.pwd, "data", "responses.csv")
      has_matching_responses = File.open(file_path, "rb").read.include?(response["Date"])

      unless has_matching_responses
        `echo '\"#{response["Date"]}\",#{response["stripped-text"]}' >> #{file_path}`
      end
    end
  end
end

scheduler.join
