# Every real endpoint either handles its Discogs failures locally or can only
# raise one kind, so this stand-in exists to drive Api::BaseController's whole
# rescue_from table from a real request.
class ExplodingController < Api::BaseController
  def show
    raise params[:kind].constantize, "estourou"
  end
end
