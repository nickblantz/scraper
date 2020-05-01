module LinkAnalyzer
  require 'uri'

  def self.configure(config)
    @host_whitelist = config['hostWhitelist']
  end

  def self.accepted_host?(uri)
    return uri.scheme == 'http' || uri.scheme == 'https'
  end

  def self.whitelist_contains?(uri)
    for host in @host_whitelist.each do
      return true if uri.host.include?(host)
    end

    return false
  end

  def self.has_path?(uri)
    return !uri.path.nil?
  end

  def self.same_page?(uri, cur_uri)
    uri.fragment = nil
    cur_uri.fragment = nil
    return uri.to_s == cur_uri.to_s
  end

  def self.analyze(link, cur_page)
    begin
      link_uri = URI(link)
      cur_uri = URI(cur_page)
      return false unless accepted_host?(link_uri)
      # return false unless whitelist_contains?(link_uri)
      return false unless has_path?(link_uri)
      return false if same_page?(link_uri, cur_uri)
    rescue URI::Error => e
      return false
    rescue Exception => e
      puts "error analyzing link #{e}"
      return false
    end
    return true
  end
end
