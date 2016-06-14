require 'odbc'

class ApprovalsController < ApplicationController

  def index
    if params[:repairkey].blank? && params[:promokey].blank?
      redirect_to 'http://www.divalsafety.com'
    else
      params[:repairkey] ? display_repair_approval : display_promo_approval
    end
  end

  def approve_repair
    case params[:approve_code]
    when 'po' then @ponum = params[:ponum].strip
    when 'verbal' then @ponum = params[:verbal].strip
    when 'credit_card' then @credit_card = true
    end

    repair_key = params[:repairkey]

    as400_83m = ODBC.connect('approvals_m')

    if @ponum
      sql_update_order = "UPDATE toolr_log
                          SET tlstatus04 = '4',
                              tlpono = '#{@ponum}'
                          WHERE tllinkkey = '#{repair_key}'"
    elsif @credit_card
      sql_update_order = "UPDATE toolr_log
                          SET tlstatus04 = '4',
                              tlpono = '',
                              tlcrdcust = 'Y'
                          WHERE tllinkkey = '#{repair_key}'"
    else
      sql_update_order = "UPDATE toolr_log
                          SET tlstatus04 = '4'
                          WHERE tllinkkey = '#{repair_key}'"
    end

    as400_83m.run(sql_update_order)
    
    as400_83m.commit
    as400_83m.disconnect
  end

  def decline_repair
    @decline_code = params[:decline_code]
    repair_key = params[:repairkey]

    case @decline_code
    when 'quote'
      decline_code = '1'
      @decline_reason = "We will be quoting you on a new peice of<br />equipment and we'll reach out to you shortly!".html_safe
    when 'scrap'
      decline_code = '2'
      @decline_reason = "We will be scrapping your equipment.<br />If this is a mistake, please call 1-800-343-1354.".html_safe
    when 'return'
      decline_code = '3'
      @decline_reason = "We will be returning your equipment unrepaired.<br />If this is a mistake, please call 1-800-343-1354.".html_safe
    end

    as400_83m = ODBC.connect('approvals_m')

    sql_update_order = "UPDATE toolr_log
                        SET tlstatus03 = '3',
                            tldeclinc = '#{decline_code}'
                        WHERE tllinkkey = '#{repair_key}'"
        
    as400_83m.run(sql_update_order)
    
    as400_83m.commit
    as400_83m.disconnect
  end

  def approve_promo 
    company_num = params[:company_num]
    parent_order_num = params[:parent_order_num]
    order_num = params[:order_num]
    order_gen_num = params[:order_gen_num]
    cust_num = params[:cust_num]
    cust_name = params[:cust_name]
    po_num = params[:po_num]
    promo_key = params[:promokey]
    now = Time.now
    date = now.strftime("%Y%m%d")
    time = now.strftime("%H%M%S")

    as400_83m = ODBC.connect('approvals_m')

    sql_insert_approval = "INSERT INTO promo_log (
                              plcono, plpror, plorno, plorgn, plcsno,
                              plcsnm, plcspo, plstatus, pluser, pldate, 
                              pltime, pllinkkey, plcurupd)
                           VALUES ('#{company_num}', '#{parent_order_num}',
                              '#{order_num}', '#{order_gen_num}', '#{cust_num}',
                              '#{cust_name}', '#{po_num}', 'AP', 'WEB',
                              '#{date}', '#{time}', '#{promo_key}', 'Y')"

    as400_83m.run(sql_insert_approval)
    
    as400_83m.commit
    as400_83m.disconnect
  end

  def change_promo
    company_num = params[:company_num]
    parent_order_num = params[:parent_order_num]
    order_num = params[:order_num]
    order_gen_num = params[:order_gen_num]
    cust_num = params[:cust_num]
    cust_name = params[:cust_name]
    po_num = params[:po_num]
    @revisions = params[:revisions].strip
    revisions = escape_apostrophes(@revisions)
    promo_key = params[:promokey]
    now = Time.now
    date = now.strftime("%Y%m%d")
    time = now.strftime("%H%M%S")

    as400_83m = ODBC.connect('approvals_m')

    sql_insert_revision = "INSERT INTO promo_log (
                              plcono, plpror, plorno, plorgn, plcsno,
                              plcsnm, plcspo, plstatus, plrevision,
                              pluser, pldate, pltime, pllinkkey, plcurupd)
                           VALUES ('#{company_num}', '#{parent_order_num}',
                              '#{order_num}', '#{order_gen_num}', '#{cust_num}',
                              '#{cust_name}', '#{po_num}', 'CH', '#{revisions}',
                              'WEB', '#{date}', '#{time}', '#{promo_key}', 'Y')"

    as400_83m.run(sql_insert_revision)
    
    as400_83m.commit
    as400_83m.disconnect
  end

  private

  def display_repair_approval
    repair_key = params[:repairkey].strip
    as400_83m = ODBC.connect('approvals_m')

    sql_find_order = "SELECT a.tlpror, a.tlorno, a.tlstatus03, a.tlstatus04,
                             a.tlticket, c.cmcsno, c.cmcsnm, b.trmodel,
                             b.trserial, d.tt$tot, e.ohcspo
                      FROM toolr_log AS a
                      JOIN toolrpctl AS b ON b.trticket = a.tlticket
                      JOIN aplus83fds.cusms AS c ON c.cmcsno = b.trcsno
                      JOIN tooltot AS d ON d.ttticket = a.tlticket
                      JOIN aplus83fds.orhed AS e ON e.ohorno = a.tlorno
                      WHERE tllinkkey = '#{repair_key}'"

    stmt_find_order = as400_83m.run(sql_find_order)
    order = stmt_find_order.fetch_all

    as400_83m.commit
    as400_83m.disconnect

    if order.nil?
      flash.now.alert = "Repair ticket does not exist."
    else
      order = order.first.map(&:strip)
      parent_order_num = order[0]
      order_num = order[1]
      @declined = order[2] == '3'
      @accepted = order[3] == '4'
      @ticket_num = order[4]
      @cust_num = order[5]
      @cust_name = order[6]
      @model_num = order[7]
      @serial_num = order[8]
      @order_total = order[9]
      @image_path = "no_image.png"
      @image_alt = "No image for Ticket #{@ticket_num}"

      unless order[10].blank? || order[10].upcase == "PENDING"
        @ponum = order[10].upcase
      end

      uri = URI.parse("https://repair-images.divalsafety.com/toolrep/" + @ticket_num + "-B.jpg")
      response_code = Net::HTTP.get_response(uri).code
      if response_code == "200"
        @image_path = "https://repair-images.divalsafety.com/toolrep/" + @ticket_num + "-B.jpg"
        @image_alt = "Image for Ticket #{@ticket_num}"
      end

      if @accepted
        flash.now.notice = "Ticket #{@ticket_num} has already been approved"
      elsif @declined
        flash.now.alert = "Ticket #{@ticket_num} has already been declined"
      end
    end

    render 'repair_approval'
  end

  def display_promo_approval
    promo_key = params[:promokey].strip
    as400_83m = ODBC.connect('approvals_m')

    sql_parent_order_num = "SELECT plpror FROM promo_log
                            WHERE pllinkkey = '#{promo_key}'"
        
    stmt_find_parent_order_num = as400_83m.run(sql_parent_order_num)
    order = stmt_find_parent_order_num.fetch_all

    unless order.nil?
      parent_order_num = order.first[0].strip
      sql_status_rows = "SELECT plcono, plpror, plorno, plorgn, plcsno,
                                plcsnm, plcspo, plstatus, pldate 
                         FROM promo_log
                         WHERE plpror = '#{parent_order_num}'
                           AND plstatus IN ('AK','CH','AP')
                         ORDER BY pldate DESC, pltime DESC"

      stmt_status_rows = as400_83m.run(sql_status_rows)
      order = stmt_status_rows.fetch_all
    end
    
    as400_83m.commit
    as400_83m.disconnect

    if order.nil?
      flash.now.alert = "Approval does not exist."
    else
      @revision_num = order.select { |row| row[7].strip == "CH" }.count

      order = order.first.map(&:strip)
      @company_num = order[0]
      @parent_order_num = order[1]
      @order_num = order[2]
      @order_gen_num = order[3]
      @cust_num = order[4]
      @cust_name = order[5]
      @po_num = order[6]
      status = order[7]
      date = order[8]

      if status == "AP"
        flash.now.notice = "Order number #{@order_num} has already been approved."
      elsif status == "CH"
        date = DateTime.parse("#{date}").strftime("%A, %b %d, %Y")

        flash.now.alert = "Revision was submitted for order number #{@order_num} "\
                          "on #{date}. We'll send a new approval email once your changes are updated!"
      else
        @action_required = true
      end
    end

    render 'promo_approval'
  end
end