USE [impresario]
GO
/****** Object:  StoredProcedure [dbo].[LP_TICKET_ELEMENTS]    Script Date: 3/17/2023 12:30:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER Procedure [dbo].[LP_TICKET_ELEMENTS](
	@ude_no			int 	= null,  		-- 1-6
	@li_seq_no 		int	= null,
	@cur_sli_no		int 	= null,
	@payment_no		int	= null,
	@print_unprinted 	char(1) = null,
	@reprint_printed 	char(1) = null,
	@sli_req_no		int	= null,		
	@au_set_no		int 	= null,
	@order_no  		int	= null,
	@customer_no		int 	= null,
	@design_no		int 	= null,
	@ticket_no	int = null,
	@composite_ticket_no	int = null,
	@design_type		char(1),			-- (T)icket, (H)eader, (R)eceipt, (F)orm
	@ude_value		varchar(500) = '' output		-- user defined element value
	)

AS

Set NoCount On

/********************************************************************************************************************************************
New Localized Procedure CWR 12/6/2004, designed to be called from ticket formatting procedures.  Allows the use of customized ticket
formatting elements.  All values must be returned as strings, formatted the way you want them to appear on the ticket

Modified CWR 4/18/2014 #8321.  Added additional parameters @ticket_no and @composite_ticket_no
Modified CWR 6/30/2014 #8730.  Expanded output parameter to 200 characters
Modified RWC 12/11/2017 #9869.  Removed obsolete samples, using standard ticket history

********************************************************************************************************************************************/

-- uncomment this if you want the procedure to actually do something
--Return



-- set up some variables

-- TrueType fonts must be added to the printer using Boca's configuration software (https://tls-bocasystems.com/en/53/test-program-firmware/)
-- the number in TTF# below must match the ID provided (or generated) when the .ttf file is added via Boca's app
DECLARE @font1 varchar(10) = '<TTF17,15>'; 			--  Source Sans regular, 15pt
DECLARE @font2 varchar(10) = '<TTF17,18>'; 			--  Source Sans regular, 18pt
DECLARE @font3 varchar(10) = '<TTF18,15>'; 			--  Source Sans bold, 15pt
DECLARE @font4 varchar(10) = '<TTF18,18>'; 			--  Source Sans bold, 18pt
DECLARE @element_reset varchar(10) = '<F3><t><n>'; 	--  reset font and start over
DECLARE @line_break varchar(8) = 'CHAR(10)'; 		-- add a line-break to the output

If @ude_no = 1
	GOTO Ude1 -- date/time - 2 fields
If @ude_no = 2
	GOTO Ude2 -- artistic discipline & performance title - 4 fields
If @ude_no = 3
	GOTO Ude3 -- performance-specific extra text (e.g. Student matinee) - 1 field
If @ude_no = 4
	GOTO Ude4 -- venue - 1 field
If @ude_no = 5
	GOTO Ude5 -- section, row & seat -  you guessed it, 3 fields

/**************************************************************************************/
Ude1:
If @ude_no = 1 and @customer_no > 0
	BEGIN
		-- prepend the TrueType font command before the value to be output
		-- example: "Mon lundi April 3 avril 2023 20:00"

		SELECT @ude_value = 
			@font3 + FORMAT(tp.perf_dt, 'ddd ')
		FROM t_sub_lineitem
			LEFT OUTER JOIN t_perf as tp ON tp.perf_no = t_sub_lineitem.perf_no
		WHERE t_sub_lineitem.order_no = @order_no;

		SET LANGUAGE French;

		SELECT @ude_value += FORMAT(tp.perf_dt, 'dddd ')
		FROM t_sub_lineitem
			LEFT OUTER JOIN t_perf as tp ON tp.perf_no = t_sub_lineitem.perf_no
		WHERE t_sub_lineitem.order_no = @order_no;

		SET LANGUAGE us_english;

		SELECT @ude_value += FORMAT(tp.perf_dt, 'MMMM %d ')
		FROM t_sub_lineitem
			LEFT OUTER JOIN t_perf as tp ON tp.perf_no = t_sub_lineitem.perf_no
		WHERE t_sub_lineitem.order_no = @order_no;

		SET LANGUAGE French;

		SELECT @ude_value += FORMAT(tp.perf_dt, 'MMMM yyyy')
		FROM t_sub_lineitem
			LEFT OUTER JOIN t_perf as tp ON tp.perf_no = t_sub_lineitem.perf_no
		WHERE t_sub_lineitem.order_no = @order_no;
		
		SET LANGUAGE us_english;

		SELECT @ude_value += @element_reset + '<NR><RC37,658>' + @font3 + FORMAT(tp.perf_dt, '%H:mm')
		FROM t_sub_lineitem
			LEFT OUTER JOIN t_perf as tp ON tp.perf_no = t_sub_lineitem.perf_no
		WHERE t_sub_lineitem.order_no = @order_no;

		Return
	END

/**************************************************************************************/
Ude2:
If @ude_no = 2 and @customer_no > 0
	BEGIN
		-- prepend the TrueType font command before the value to be output
		-- e.g value: "NAC Orchestra, Schumann's concerto, title in french, 4th line title if necessary"
		-- horizontal elements are prepended with the following, for e.g.: <NR><RC121,36><F13><HW1,1>
		-- followed by what @ude_value is set below
		SELECT @ude_value = 
			@font1 + ti.text1 + @element_reset +  
			'<NR><RC204,37>' + @font2 + ti.text2 + @element_reset + 
			'<NR><RC251,37>' + @font2 + ti.text3 + @element_reset + 
			'<NR><RC298,34>' + @font2 + ti.text4
		FROM t_sub_lineitem
			LEFT OUTER JOIN t_perf as tp ON tp.perf_no = t_sub_lineitem.perf_no
			LEFT OUTER JOIN t_prod_season as tps ON tps.prod_season_no = tp.prod_season_no
			LEFT OUTER JOIN t_inventory as ti ON ti.inv_no = tp.prod_season_no
		WHERE t_sub_lineitem.order_no = @order_no;

		Return
	END

/**************************************************************************************/
Ude3:
If @ude_no = 3 and @customer_no > 0
	BEGIN
		-- prepend the TrueType font command before the value to be output
		-- e.g value: "Student Matinee" - nb this is pulled from the perf, NOT the prod
		SELECT @ude_value = @font3 + ti.text2
		FROM t_sub_lineitem
			LEFT OUTER JOIN t_perf as tp ON tp.perf_no = t_sub_lineitem.perf_no
			LEFT OUTER JOIN t_inventory as ti ON ti.inv_no = tp.perf_no
		WHERE t_sub_lineitem.order_no = @order_no;

		Return
	END

/**************************************************************************************/
Ude4:
If @ude_no = 4 and @customer_no > 0
	BEGIN
		-- prepend the TrueType font command before the value to be output
		-- e.g value: "Salle Southam Hall"
		SELECT @ude_value = @font3 + f.description
		FROM t_sub_lineitem
			LEFT OUTER JOIN t_perf as tp ON tp.perf_no = t_sub_lineitem.perf_no
			LEFT OUTER JOIN t_facility as f ON f.facil_no = tp.facility_no
		WHERE t_sub_lineitem.order_no = @order_no;

		Return
	END

/**************************************************************************************/
Ude5:
If @ude_no = 5 and @customer_no > 0
	BEGIN
		-- prepend the TrueType font command before the value to be output
		-- e.g value: "LOGERD VV 13"
		SELECT @ude_value = 
			@font4 + s.short_desc +
			'<NR><RC578,276>' + @font4 + t_seat.seat_row +
			'<NR><RC578,418>' + @font4 + t_seat.seat_num
		FROM t_seat
			LEFT OUTER JOIN t_sub_lineitem as ts ON t_seat.seat_no = ts.seat_no
			LEFT OUTER JOIN tr_section as s ON t_seat.section = s.id
		WHERE ts.order_no = @order_no;

		Return
	END

