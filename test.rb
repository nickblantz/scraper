require 'uri'
module LinkAnalyzer
  require 'uri'

  def self.configure(config)
    @host_whitelist = config['hostWhitelist']
  end

  def self.same_page?(uri, page)
    temp = uri.clone()
    temp.fragment = nil
    return temp.to_s == page
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

  def self.analyze(link, cur_page)
    begin
      link_uri = URI(link)
      return false if same_page?(link_uri, cur_page)
      return false unless accepted_host?(link_uri)
      return false unless whitelist_contains?(link_uri)
    rescue Exception => e
      return false
    end
    return true
  end
end

puts LinkAnalyzer::same_page?(URI('https://www.ebay.com/p/1100188280?iid=401853825261#UserReviews'), 'https://www.ebay.com/p/1100188280?iid=401853825261')