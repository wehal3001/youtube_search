require 'rexml/document'
require 'cgi'
require 'open-uri'

module YoutubeSearch
  def self.search(query, options={})
    @debug = options_with_debug(options)

    options = options_with_per_page_and_page(options)
    debug "query string: " + query.inspect
    debug "options hash: " + options.inspect

    query = options.merge(:q => query).map{|k,v| "#{CGI.escape k.to_s}=#{CGI.escape v.to_s}" }.join('&')
    url = "http://gdata.youtube.com/feeds/api/videos?#{query}"
    debug "resulting url: " + url

    xml = open(url).read
    array = parse(xml)

    debug "videos returned: " + array.size.to_s
		totalresults = get_totalresults(xml)
		debug "total videos: " + totalresults.to_s

    array
  end

  def self.playlist_videos(playlist_id)
    playlist_id = playlist_id.sub(/^PL/, "")
    xml = open("http://gdata.youtube.com/feeds/api/playlists/#{playlist_id}?v=2").read
    parse(xml, :type => :playlist)
  end

  def self.parse(xml, options={})
    elements_in(xml, 'feed/entry').map do |element|
      entry = xml_to_hash(element)
      entry['video_id'] = if options[:type] == :playlist
        element.elements['*/yt:videoid'].text
      else
        entry['id'].split('/').last
      end

      duration = element.elements['*/yt:duration']
      entry['duration'] = duration.attributes['seconds'] if duration

      no_embed = element.elements['yt:noembed'] || element.elements['yt:private']
      entry['embeddable'] = !(no_embed)

      entry['raw'] = element

      entry
    end
  end

  private

  def self.elements_in(xml, selector)
    entries = []
    doc = REXML::Document.new(xml)
    doc.elements.each(selector) do |element|
      entries << element
    end
    entries
  end

  def self.xml_to_hash(element)
    Hash[element.children.map do |child|
      [child.name, child.text]
    end]
  end

  def self.get_totalresults(xml)
    doc = REXML::Document.new(xml)
    doc.elements['feed/openSearch:totalResults'].text.to_i
  end

  def self.options_with_debug(options)
    return true if options.delete(:debug)
    false
  end

  def self.debug(string)
    puts "[DEBUG] " + string if @debug
  end

  def self.options_with_per_page_and_page(options)
    options = options.dup
    if per_page = options.delete(:per_page)
      options['max-results'] = per_page
    else
      per_page = options['max-results']
    end

    if per_page and page = options.delete(:page)
      options['start-index'] = per_page.to_i * ([page.to_i, 1].max - 1)
    end

    options
  end
end
