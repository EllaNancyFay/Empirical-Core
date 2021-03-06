class Teachers::ClassroomManagerController < ApplicationController
  respond_to :json, :html
  before_filter :teacher!
  before_filter :authorize!
  include ScorebookHelper

  def lesson_planner
    if current_user.classrooms_i_teach.empty?
      redirect_to new_teachers_classroom_path
    else
      @tab = params[:tab] #|| "manageUnits"
      @grade = params[:grade]
      @students_exist = current_user.students.any?
      @last_classroom_name = current_user.classrooms_i_teach.last.name
      @last_classroom_id = current_user.classrooms_i_teach.last.id
    end
  end

  def retrieve_classrooms_for_assigning_activities # in response to ajax request
    current_user.classrooms_i_teach.includes(:students).each do |classroom|
      obj = {
        classroom: classroom,
        students: classroom.students.sort_by(&:sorting_name)
      }
      ( @classrooms_and_their_students ||= [] ).push obj
    end
    #render partial: 'assign', layout: false
    render json: {
      classrooms_and_their_students: @classrooms_and_their_students
    }
  end

  def invite_students
    @classrooms = current_user.classrooms_i_teach
  end

  def scorebook
    if current_user.classrooms_i_teach.empty?
      redirect_to new_teachers_classroom_path
    end

    if current_user.students.empty?
      if current_user.classrooms_i_teach.last.activities.empty?
        redirect_to(controller: "teachers/classroom_manager", action: "lesson_planner", tab: "exploreActivityPacks", grade: current_user.classrooms_i_teach.last.grade)
      else
        redirect_to teachers_classroom_invite_students_path(current_user.classrooms_i_teach.last)
      end
    end
  end

  def dashboard
    if current_user.classrooms_i_teach.empty?
      redirect_to new_teachers_classroom_path
    end
  end

  def premium
    @subscription_type = current_user.premium_state
    render json: {
      hasPremium: @subscription_type,
      trial_days_remaining: current_user.trial_days_remaining,
      first_day_of_premium_or_trial: current_user.premium_updated_or_created_today?
    }
  end



  def classroom_mini
    current_user.classrooms_i_teach.includes(:students).each do |classroom|
      obj = {
        classroom: classroom,
        students: classroom.students.count,
        activities_completed: classroom.activity_sessions.where(state: "finished").count
      }
      ( @classrooms ||= [] ).push obj
    end
    render json: {
      classes: @classrooms
    }
  end

  def dashboard_query
    @query_results = Dashboard.queries(current_user)
    render json: {
      performanceQuery: @query_results
    }
  end

  def scores
    classrooms = current_user.classrooms_i_teach.includes(classroom_activities: [:unit])
    units = classrooms.map(&:classroom_activities).flatten.map(&:unit).uniq.compact
    if params[:no_load_has_ever_occurred_yet] == 'true'
      params[:classroom_id] = current_user.classrooms_i_teach.first
      was_classroom_selected_in_controller = true
      selected_classroom = Classroom.find params[:classroom_id]
    else
      was_classroom_selected_in_controller = false
      selected_classroom = nil
    end

    scores, is_last_page = current_user.scorebook_scores params[:current_page].to_i, params[:classroom_id], params[:unit_id], params[:begin_date], params[:end_date]
    render json: {
      teacher: Scorebook::TeacherSerializer.new(current_user).as_json(root: false),
      classrooms: classrooms,
      units: units,
      scores: scores,
      is_last_page: is_last_page,
      was_classroom_selected_in_controller: was_classroom_selected_in_controller,
      selected_classroom: selected_classroom
    }
  end

  # needed to simply render a page, lets React.js do the rest
  def my_account
  end

  def my_account_data
    render json: current_user.generate_teacher_account_info
  end

  def update_my_account

    # incoming request

    # var data = {
    #   name: this.state.name,
    #   username: this.state.username,
    #   email: this.state.email,
    #   password: this.state.password,
    #   password_confirmation: this.state.passwordConfirmation,
    #   school_id: this.state.selectedSchool.id,
    #   school_options_do_not_apply: this.state.schoolOptionsDoNotApply
    # }

    response = current_user.update_teacher params
    render json: response
  end

  def delete_my_account
    sign_out
    User.find(params[:id]).destroy
    render json: {}
  end

  private

  def authorize!
    if current_user.classrooms_i_teach.any?
      if params[:classroom_id].present? and params[:classroom_id].length > 0
        @classroom = Classroom.find(params[:classroom_id])
      end

      @classroom ||= current_user.classrooms_i_teach.first
      auth_failed unless @classroom.teacher == current_user
    end
  end
end
