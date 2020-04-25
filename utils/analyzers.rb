module LinkAnalyzer
  require 'uri'

  HOST_WHITELIST = ['ebay.com', 'amazon.com', 'craigslist.org', 'walmart.com', 'target.com', 'sears.com', 'wish.com', 'kohls.com', 'costco.com', 'aliexpress.com']

  def self.accepted_host?(uri)
    uri.scheme != 'http' && uri.scheme != 'https'
  end

  def self.same_page?(uri, page)
    result = uri.clone()
    result.fragment = nil
    result.to_s == page
  end

  def self.whitelist_contains?(uri)
    for host in HOST_WHITELIST.each do
      return true if uri.host.include? host
    end

    false
  end

  def self.analyze(link, cur_page)
    puts "analyzing #{link}"
    begin
      link_uri = URI(link)
      return false if accepted_host?(link_uri)
      return false if same_page?(link_uri, cur_page)
      return false unless whitelist_contains?(link_uri)
    rescue URI::InvalidURIError
      false
    end

    true
  end
end

module ContentAnalyzer

  def self.longest_common_substring(s0, s1)
    table = Array.new(s0.length, Array.new(s1.length, 0))
    result = Hash.new()
    longest = 0

    s0.split('').each_with_index { |c0, i0|
      s1.split('').each { |c1, i1|
        next if c0 != c1
        table[i0][i1] = (i0 == 0 || i1 == 0 ) ? 1 : table[i0 - 1][i1 - 1] + 1
        if table[i0][i1] > longest
          longest = table[i0][i1]
          result.clear()
        end
        if table[i0][i1] = longest
          result.add(c0[(s0 - longest + 1) ... (s0 + 1)])
        end
      }
    }

    result
  end
end
