module LinkAnalyzer
  require 'uri'

  HOST_WHITELIST = ['www.ebay.com', 'www.amazon.com', 'craigslist.org', 'www.walmart.com', 'www.target.com', 'www.sears.com', 'www.wish.com', 'www.kohls.com', 'www.costco.com', 'www.aliexpress.com']

  def self.configure(config)
    @host_whitelist = config['hostWhitelist']
  end

  def self.same_page?(uri, page)
    result = uri.clone()
    result.fragment = nil
    return result.to_s == page
  end

  def self.accepted_host?(uri)
    return uri.scheme == 'http' || uri.scheme == 'https'
  end

  def self.whitelist_contains?(uri)
    for host in HOST_WHITELIST.each do
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

module ContentAnalyzer
  MIN_LCS_LENGTH = 15
  FOR_SALE_WHITELIST = ['For Sale', 'for sale', 'selling', 'price']

  def self.configure(config)
    @min_least_common_substring_length = config['minLeastCommonSubstringLength']
    @for_sale_whitelist = config['forSaleWhitelist']
  end

  def self.longest_common_substring_length?(content, search)
    table = Array.new(search.length, Array.new(content.length, 0))
    result = ''
    longest = 0

    search.split('').each_with_index { |c0, i0|
      content.split('').each_with_index { |c1, i1|
        next unless c0.casecmp?(c1)
        table[i0][i1] = (i0 == 0 || i1 == 0) ? 1 : table[i0 - 1][i1 - 1] + 1
        if table[i0][i1] > longest
          longest = table[i0][i1]
          result = search[i0 - longest + 1, longest]
        end
      }
    }

    # puts 'content analysis result: ' + result
    return longest >= MIN_LCS_LENGTH
  end

  def self.has_sale?(content)
    for string in FOR_SALE_WHITELIST
      return true if content.include?(string)
    end
    
    return false
  end

  def self.analyze(content, recall)
    product_names = ( recall['Products'].map { |product| product['Name'] } ).join(" | ")

    return false unless longest_common_substring_length?(content, product_names)
    return false unless has_sale?(content)
    
    return true
  end
end
