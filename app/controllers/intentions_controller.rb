class IntentionsController < ApplicationController
  before_action :set_intention, only: %i[show edit update destroy]

  def index
    @intentions = current_user.intentions.includes(:latest_guided_script).order(created_at: :desc)
  end

  def show
    @guided_scripts = @intention.guided_scripts.order(created_at: :desc)
  end

  def new
    @intention = current_user.intentions.build(length_minutes: 3, tone: "plain")
  end

  def create
    @intention = current_user.intentions.build(intention_params)
    if @intention.save
      redirect_to @intention
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @intention.update(intention_params)
      redirect_to @intention
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @intention.destroy
    redirect_to intentions_path
  end

  private

  def set_intention
    @intention = current_user.intentions.find(params[:id])
  end

  def intention_params
    params.require(:intention).permit(:sentence, :length_minutes, :tone)
  end
end
