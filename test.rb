require 'date'

def generate_sortable_date(date)
  date.match(/([a-zA-Z]+) ([\d]{1,2}), ([\d]{1,4})/) { |m|
    return '' if m.captures[0].nil? || m.captures[1].nil? || m.captures[2].nil?

    day = m.captures[1].rjust(2, '0')
    month = Date.strptime(m.captures[0], '%B').month.to_s.rjust(2, '0')
    year = m.captures[2].rjust(4, '0')
    return year + '/' + month + '/' + day
  }
end

puts generate_sortable_date('April 1, 1')