class Api::ReservesController < ApplicationController
  before_action :validate_access

  def create
    borrowernumber = params[:reserve][:user_id]
    branchcode = params[:reserve][:location_id]
    biblionumber = params[:reserve][:biblio_id]
    itemnumber = params[:reserve][:item_id]
    loantype = params[:reserve][:loan_type_id]
    reservenotes = params[:reserve][:reserve_notes]
    subscriptionnotes = params[:reserve][:subscription_notes]
    subscriptionlocation = params[:reserve][:subscription_location]
    subscriptionsublocation = params[:reserve][:subscription_sublocation]
    subscriptioncallnumber = params[:reserve][:subscription_call_number]

    error_list = Array.new
    error_list.push({code: "MISSING_USER", detail: "Required user_id is missing."}) if borrowernumber.blank?
    error_list.push({code: "MISSING_LOCATION", detail: "Required location_id is missing."}) if branchcode.blank?
    error_list.push({code: "MISSING_BIBLIO", detail: "Required biblio_id is missing."}) if biblionumber.blank?
    if loantype.blank?
      error_list.push({code: "MISSING_LOAN_TYPE", detail: "Required loan_type_id is missing."})
    else
      loan_type_obj = LoanType.find_by_id(loantype.to_i)
      if loan_type_obj
        loan_type_name = loan_type_obj.name_sv
      else
        loan_type_name = ''
      end
      reservenotes = reserve_notes(loan_type_name, reservenotes, subscriptionnotes, subscriptionlocation, subscriptionsublocation, subscriptioncallnumber)
      #reservenotes = "Lånetyp: #{loan_type_name} \n#{(reservenotes.present? ? reservenotes : '')} \n#{(subscriptionnotes.present? ? subscriptionnotes : '')}"
    end
    if error_list.present?
      error_msg(ErrorCodes::UNPROCESSABLE_ENTITY, "At least one parameter was not valid.", error_list)
      render_json
      return
    end

    # Check that requested user is same as current user
    user_id = borrowernumber.to_i
    currentuser_id = AccessToken.find_by_username(@current_username).user_id
    if user_id != currentuser_id
      error_msg(ErrorCodes::UNAUTHORIZED, "Requested user must be same same as logged in user")
      render_json
      return
    end

    # If no validation errors were stored in response connect to Koha
    if @response[:errors].nil?
      result = Reserve.add(borrowernumber: borrowernumber, branchcode: branchcode, biblionumber: biblionumber, itemnumber: itemnumber, reservenotes: reservenotes)
      if result.class == Reserve
        @response[:reserve] = result.as_json
        render_json(201)
        return
      elsif result.class == Hash
        if result[:code] == 400
          error_msg(ErrorCodes::BAD_REQUEST, result[:msg], result[:errors])
        end
        if result[:code] == 403
          error_msg(ErrorCodes::FORBIDDEN, result[:msg], result[:errors])
        end
        if result[:code] == 404
          error_msg(ErrorCodes::NOT_FOUND, result[:msg], result[:errors])
        end
        if result[:code] == 500
          error_msg(ErrorCodes::INTERNAL_SERVER_ERROR, result[:msg], result[:errors])
        end
      else
        error_msg(ErrorCodes::INTERNAL_SERVER_ERROR, "Error when creating a reserve")
      end
    end
    render_json
  end

  def reserve_notes(loan_type_name, reservenotes, subscriptionnotes, subscriptionlocation, subscriptionsublocation, subscriptioncallnumber)
    notes = Array.new
    notes << "Lånetyp: #{loan_type_name}"
    notes << reservenotes
    notes << subscriptionnotes
    notes << subscriptionlocation
    notes << subscriptionsublocation
    notes << subscriptioncallnumber
    notes.delete_if{|e|e.blank?}
    notes.join("\n")
  end
end
