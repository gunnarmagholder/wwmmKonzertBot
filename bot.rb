# frozen_string_literal: true

require 'dotenv/load'
require 'discordrb'
require 'rufus-scheduler'
require_relative 'scraper'

BOT_TOKEN  = ENV['DISCORD_BOT_TOKEN']
CLIENT_ID  = ENV['DISCORD_CLIENT_ID']&.to_i
CHANNEL_ID = ENV['DISCORD_CHANNEL_ID']&.to_i

def upcoming_events
  get_concerts(days_ahead: 30)
end
bot = Discordrb::Bot.new(
  token: BOT_TOKEN,
  client_id: CLIENT_ID,
  intents: [:server_messages],
  log_mode: :debug
)

bot.register_application_command(:concerts, 'Zeige kommende Konzerte in Hamburg') do |cmd|
  cmd.string('artist', 'Filtere nach Künstler', required: false)
  cmd.string('venue', 'Filtere nach Venue', required: false)
  cmd.integer('limit', 'Maximale Anzahl Ergebnisse (Standard: 10)', required: false)
end

bot.register_application_command(:refresh, 'Lade neue Konzertdaten von Songkick')

bot.application_command(:concerts) do |event|
  event.defer

  concerts = get_concerts

  options = {}
  options[:artist] = event.options['artist'] if event.options['artist']
  options[:venue] = event.options['venue'] if event.options['venue']

  filtered = filter_concerts(concerts, options)
  limit = event.options['limit'] || 10

  if filtered.empty?
    event.edit_response(content: '🎭 Keine Konzerte gefunden mit den angegebenen Kriterien.')
    return
  end

  concert_list = filtered.first(limit).map.with_index(1) do |c, i|
    "#{i}. **#{c['date']}** - #{c['artist']} @ #{c['location']}"
  end.join("\n")

  filter_info = []
  filter_info << "Künstler: #{options[:artist]}" if options[:artist]
  filter_info << "Venue: #{options[:venue]}" if options[:venue]

  message = "🎶 **Konzerte in Hamburg** 🎶\n"
  message += "Filter: #{filter_info.join(', ')}\n" unless filter_info.empty?
  message += "Zeige #{[filtered.count, limit].min} von #{filtered.count} Konzerten\n\n"
  message += concert_list

  event.edit_response(content: message)
end

bot.application_command(:refresh) do |event|
  event.defer

  concerts = get_concerts(force_refresh: true)

  if concerts.empty?
    event.edit_response(content: '⚠️ Keine neuen Konzertdaten gefunden. Scraper funktioniert möglicherweise nicht.')
  else
    event.edit_response(content: "✅ #{concerts.count} Konzerte neu geladen und gespeichert!")
  end
end

bot.ready do |_event|
  puts '✅ Bot ist bereit! Slash Commands registriert.'

  channel = bot.channel(CHANNEL_ID)
  if channel
    puts "✅ Bot schreibt in ##{channel.name}"
  else
    puts "⚠️ Channel mit ID #{CHANNEL_ID} nicht gefunden. Scheduler deaktiviert."
    next
  end

  scheduler = Rufus::Scheduler.new

  if ARGV[0] == 'test'
    puts '🧪 Test-Modus: Sende eine Nachricht und beende Bot...'

    concerts = upcoming_events
    if concerts.empty?
      message = "🎶 **Test: Hamburg Concert Bot** 🎶\nKeine Konzerte gefunden. Scraper funktioniert möglicherweise nicht."
    else
      concert_list = concerts.first(5).map do |c|
        "- #{c[:date]}: #{c[:artist]} @ #{c[:location]}"
      end.join("\n")

      message = <<~MSG
        🎶 **Test: Hamburg Concert Bot** 🎶
        Gefunden: #{concerts.count} Konzerte (zeige erste 5)

        #{concert_list}
      MSG
    end

    channel.send_message(message)
    puts '✅ Test-Nachricht gesendet!'
    exit
  end

  scheduler.cron '0 12 * * *' do
    concerts = upcoming_events.map do |c|
      "- #{c[:date]}: #{c[:artist]} @ #{c[:location]}"
    end.join("\n")

    message = <<~MSG
      🎶 **Konzerte in Hamburg (nächste 30 Tage)** 🎶
      #{concerts}
    MSG

    channel.send_message(message)
  rescue StandardError => e
    puts "Fehler beim Senden: #{e.message}"
  end
end

bot.run
