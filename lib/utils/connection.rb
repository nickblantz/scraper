module ConnectionUtils
  require 'mysql2'
  
  def self.configure(logger)
    @logger = logger
    @logger.info 'Connection utilities config'
    @configured = true
  end

  def self.create_recall(
    connection: nil,
    recall_id: 0,
    recall_number: '',
    high_priority: false,
    date: '',
    sortable_date: '',
    recall_heading: '',
    name_of_product: '',
    description: '',
    hazard: '',
    remedy_type: '',
    units: '',
    conjunction_with: '',
    incidents: '',
    remedy: '',
    sold_at: '',
    distributors: '',
    manufactured_in: ''
  )
    begin
      connection.query("INSERT INTO fullrecallapi (  `recall_id`,    `recall_number`,   `high_priority`,   `date`,    `sortable_date`,    `recall_heading`,    `name_of_product`,    `description`,    `hazard`,    `remedy_type`,    `units`,    `conjunction_with`,    `incidents`,    `remedy`,    `sold_at`,    `distributors`,    `manufactured_in`) 
        VALUES ('#{recall_id}', '#{recall_number}', #{high_priority}, '#{date}', '#{sortable_date}', '#{recall_heading}', '#{name_of_product}', '#{description}', '#{hazard}', '#{remedy_type}', '#{units}', '#{conjunction_with}', '#{incidents}', '#{remedy}', '#{sold_at}', '#{distributors}', '#{manufactured_in}')")
    rescue Mysql2::Error => e
      @logger.error "Could not create recall #{recall_id}"
      @logger.debug e.to_s
      @logger.trace e
    end
   end

  def self.create_violation(
    connection: nil,
    violation_date: '',
    url: '',
    title: '',
    screenshot_file: '',
    recall_id: 0,
    violation_status: ''
  )
    begin
      connection.query("INSERT INTO Violation (`violation_date`, `url`, `title`, `screenshot_file`, `recall_id`, `violation_status`)
        VALUES ('#{violation_date}', '#{url}', '#{title}', '#{screenshot_file}', #{recall_id}, '#{violation_status}')")
    rescue
      @logger.error 'Could not create violation'
      @logger.debug e.to_s
      @logger.trace e
    end
   end
end