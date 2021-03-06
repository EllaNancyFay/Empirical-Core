require 'rails_helper'

describe ClassroomActivity, type: :model do

  let!(:activity){ FactoryGirl.create(:activity) }
  let!(:teacher) { FactoryGirl.create(:user, role: 'teacher') }
  let!(:student){ FactoryGirl.create(:user, role: 'student', username: 'great', name: 'hi hi', password: 'pwd') }
  let!(:classroom) { FactoryGirl.create(:classroom, teacher: teacher, code: 'great', name: 'great', students: [student]) }
  let!(:classroom_activity) { ClassroomActivity.create(activity: activity, classroom: classroom) }


  describe "#destroy" do
  	it 'should destroy associated activity_sessions' do
  		classroom_activity.destroy
  		expect(student.activity_sessions.count).to eq(0)
  	end
  end

  describe "#assigned_students" do

    it 'must be empty if none assigned' do
    	expect(classroom_activity.assigned_students).to be_empty
    end

    context "when there is an assigned student" do

    	let(:classroom) { Classroom.new(code: '101') }
    	before do
	      @student = classroom.students.build(first_name: 'John', last_name: 'Doe')
	      @student.generate_student(classroom.id)
	      @student.save!
    	end
	    it "must return a list with one element" do
	    	classroom_activity=FactoryGirl.build(:classroom_activity, assigned_student_ids: [@student.id])
	    	expect(classroom_activity.assigned_students.first ).to eq(@student)
	    end
	end
  end

  context "when it has a due_date_string attribute" do

  	describe "#due_date_string=" do
	  	it "must have a due date setter" do
	  		expect(classroom_activity.due_date_string="03/02/2012").to eq("03/02/2012")
	  	end
	  	it "must throw an exception whn not valid input" do
	  		expect{classroom_activity.due_date_string="03-02-2012"}.to raise_error ArgumentError
	  	end
	end

	describe "#due_date_string" do
		before do
			classroom_activity.due_date_string="03/02/2012"
		end
		it "must have a getter" do
			expect(classroom_activity.due_date_string).to  eq("03/02/2012")
		end
	end

  end

  describe "session_for" do

  		let(:classroom) { FactoryGirl.create(:classroom, code: '101') }
  		let(:student){ classroom.students.create(first_name: 'John', last_name: 'Doe') }

    	before do
	      student.generate_student(classroom.id)
    	end

	  	it "must start a session for the given user" do
	  		expect(classroom_activity.session_for(student)).to be_valid
	  	end
	  	it "must raise an error when user's input is not valid" do
	  		expect{classroom_activity.session_for(0)}.to raise_error
	  	end
  end


end
