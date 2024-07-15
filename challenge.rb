# frozen_string_literal: true

require 'json'
require 'stringio'

# The User class
class User
  attr_accessor :id, :first_name, :last_name, :email, :company_id, :email_status, :active_status, :tokens,
                :new_token_balance

  # Initializes a new User instance with the provided attributes.
  #
  # @param id [Integer] Unique identifier for the user
  # @param first_name [String] User's first name
  # @param last_name [String] User's last name
  # @param email [String] User's email address
  # @param company_id [Integer] ID of the associated company
  # @param email_status [Boolean] Email status
  # @param active_status [Boolean] Indicates if the user is active
  # @param tokens [Integer] Initial token count for the user
  def initialize(id:, first_name:, last_name:, email:, company_id:, email_status:, active_status:, tokens:)
    @id = id
    @first_name = first_name
    @last_name = last_name
    @email = email
    @company_id = company_id
    @email_status = email_status
    @active_status = active_status
    @tokens = tokens
    @new_token_balance = tokens # Initializes new_token_balance with the current tokens
  end

  # Checks if the user is active.
  #
  # @return [Boolean] True if the user is active; false otherwise
  def active?
    active_status == true
  end

  # Adds a specified amount to the user's new token balance.
  #
  # @param amount [Integer] The amount to add to the token balance
  def top_up(amount)
    self.new_token_balance += amount
  end
end

# The Company class
class Company
  attr_accessor :id, :name, :top_up, :email_status

  # Initializes a new Company instance with the provided attributes.
  #
  # @param id [Integer] Unique identifier for the account
  # @param name [String] Name associated with the account
  # @param top_up [Integer] Amount available for top-up
  # @param email_status [Boolean] Email status
  def initialize(id:, name:, top_up:, email_status:)
    @id = id
    @name = name
    @top_up = top_up
    @email_status = email_status
  end
end

# The BaseList class represents a collection of items.
# It provides functionality to initialize a list from an array
# and to load items from a JSON file.
class BaseList
  attr_reader :items

  # Initializes a new BaseList instance with an optional array of items.
  #
  # @param items [Array] An array of items to initialize the list with (default: empty array)
  def initialize(items = [])
    @items = items
  end

  # Loads a BaseList from a JSON file.
  #
  # @param file_name [String] The name of the JSON file to read
  # @return [BaseList] A new instance of BaseList populated with items from the JSON file
  def self.load_from_json(file_name)
    file_data = File.read(File.join(__dir__, file_name))
    json = JSON.parse(file_data, symbolize_names: true)
    list = []
    json.each do |item|
      list << list_class.new(**item)
    end
    new(list)
  end
end

# The CompanyList class extends the BaseList class to specifically manage
# a collection of Company objects
class CompanyList < BaseList
  # Returns the class of items contained in the CompanyList.
  #
  # @return [Class] The Company class that instances of this list will hold
  def self.list_class
    Company
  end
end

# The UserList class extends the BaseList class to specifically manage
# a collection of User objects
class UserList < BaseList
  def self.list_class
    User
  end

  # Filters the list to return users associated with a specific company.
  #
  # @param company_id [Integer] The ID of the company to filter users by
  # @return [Array<User>] An array of User objects that belong to the specified company
  def users_for_company(company_id)
    items.select { |u| u.company_id == company_id }
  end
end

# The DataProcessor class is responsible for processing companies and users.
class DataProcessor
  attr_reader :results, :errors

  # Initializes a new DataProcessor instance with empty results and errors arrays.
  def initialize
    @results = []
    @errors = []
  end

  # Checks if any errors occurred during processing.
  #
  # @return [Boolean] True if there are errors; false otherwise
  def errors?
    @errors.any?
  end

  # Processes company and user data from specified JSON files.
  #
  # @param companies_file_name [String] The name of the JSON file for companies (default: 'companies.json')
  # @param users_file_name [String] The name of the JSON file for users (default: 'users.json')
  def process(companies_file_name = 'companies.json', users_file_name = 'users.json')
    @results = []
    @errors = []
    begin
      company_list = CompanyList.load_from_json(companies_file_name)
      user_list = UserList.load_from_json(users_file_name)
    rescue StandardError => e
      @errors << "Failed to load json data. #{e.message}"
      return
    end
    # Sort companies by their IDs and process each company
    company_list.items.sort_by!(&:id).each do |company|
      company_item = {
        company: company,
        users_emailed: [],
        users_not_emailed: [],
        total_tops_up: 0
      }
      # Fetch the list of users for the current company
      company_users = user_list.users_for_company(company.id)
      company_users.each do |user|
        # add a token top up for active users
        if user.active?
          company_item[:total_tops_up] += company.top_up.to_i
          user.top_up(company.top_up.to_i)
        end
        # Check if email was sent.
        if company.email_status == true && user.email_status != false
          company_item[:users_emailed] << user
        else
          company_item[:users_not_emailed] << user
        end
      end
      # Sort users by last name
      company_item[:users_emailed].sort_by!(&:last_name)
      company_item[:users_not_emailed].sort_by!(&:last_name)
      @results << company_item
    end
  end
end

# The TxtRenderer class is responsible for rendering output data
# related to companies and users.
class TxtRenderer
  # Outputs user information in a formatted way for a given user.
  #
  # @param user [User] The user object containing user details
  # @return [String]
  def user_txt_partial(user)
    <<~USER
      \t\t#{user.last_name}, #{user.first_name}, #{user.email}
      \t\t\tPrevious Token Balance, #{user.tokens}
      \t\t\tNew Token Balance, #{user.new_token_balance}
    USER
  end

  # Outputs the entire prepared data in a readable text format.
  # @return [String]
  def render(data)
    output = StringIO.new
    data.each do |item|
      output << "\tCompany Id: #{item[:company].id}\n"
      output << "\tCompany Name: #{item[:company].name}\n"
      output << "\tUsers Emailed:\n"
      item[:users_emailed].each do |user|
        output << user_txt_partial(user)
      end
      output << "\tUsers Not Emailed:\n"
      item[:users_not_emailed].each do |user|
        output << user_txt_partial(user)
      end
      output << "\tTotal amount of top ups for #{item[:company].name}: #{item[:total_tops_up]}\n\n"
    end
    output.string
  end

  # Render errors.
  # @return [String]
  def render_errors(errors)
    output = StringIO.new
    output << "Errors:\n"
    errors.each do |error|
      output << "\t#{error}\n"
    end
    output.string
  end
end

processor = DataProcessor.new
processor.process('companies.json', 'users.json')
renderer = TxtRenderer.new
if processor.errors?
  puts renderer.render_errors(processor.errors)
else
  puts renderer.render(processor.results)
end
