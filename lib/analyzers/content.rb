module ContentAnalyzer
  def self.configure(config, logger)
    @logger = logger
    @for_sale_whitelist = config['forSaleWhitelist']
    @min_least_common_substring_length = config['minLongestCommonSubstringLength']
    @logger.info 'Content analyzer configured'
    @configured = true
  end

  def self.analyze(content, recall)
    begin
      product_names = ( recall['Products'].map { |product| product['Name'] } ).join(" | ")
      return false unless longest_common_substring_length?(content, product_names)
      return false unless has_sale?(content)
    rescue Exception => e
      @logger.error 'Could not analyze content'
      @logger.debug e.to_s
      @logger.trace e
      return false
    end
    @logger.info "Content analysis succeeded"
    return true
  end

  private
  
  def self.longest_common_substring_length?(content, search)
    table = Array.new(search.length) { Array.new(content.length, 0) }
    result = ''
    longest = 0

    search.split('').each_with_index { |c0, i0|
      content.split('').each_with_index { |c1, i1|
        next unless c0.casecmp?(c1)
        table[i0][i1] = (i0.zero? || i1.zero?) ? 1 : table[i0 - 1][i1 - 1] + 1
        if table[i0][i1] > longest
          longest = table[i0][i1]
          result = search[i0 - longest + 1, longest]
        end
      }
    }

    if longest >= @min_least_common_substring_length
      @logger.debug "Least common sunstring succeeded for: #{result}" 
      return true
    end
  end

  def self.has_sale?(content)
    for string in @for_sale_whitelist
      return true if content.include?(string)
    end
    
    return false
  end
end
