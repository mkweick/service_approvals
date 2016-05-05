require 'odbc'

class ApprovalsController < ApplicationController
  before_action :valid_order?, only: [:index]

  def index
    
  end

  def approve
    @ponum = params[:ponum].strip unless params[:ponum].strip.blank?
    repair_key = params[:repairkey]

    as400_83m = ODBC.connect('approvals_m')

    if @ponum
      sql_update_order = "UPDATE toolr_logt
                          SET tlstatus04 = '4',
                              tlpono = '#{@ponum}'
                          WHERE tllinkkey = '#{repair_key}'"
    else
      sql_update_order = "UPDATE toolr_logt
                          SET tlstatus04 = '4'
                          WHERE tllinkkey = '#{repair_key}'"
    end
        
    as400_83m.run(sql_update_order)
    
    as400_83m.commit
    as400_83m.disconnect
  end

  def decline
    repair_key = params[:repairkey]

    as400_83m = ODBC.connect('approvals_m')

    sql_update_order = "UPDATE toolr_logt
                        SET tlstatus03 = '3'
                        WHERE tllinkkey = '#{repair_key}'"
        
    as400_83m.run(sql_update_order)
    
    as400_83m.commit
    as400_83m.disconnect
  end

  private

  def valid_order?
    if params[:repairkey].nil?
      redirect_to 'http://www.divalsafety.com'
    else
      repair_key = params[:repairkey].strip
      as400_83m = ODBC.connect('approvals_m')

      sql_find_order = "SELECT a.tlorno, a.tlstatus03, a.tlstatus04, a.tlticket,
                                c.cmcsno, c.cmcsnm, b.trmodel, b.trserial, d.tt$tot
                        FROM toolr_logt AS a
                        JOIN toolrpctl AS b ON b.trticket = a.tlticket
                        JOIN aplus83fds.cusms AS c ON c.cmcsno = b.trcsno
                        JOIN tooltot AS d ON d.ttpror = a.tlpror
                        WHERE tllinkkey = '#{repair_key}'"
          
      stmt_find_order = as400_83m.run(sql_find_order)
      order = stmt_find_order.fetch_all
      
      as400_83m.commit
      as400_83m.disconnect

      if order.nil?
        flash.alert = "This is not a valid repair ticket."
      else
        order = order.first.map(&:strip)
        order_num = order[0]
        @declined = order[1] == '3'
        @accepted = order[2] == '4'
        @ticket_num = order[3]
        @cust_num = order[4]
        @cust_name = order[5]
        @model_num = order[6]
        @serial_num = order[7]
        @order_total = order[8]

        if @accepted
          flash.notice = "Ticket #{@ticket_num} has already been approved"
        elsif @declined
          flash.alert = "Ticket #{@ticket_num} has already been declined"
        end
      end
    end
  end
end