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




/*
	LP_TICKET_ELEMENTS for NAC-CNA printed and PAH tickets
	Author: Dan Copeland <dan.copeland@nac-cna.ca>
	Repo: https://github.com/nac-cna/tessitura-tickets
*/

-- horizontal elements in Tessitura's exported FGL are prepended with the following, for e.g.: <NR><RC121,36><F13><HW1,1>
-- we follow that up with @font#, which prepends the TrueType font command before the value

/* Caveats
	- TrueType fonts must be added to the printer using Boca's configuration software (https://tls-bocasystems.com/en/53/test-program-firmware/)
	- the number in TTF# below must match the ID provided (or generated) when the .ttf file is added via Boca's app
	- for plain text elements in your ticket design, simply prepend the text with <TTF#,#> to achieve the same font override e.g. "<TTF17,12>Section"
	- UD elements have a hard limit of 200 characters, so choose wisely: group equal-length fields to stay under-budget
*/

-- first we set up some variables
DECLARE @font1 varchar(10) = '<TTF17,14>'; 							--  Source Sans regular, 14pt
DECLARE @font2 varchar(10) = '<TTF17,17>'; 							--  Source Sans regular, 17pt
DECLARE @font3 varchar(10) = '<TTF17,18>'; 							--  Source Sans regular, 18pt (unused)
DECLARE @font4 varchar(10) = '<TTF18,15>'; 							--  Source Sans bold, 15pt
DECLARE @font5 varchar(10) = '<TTF18,18>'; 							--  Source Sans bold, 18pt (unused)
DECLARE @element_reset varchar(10) = '<F3><t>'; 					--  reset font and start over
DECLARE @line_break varchar(16) = CHAR(13) + CHAR(10) + '<n>'; 		-- add a line-break to the output

-- then route to different queries for each User-defined element
If @ude_no = 1
	GOTO Ude1
	-- date/time - 2 fields (used for thermal printed ticket only)
	-- Ticket design fields: Performance.Perf.Info-1_1, Performance.Perf.Begin Time
If @ude_no = 2
	GOTO Ude2
	-- artistic discipline
	-- Ticket design fields: Performance.Prod.Season.Info-1_1
If @ude_no = 3
	GOTO Ude3
	-- performance title - 3 fields
	-- Ticket design fields: Performance.Prod.Season.Info-1_2, Performance.Prod.Season.Info-1_3, Performance.Prod.Season.Info-1_4
If @ude_no = 4
	GOTO Ude4
	-- performance-specific extra text and venue
	-- Ticket design fields: (e.g. Student matinee, Salle Southam Hall) - 2 field (Performance.Perf.Info-2_1, Seat.Theatre_1
If @ude_no = 5
	GOTO Ude5
	-- section, row & seat -  you guessed it, 3 fields
	-- Ticket design fields: Seat.Section Short_Desc_1, Seat.Seat Row_1, Seat.Seat Number_1
If @ude_no = 6
	GOTO Ude6
	-- date 1 field (used for PAH ticket only)
	-- Ticket design fields: Performance.Perf.Info-1_1

/**************************************************************************************/
Ude1:
If @ude_no = 1 and @customer_no > 0
	BEGIN
		-- example: "Mon lundi April 3 avril 2023 20:00"

		SELECT @ude_value = 
			@font4 + FORMAT(tp.perf_dt, 'ddd ')
		FROM t_sub_lineitem
			LEFT OUTER JOIN t_perf as tp ON tp.perf_no = t_sub_lineitem.perf_no
		WHERE t_sub_lineitem.sli_no = @cur_sli_no;

		SET LANGUAGE French;

		SELECT @ude_value += REPLACE(FORMAT(tp.perf_dt, 'ddd '),'.','')
		FROM t_sub_lineitem
			LEFT OUTER JOIN t_perf as tp ON tp.perf_no = t_sub_lineitem.perf_no
		WHERE t_sub_lineitem.sli_no = @cur_sli_no;

		SET LANGUAGE us_english;

		SELECT @ude_value += REPLACE(FORMAT(tp.perf_dt, 'MMM %d '),'.','')
		FROM t_sub_lineitem
			LEFT OUTER JOIN t_perf as tp ON tp.perf_no = t_sub_lineitem.perf_no
		WHERE t_sub_lineitem.sli_no = @cur_sli_no;

		SET LANGUAGE French;

		SELECT @ude_value += REPLACE(FORMAT(tp.perf_dt, 'MMM yyyy'),'.','')
		FROM t_sub_lineitem
			LEFT OUTER JOIN t_perf as tp ON tp.perf_no = t_sub_lineitem.perf_no
		WHERE t_sub_lineitem.sli_no = @cur_sli_no;
		
		SET LANGUAGE us_english;

		SELECT @ude_value += @element_reset + @line_break + '<NR><RC20,678>' + @font4 + FORMAT(tp.perf_dt, '%H:mm')
		FROM t_sub_lineitem
			LEFT OUTER JOIN t_perf as tp ON tp.perf_no = t_sub_lineitem.perf_no
		WHERE t_sub_lineitem.sli_no = @cur_sli_no;

		Return
	END

/**************************************************************************************/
Ude2:
If @ude_no = 2 and @customer_no > 0
	BEGIN
		-- e.g value: "NAC Orchestra"
		SELECT @ude_value = 
			@font1 + ISNULL(ti.text1,'')
		FROM t_sub_lineitem
			LEFT OUTER JOIN t_perf as tp ON tp.perf_no = t_sub_lineitem.perf_no
			LEFT OUTER JOIN t_prod_season as tps ON tps.prod_season_no = tp.prod_season_no
			LEFT OUTER JOIN t_inventory as ti ON ti.inv_no = tp.prod_season_no
		WHERE t_sub_lineitem.sli_no = @cur_sli_no;

		Return
	END

/**************************************************************************************/
Ude3:
If @ude_no = 3 and @customer_no > 0
	BEGIN
		-- e.g value: "Schumann's concerto, title in french, 4th line title if necessary"
		SELECT @ude_value = @font2 + ISNULL(ti.text2,'') + @element_reset + @line_break + 
			'<NR><RC235,56>' + @font2 + ISNULL(ti.text3,'') + @element_reset + @line_break + 
			'<NR><RC290,56>' + @font2 + ISNULL(ti.text4,'')
		FROM t_sub_lineitem
			LEFT OUTER JOIN t_perf as tp ON tp.perf_no = t_sub_lineitem.perf_no
			LEFT OUTER JOIN t_prod_season as tps ON tps.prod_season_no = tp.prod_season_no
			LEFT OUTER JOIN t_inventory as ti ON ti.inv_no = tp.prod_season_no
		WHERE t_sub_lineitem.sli_no = @cur_sli_no;

		Return
	END

/**************************************************************************************/
Ude4:
If @ude_no = 4 and @customer_no > 0
	BEGIN
		-- e.g value: "Student Matinee, Salle Southam Hall" - nb this is pulled from the perf, NOT the prod
		SELECT @ude_value = @font1 + ISNULL(ti.text2,'') + @element_reset + @line_break +
			'<NR><RC455,56>' + @font4 + ISNULL(f.description,'')
		FROM t_sub_lineitem
			LEFT OUTER JOIN t_perf as tp ON tp.perf_no = t_sub_lineitem.perf_no
			LEFT OUTER JOIN t_inventory as ti ON ti.inv_no = tp.perf_no
			LEFT OUTER JOIN t_facility as f ON f.facil_no = tp.facility_no
		WHERE t_sub_lineitem.sli_no = @cur_sli_no;
		
		Return
	END

/**************************************************************************************/
Ude5:
If @ude_no = 5 and @customer_no > 0
	BEGIN
		-- e.g value: "LOGERD VV 13"
		SELECT @ude_value = 
			@font4 + ISNULL(s.short_desc,'') + @element_reset + @line_break +
			'<NR><RC573,288>' + @font4 + ISNULL(t_seat.seat_row,'') + @element_reset + @line_break +
			'<NR><RC573,438>' + @font4 + ISNULL(t_seat.seat_num,'')
		FROM t_seat
			LEFT OUTER JOIN t_sub_lineitem as sli ON t_seat.seat_no = sli.seat_no
			LEFT OUTER JOIN tr_section as s ON t_seat.section = s.id
		WHERE sli.sli_no = @cur_sli_no;
	
		Return
	END
/**************************************************************************************/
Ude6:
If @ude_no = 6 and @customer_no > 0
	BEGIN
		-- e.g value: "Mon lundi April 3 avril 2023"

		SELECT @ude_value = FORMAT(tp.perf_dt, 'ddd ')
		FROM t_sub_lineitem
			LEFT OUTER JOIN t_perf as tp ON tp.perf_no = t_sub_lineitem.perf_no
		WHERE t_sub_lineitem.sli_no = @cur_sli_no;
		
		SET LANGUAGE French;
		
		SELECT @ude_value += REPLACE(FORMAT(tp.perf_dt, 'ddd '),'.','')
		FROM t_sub_lineitem
			LEFT OUTER JOIN t_perf as tp ON tp.perf_no = t_sub_lineitem.perf_no
		WHERE t_sub_lineitem.sli_no = @cur_sli_no;
		
		SET LANGUAGE us_english;
		
		SELECT @ude_value += REPLACE(FORMAT(tp.perf_dt, 'MMM %d '),'.','')
		FROM t_sub_lineitem
			LEFT OUTER JOIN t_perf as tp ON tp.perf_no = t_sub_lineitem.perf_no
		WHERE t_sub_lineitem.sli_no = @cur_sli_no;
		
		SET LANGUAGE French;
		
		SELECT @ude_value += REPLACE(FORMAT(tp.perf_dt, 'MMM yyyy'),'.','')
		FROM t_sub_lineitem
			LEFT OUTER JOIN t_perf as tp ON tp.perf_no = t_sub_lineitem.perf_no
		WHERE t_sub_lineitem.sli_no = @cur_sli_no;
		
		SET LANGUAGE us_english;

		Return
	END


