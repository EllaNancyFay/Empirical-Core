require 'spec_helper'

describe District, type: :model do
  describe 'setup from clever', :vcr do
    it 'passes an auth hash for a district to be setup' do
      @district = District.setup_from_clever({
        info: {
          name: 'Fake District',
          id: '535e91b05fc8cb160e001645'
        },
        credentials: {
          token: '123'
        }
      })

      expect(@district.valid?).to be_truthy
      expect(@district.id).to_not be_nil
      expect(@district.name).to eq('Fake District')

      expect(Classroom.count).to eq(4)
      expect(User.teacher.count).to eq(5)
      expect(User.student.count).to eq(37)
    end
  end

  describe 'create from clever', :vcr do
    it 'gets data from clever' do
      @district = District.create_from_clever('535e91b05fc8cb160e001645')

      expect(@district.name).to eq('#DEMO Clever Team Testing')
      expect(@district.valid?).to be_truthy
      expect(@district.id).to_not be_nil

      expect(Classroom.count).to eq(4)
      expect(User.teacher.count).to eq(5)
      expect(User.student.count).to eq(37)
    end
  end

  describe 'importing users', :vcr do
    before do
      @district = District.create({
        clever_id: '535e91b05fc8cb160e001645',
        name: '#DEMO Clever Team Testing'
      })

      @school = School.create({
        name: 'Test School',
        clever_id: '535ea6e0e17efb3e297374f2'
      })
    end

    it 'finds its clever district' do
      d = @district.send(:clever_district)

      expect(d.id).to eq(@district.clever_id)
      expect(d.name).to eq(@district.name)
    end

    it 'imports from clever' do
      @district.import_from_clever!

      expect(Classroom.count).to eq(4)
      expect(User.teacher.count).to eq(5)
      expect(User.student.count).to eq(37)

      expect(@school.users.teacher.count).to eq(5)
      expect(@school.users.student.count).to eq(32)

      c = Classroom.first
      expect(c.name).to eq('Development 101')
      expect(c.students.count).to eq(16)
      expect(c.teacher.clever_id). to eq('535ea6e416b90a4529c18fd3')
    end
  end
end