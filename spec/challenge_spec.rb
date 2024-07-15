# frozen_string_literal: true

require_relative '../challenge'

describe User do
  before do
    @user = User.new(id: 1, first_name: 'John', last_name: 'Doe', email: 'johndoe@test.com', company_id: 1,
                     email_status: true, active_status: true, tokens: 75)
  end
  it 'should be initialized with id:, first_name:, last_name:, email:, company_id:, email_status:, active_status:, tokens:' do
    expect(@user.id).to eq(1)
    expect(@user.first_name).to eq('John')
    expect(@user.last_name).to eq('Doe')
    expect(@user.email).to eq('johndoe@test.com')
    expect(@user.company_id).to eq(1)
    expect(@user.email_status).to eq(true)
    expect(@user.active_status).to eq(true)
    expect(@user.tokens).to eq(75)
  end

  it 'should initialize new_token_balance with the current tokens' do
    expect(@user.new_token_balance).to eq(75)
  end

  it 'should properly show active? status' do
    expect(@user.active?).to eq(true)
    @user.active_status = false
    expect(@user.active?).to eq(false)
  end

  it 'should top up new token balance' do
    expect(@user.new_token_balance).to eq(75)
    @user.top_up(25)
    expect(@user.new_token_balance).to eq(100)
  end
end

describe Company do
  it 'should be initialized with id, :name, :top_up, :email_status' do
    company = Company.new(id: 1, name: 'Test Company', top_up: 100, email_status: true)
    expect(company.id).to eq(1)
    expect(company.name).to eq('Test Company')
    expect(company.top_up).to eq(100)
    expect(company.email_status).to eq(true)
  end
end

describe CompanyList do
  it 'should use Company for list class' do
    expect(CompanyList.list_class).to eq(Company)
  end
  it 'should load companies from json file' do
    list = CompanyList.load_from_json('companies.json')
    expect(list.items.count).to eq(6)
    company = list.items.first
    expect(company.id).to eq(1)
    expect(company.name).to eq('Blue Cat Inc.')
    expect(company.top_up).to eq(71)
    expect(company.email_status).to eq(false)
  end
end

describe UserList do
  it 'should use Company for list class' do
    expect(UserList.list_class).to eq(User)
  end
  it 'should load companies from json file' do
    list = UserList.load_from_json('users.json')
    expect(list.items.count).to eq(35)
    user = list.items.first
    expect(user.id).to eq(1)
    expect(user.first_name).to eq('Tanya')
    expect(user.last_name).to eq('Nichols')
    expect(user.email).to eq('tanya.nichols@test.com')
    expect(user.company_id).to eq(2)
    expect(user.email_status).to eq(true)
    expect(user.active_status).to eq(false)
    expect(user.tokens).to eq(23)
  end
end

describe DataProcessor do
  before do
    @processor = DataProcessor.new
    @processor.process('companies.json', 'users.json')
  end
  it 'should successfully process data' do
    expect(@processor.results.count).to eq(6)
    expect(@processor.errors.count).to eq(0)
  end

  it 'should order companies results by id' do
    expect(@processor.results.map { |res| res[:company].id }).to eq([1, 2, 3, 4, 5, 6])
  end

  it 'should calculate total top ups per company' do
    expect(@processor.results[0][:total_tops_up]).to eq(142)
    expect(@processor.results[1][:total_tops_up]).to eq(185)
  end

  describe 'users emailed for company with email_status = false' do
    before do
      @users_emailed = @processor.results.first[:users_emailed]
      @users_not_emailed = @processor.results.first[:users_not_emailed]
    end

    it 'should return list for users_emailed and users_not_emailed' do
      expect(@users_emailed.count).to eq(0)
      expect(@users_not_emailed.count).to eq(7)
    end

    it 'should order users by last_name' do
      expect(@users_not_emailed.map(&:last_name)).to eq(%w[Beck Carr Fox Gomez Jackson Lynch Pierce])
    end

    it 'should top up active users' do
      @users_not_emailed.each do |user|
        if user.active?
          expect(user.new_token_balance).to eq(user.tokens + 71)
        else
          expect(user.new_token_balance).to eq(user.tokens)
        end
      end
    end
  end

  describe 'users emailed for company with email_status = true' do
    before do
      @users_emailed = @processor.results[1][:users_emailed]
      @users_not_emailed = @processor.results[1][:users_not_emailed]
    end

    it 'should return list for users_emailed and users_not_emailed' do
      expect(@users_emailed.count).to eq(5)
      expect(@users_not_emailed.count).to eq(2)
    end

    it 'should order users by last_name' do
      expect(@users_emailed.map(&:last_name)).to eq(%w[Boberson Boberson Nichols Simpson Simpson])
      expect(@users_not_emailed.map(&:last_name)).to eq(%w[Gordon Weaver])
    end

    it 'should top up active users' do
      (@users_emailed + @users_not_emailed).each do |user|
        if user.active?
          expect(user.new_token_balance).to eq(user.tokens + 37)
        else
          expect(user.new_token_balance).to eq(user.tokens)
        end
      end
    end
  end
end

describe TxtRenderer do
  it 'should generate user partial txt' do
    user = User.new(id: 1, first_name: 'John', last_name: 'Doe', email: 'johndoe@test.com', company_id: 1,
                    email_status: true, active_status: true, tokens: 75)
    user.top_up(25)
    renderer = TxtRenderer.new
    user_txt = renderer.user_txt_partial(user)
    expect(user_txt).to match(/Doe, John, johndoe@test.com/)
    expect(user_txt).to match(/Previous Token Balance, 75/)
    expect(user_txt).to match(/New Token Balance, 100/)
  end

  it 'should generate txt output' do
    processor = DataProcessor.new
    processor.process('companies.json', 'users.json')
    renderer = TxtRenderer.new
    txt = renderer.render([processor.results.first])
    expect(txt).to match(/Company Id: 1/)
    expect(txt).to match(/Company Name: Blue Cat Inc./)
    expect(txt).to match(/Company Id: 1/)
    expect(txt).to match(/Users Emailed:/)
    expect(txt).to match(/Users Not Emailed:/)
    expect(txt).to match(/Total amount of top ups for Blue Cat Inc.: 142/)
  end

  it 'should generate txt output for errors' do
    renderer = TxtRenderer.new
    txt = renderer.render_errors(['This is an error message'])
    expect(txt).to match(/Errors:/)
    expect(txt).to match(/This is an error message/)
  end
end
