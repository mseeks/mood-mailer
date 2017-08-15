require "dotenv"

Dotenv.load

require "awesome_print"
require "mailgun"
require "mongoid"
require "rest-client"

Mongoid.load!("./mongoid.yml", :production)

class Response
  include Mongoid::Document
  field :body, type: String
  field :recieved_at, type: DateTime
end

# First, instantiate the Mailgun Client with your API key
mg_client = Mailgun::Client.new ENV["MAILGUN_API_KEY"]

# Define your message parameters
# message_params =  {
#   from:    ENV["FROM_EMAIL_ADDRESS"],
#   to:      ENV["TO_EMAIL_ADDRESS"],
#   subject: "How are you feeling?",
#   text:    "Reply with a word of how you're feeling right now."
# }
#
# # Send your message through the client
# mg_client.send_message ENV["EMAIL_DOMAIN"], message_params
mg_events = Mailgun::Events.new(mg_client, ENV["EMAIL_DOMAIN"])

result = mg_events.get({'event' => 'stored'})

# To Ruby standard Hash.
result.to_h["items"].each do |item|
  key = item["storage"]["key"]
  access_url = "https://api:#{ENV["MAILGUN_API_KEY"]}@sw.api.mailgun.net/v3/domains/#{ENV["EMAIL_DOMAIN"]}/messages/#{key}"

  begin
    response = JSON.parse(RestClient.get(access_url).body)
    document = Response.new(body: response["stripped-text"], recieved_at: response["Date"])
    document.upsert
  rescue => e
  end
end

ap Response.count
