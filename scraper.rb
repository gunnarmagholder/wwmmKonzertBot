require 'nokogiri'
require 'ferrum'
require 'net/http'
require 'json'
require 'fileutils'

DATA_FILE = 'concerts.json'

def scrape_songkick(days_ahead: 30)
  browser = Ferrum::Browser.new(headless: true, timeout: 30)
  browser.goto('https://www.songkick.com/metro-areas/28498-germany-hamburg')

  sleep 5

  browser.execute('window.scrollTo(0, document.body.scrollHeight);')
  sleep 2

  doc = Nokogiri::HTML(browser.body)
  concerts = []

  puts 'Suche nach Events auf der Seite...'
  puts "Gefundene Links mit 'concert' oder 'tour': #{doc.css('a').select do |a|
    a['href']&.include?('concert') || a['href']&.include?('tour')
  end.count}"

  selectors = [
    'li.event-listings-element',
    '.event-listing',
    '.concert-listing',
    'li[class*="event"]',
    'div[class*="event"]',
    'a[href*="concerts"]'
  ]

  selectors.each do |selector|
    elements = doc.css(selector)
    puts "Selector '#{selector}': #{elements.count} Elemente gefunden"

    elements.each do |event|
      puts "Event HTML: #{event.to_html[0..200]}..." if elements.count < 10

      artist = extract_text(event, ['.artists', '.artist', 'strong', 'h3', '.summary'])
      venue = extract_text(event, ['.venue', '.location', '.venue-name'])
      date_text = extract_text(event, ['.date', 'time', '.event-date']) ||
                  event.at_css('time')&.[]('datetime')

      date = parse_date(date_text)

      next unless artist && venue && date

      puts "Gefunden: #{artist} @ #{venue} am #{date}"
      next if date < Date.today
      next if date > Date.today + days_ahead

      concerts << {
        date: date.strftime('%Y-%m-%d'),
        artist: artist,
        location: venue
      }
    end

    break if concerts.any?
  end

  browser.quit
  puts "Insgesamt #{concerts.count} Konzerte gefunden"
  concerts
rescue StandardError => e
  puts "Fehler beim Scrapen: #{e.message}"
  puts e.backtrace.first(3)
  browser&.quit
  []
end

def extract_text(element, selectors)
  selectors.each do |selector|
    text = element.at_css(selector)&.text&.strip
    return text if text && !text.empty?
  end
  nil
end

def parse_date(date_text)
  return nil unless date_text

  formats = [
    '%Y-%m-%d',
    '%d.%m.%Y',
    '%m/%d/%Y',
    '%B %d, %Y',
    '%d %B %Y',
    '%a, %d %b %Y'
  ]

  formats.each do |format|
    return Date.strptime(date_text, format)
  rescue Date::Error
    next
  end

  begin
    Date.parse(date_text)
  rescue StandardError
    nil
  end
end

def scrape_allevents(days_ahead: 30)
  []
end

def save_concerts(concerts)
  data = {
    last_updated: Time.now.iso8601,
    concerts: concerts
  }
  File.write(DATA_FILE, JSON.pretty_generate(data))
  puts "💾 #{concerts.count} Konzerte in #{DATA_FILE} gespeichert"
end

def load_concerts
  return [] unless File.exist?(DATA_FILE)

  data = JSON.parse(File.read(DATA_FILE))
  puts "📂 #{data['concerts']&.count || 0} Konzerte aus #{DATA_FILE} geladen (letzte Aktualisierung: #{data['last_updated']})"
  data['concerts'] || []
rescue JSON::ParserError => e
  puts "⚠️ Fehler beim Laden der Daten: #{e.message}"
  []
end

def get_concerts(days_ahead: 30, force_refresh: false)
  if force_refresh || !File.exist?(DATA_FILE) || file_older_than_hours?(DATA_FILE, 6)
    puts '🔄 Lade neue Konzertdaten von Songkick...'
    concerts = scrape_songkick(days_ahead: days_ahead)
    save_concerts(concerts) if concerts.any?
    concerts
  else
    puts '📂 Verwende gespeicherte Konzertdaten...'
    load_concerts
  end
end

def file_older_than_hours?(filepath, hours)
  return true unless File.exist?(filepath)

  (Time.now - File.mtime(filepath)) > (hours * 3600)
end

def filter_concerts(concerts, options = {})
  filtered = concerts.dup

  filtered = filtered.select { |c| c['artist']&.downcase&.include?(options[:artist].downcase) } if options[:artist]

  filtered = filtered.select { |c| c['location']&.downcase&.include?(options[:venue].downcase) } if options[:venue]

  filtered = filtered.select { |c| c['date'] >= options[:from_date] } if options[:from_date]

  filtered = filtered.select { |c| c['date'] <= options[:to_date] } if options[:to_date]

  filtered.sort_by { |c| c['date'] }
end
