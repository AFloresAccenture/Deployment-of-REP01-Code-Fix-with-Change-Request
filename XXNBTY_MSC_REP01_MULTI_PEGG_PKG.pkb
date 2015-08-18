create or replace PACKAGE BODY       XXNBTY_MSCREP01_MULTI_PEGG_PKG
/*
Package Name	: XXNBTY_MULTI_PEGGING_REP_PKG
Author's name	: Mark Anthony Geamoga
Date written	: 12-FEB-2015
RICEFW Object id: 
Description		: Package that will generate multi-pegging report details.
Program Style	:  

Maintenance History:
Date 		   Issue# 			    Name 				                  Remarks
-----------   -------- 				---- 				            ------------------------------------------
12-FEB-2015 		  	        Mark Anthony Geamoga  				Initial development.
25-FEB-2015            	    	Mark Anthony Geamoga				Finished development except for BLEND.
03-MAR-2015 			        Albert John Flores					Added the conversion of date for the concurrent program
03-MAR-2015            	    	Mark Anthony Geamoga				Added BLEND ICC and consolidated with Albert's modification.
04-MAR-2015            	    	Mark Anthony Geamoga				Added Validations in the root selection 
05-MAR-2015				        Albert John Flores					Added the procedure for the request id identifier
13-MAR-2015						Albert John Flores					Finalized the Package with the parameters passed to be used by the XML Publisher
20-MAR-2015						Albert John Flores					Added Review points due to performance Issues
25-MAR-2015						Albert John Flores					Added procedure get_catalog_pr for items in vcp to staging table
26-MAR-2015						Albert John Flores					Added Function for the planned order demand query
30-MAR-2015						Albert John Flores					Modified For the incorrect details
24-APR-2015						Albert John Flores					Added Phase II
11-JUL-2015						Albert John Flores					Used xxnbty_dem_peg_id_tbl for the pegging ids
14-JUL-2015						Albert John Flores					Added who columns for xxnbty_dem_peg_id_tbl
15-JUL-2015						Albert John Flores					Added procedures due to OPP issues(REPORT AS CSV)
16-JUL-2015						Albert John Flores					Additional Changes for the CSV work around due to OPP Issue
17-JUL-2015						Daniel Rodil                        added function to get the email address of the user
21-JUL-2015	  Change Request    Albert John Flores					Added the additional columns and printing functions for the change request
29-JUL-2015						Albert John Flores					Fixed the error handling for mandatory columns
13-AUG-2015						Albert John Flores					Fix for the issues encountered in prod
*/
----------------------------------------------------------------------
IS
	--Function xxnbty_get_catalog_fn --Added 26/03/2015 Albert Flores
	FUNCTION xxnbty_get_catalog_fn( p_segment1 IN VARCHAR2 , p_org IN NUMBER)  RETURN VARCHAR2 IS  
	l_attribute1 	VARCHAR2(1000);
	BEGIN 

	  SELECT  icc 
	  INTO l_attribute1
	  FROM xxnbty_catalog_staging_tbl  
	  WHERE 	item_name  		= p_segment1
	  AND 		organization_id = p_org;

	  RETURN l_attribute1;
    
      EXCEPTION
      WHEN OTHERS THEN
      RETURN NULL;

    END;

	FUNCTION xxnbty_get_email RETURN VARCHAR2
	IS
		CURSOR c_db_link
		IS
		SELECT mai.m2a_dblink
		  FROM msc_apps_instances mai
		 WHERE mai.instance_code = 'EBS';	

		CURSOR c_get_user_name (p_user_id number)
		IS
		SELECT user_name
		  FROM fnd_user
		 WHERE user_id = p_user_id;	
		 
		v_db_link msc_apps_instances.m2a_dblink%type;
		v_email_add varchar2(100) := null;
		
		c_cursor 		  SYS_REFCURSOR;
		v_query VARCHAR2(4000);
		v_user_name  fnd_user.user_name%type;
		
	BEGIN 

	  -- Get DB Link from VCP to EBS
	  OPEN c_db_link;
	  FETCH c_db_link INTO v_db_link;
	  CLOSE c_db_link;
	  
	  g_created_by  := fnd_global.user_id;	
	  
	  OPEN c_get_user_name (g_created_by);
	  FETCH c_get_user_name INTO v_user_name;
	  CLOSE c_get_user_name;

	  v_query := 'SELECT email_address '
	            ||'FROM fnd_user@'|| v_db_link 
				||' WHERE email_address IS NOT NULL AND user_name = '''|| v_user_name ||'''';

	  OPEN c_cursor FOR v_query;
	  FETCH c_cursor into v_email_add;
	  CLOSE c_cursor;
				
	  RETURN v_email_add;
    
     EXCEPTION
      WHEN OTHERS THEN
		RETURN NULL;
    END;	
	
	--procedure that will fetch records from ebs to vcp for catalog groups staging table xxnbty_catalog_staging_tbl
	PROCEDURE get_catalog_pr( errbuf	OUT VARCHAR2
							 ,retcode	OUT NUMBER) --3/25/2015 Albert Flores
	IS

	  TYPE get_icc_temp_tab   IS TABLE OF xxnbty_catalog_staging_tbl%ROWTYPE;

		
	  g_icc_rec			  get_icc_temp_tab := get_icc_temp_tab();   
	  c_get_icc 		  SYS_REFCURSOR;  	
	  l_get_icc_query     VARCHAR2(4000);
    
    v_step          number;
    v_mess          varchar2(500);
	-- Get DB Link from VCP to EBS
  
	  CURSOR icc_dbLink
	  IS
	  SELECT mai.M2A_DBLINK
			,mai.instance_id -- 3/25/2015 A Flores   
		FROM msc_apps_instances mai
	   WHERE mai.instance_code = 'EBS';
	 

	BEGIN
    v_step := 1;
    DELETE FROM xxnbty_catalog_staging_tbl;
    COMMIT;
    
	  v_step := 2;
    -- Get DB Link from VCP to EBS
	  OPEN icc_dbLink;
	  FETCH icc_dbLink INTO g_icc_db_link , g_instance_id;
	  CLOSE icc_dbLink;

    v_step := 3;
	l_get_icc_query := 'SELECT   msi_ebs.inventory_item_id inventory_item_id '
							||' ,msi_ebs.segment1 item_name '
							||' ,msi_ebs.organization_id organization_id '
							||' ,DECODE(NVL(emsieb.c_ext_attr2, ecg.catalog_group) '
								||' , '''|| icc_rm_constant ||''', NVL(emsieb.c_ext_attr2, ecg.catalog_group) '
								||' , '''|| icc_bl_constant ||''', NVL(emsieb.c_ext_attr2, ecg.catalog_group) '
								||' , '''|| icc_fg_constant ||''', NVL(emsieb.c_ext_attr2, ecg.catalog_group) '
								||' , ''FP Retail-Direct Consumer'', '''|| icc_fg_constant ||''' '
								||' , ''SFG - Consumer Direct'', '''|| icc_fg_constant ||''' '
								||' ,'''|| icc_dd_constant ||''', NVL(emsieb.c_ext_attr2, ecg.catalog_group),'''|| icc_bc_constant ||''') icc '
							||' ,emsieb.c_ext_attr2 blend '	
							||' ,ecg.catalog_group catalog_group '								
					 ||' FROM mtl_system_items@'|| g_icc_db_link ||' msi_ebs '
								||' ,ego_catalog_groups_v@'|| g_icc_db_link ||' ecg '
								||' ,ego_mtl_sy_items_ext_b@'|| g_icc_db_link ||' emsieb '
								||' ,msc_system_items msi_ascp '
					 ||' WHERE ecg.catalog_group_id 	  = msi_ebs.item_catalog_group_id '
					 ||' AND   msi_ebs.organization_id    = emsieb.organization_id (+) '
					 ||' AND   msi_ebs.inventory_item_id  = emsieb.inventory_item_id (+) '
					 ||' AND   emsieb.c_ext_attr2(+)   	  = '''|| icc_bl_constant ||''' '
					 ||' AND   msi_ebs.segment1        	  = msi_ascp.item_name '
					 ||' AND   msi_ebs.organization_id 	  = msi_ascp.organization_id '
					 ||' AND   msi_ascp.plan_id    	   	  = '''|| plan_id_constant ||''' '
					 ||' AND   msi_ascp.sr_instance_id 	  = '''|| g_instance_id ||''' ' ;
					 
    v_step := 4;
		OPEN c_get_icc FOR l_get_icc_query;
		LOOP
		 FETCH c_get_icc BULK COLLECT INTO g_icc_rec LIMIT c_limit;
			v_step := 5;
        FORALL i IN 1..g_icc_rec.COUNT	  
        INSERT /*+APPEND*/ INTO xxnbty_catalog_staging_tbl VALUES g_icc_rec(i);      
        COMMIT;        
    EXIT WHEN c_get_icc%NOTFOUND;        
		END LOOP;
    v_step := 6;
    --FND_FILE.PUT_LINE(FND_FILE.LOG, 'Successfully inserted' || g_icc_rec.COUNT|| ' records');
		CLOSE c_get_icc;

		EXCEPTION
			WHEN OTHERS THEN
			  v_mess := 'At step ['||v_step||'] for procedure get_catalog_pr(SUPPLY) - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
			  errbuf  := v_mess;
			  retcode := 2; 	
			  FND_FILE.PUT_LINE(FND_FILE.LOG,'Error message : ' || v_mess);	
		
	END get_catalog_pr;	


	--main procedure
	PROCEDURE main_pr( errbuf        	 OUT VARCHAR2
                     ,retcode       	 OUT NUMBER
                     ,p_plan_name        msc_orders_v.compile_designator%TYPE
                     ,p_org_code         msc_orders_v.organization_code%TYPE
                     ,p_catalog_group	 VARCHAR2
                     ,p_planner_code	 msc_orders_v.planner_code%TYPE
                     ,p_purchased_flag   msc_orders_v.purchasing_enabled_flag%TYPE
                     ,p_item_name		 msc_orders_v.item_segments%TYPE
                     ,p_main_from_date	 VARCHAR2
                     ,p_main_to_date	 VARCHAR2
					 ,p_pegging_type	 VARCHAR2
					 ,p_email_ad		 VARCHAR2) --Added 24/04/2015 Albert Flores
	IS
	  l_err_msg		    VARCHAR(100);
      l_from_date 		DATE := TO_DATE (p_main_from_date, 'YYYY/MM/DD HH24:MI:SS');
      l_to_date   		DATE := TO_DATE (p_main_to_date, 'YYYY/MM/DD HH24:MI:SS');
	--  l_request_id    NUMBER := fnd_global.conc_request_id;
	  v_request_id		NUMBER;
	  v_step          	NUMBER;
	  v_mess          	VARCHAR2(500);
	  e_error           EXCEPTION;
	
	BEGIN
	--FND_FILE.PUT_LINE(FND_FILE.LOG, 'Start of  main_pr. Start time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');
	--define last updated by and created by
    g_last_updated_by := fnd_global.user_id;
    g_created_by      := fnd_global.user_id;	 
    g_request_id	  := fnd_global.conc_request_id; --Applied for review points 3/20/2015 Albert Flores
	
	v_step := 1;
	--validate input parameters
	IF p_plan_name IS NULL THEN
		l_err_msg := 'Please enter Plan Name.';
	ELSIF p_org_code IS NULL THEN
		l_err_msg := 'Please enter Organization Code.';
	ELSIF p_main_from_date IS NULL THEN
		l_err_msg := 'Please enter From Date.';  
	ELSIF p_catalog_group IS NULL
	   AND p_planner_code IS NULL
	   AND p_item_name IS NULL THEN
		l_err_msg := 'Either ICC or Planner Code or Item is required to generate pegging report.';  
	ELSIF l_to_date < l_from_date THEN
		l_err_msg := 'To Date must be later than From Date.';
	END IF;   
	v_step := 2;
	--7/16/2015 Additional Changes for CSV
    IF l_err_msg IS NULL AND p_pegging_type = 'SUPPLY' --Added 24/04/2015 Albert Flores
	THEN --proceed if all parameters are valid     
	
		--delete old records from the temporary tables
		DELETE FROM xxnbty_pegging_temp_tbl
		WHERE (TRUNC(SYSDATE) - TO_DATE(creation_date)) > 5;
		COMMIT; 
		--added who columns for xxnbty_dem_peg_id_tbl 7/14/2015 AFLORES
		DELETE FROM xxnbty_dem_peg_id_tbl
		WHERE (TRUNC(SYSDATE) - TO_DATE(creation_date)) > 5;
		COMMIT; 
	
		--get root report
		get_root_rep( errbuf 
                   ,retcode
                   ,p_plan_name
                   ,p_org_code
                   ,p_catalog_group
                   ,p_planner_code
                   ,p_purchased_flag
                   ,p_item_name
                   ,l_from_date
                   ,l_to_date);
				   
		IF retcode != 0 THEN
		RAISE e_error;
		END IF;
	v_step := 3;	
	--Defect FIX 7/29/2015	AFlores	
	ELSIF l_err_msg IS NULL AND p_pegging_type = 'DEMAND' THEN
	XXNBTY_MSCREP01_PEGG_DEM_PKG.main_pr(errbuf        	
											  ,retcode       	 
											  ,p_plan_name        
											  ,p_org_code         
											  ,p_catalog_group	 
											  ,p_planner_code	 
											  ,p_purchased_flag   
											  ,p_item_name		 
											  ,p_main_from_date	 
											  ,p_main_to_date); 	
	--Defect FIX 7/29/2015	AFlores									  
	ELSIF l_err_msg IS NULL AND p_pegging_type = 'BOTH' THEN
	v_step := 4;
		--delete old records from the temporary tables
		DELETE FROM xxnbty_pegging_temp_tbl
		WHERE (TRUNC(SYSDATE) - TO_DATE(creation_date)) > 5;
		COMMIT; 
		--added who columns for xxnbty_dem_peg_id_tbl 7/14/2015 AFLORES
		DELETE FROM xxnbty_dem_peg_id_tbl
		WHERE (TRUNC(SYSDATE) - TO_DATE(creation_date)) > 5;
		COMMIT; 
	v_step := 5;
		--get root report
		get_root_rep( errbuf 
                   ,retcode
                   ,p_plan_name
                   ,p_org_code
                   ,p_catalog_group
                   ,p_planner_code
                   ,p_purchased_flag
                   ,p_item_name
                   ,l_from_date
                   ,l_to_date);
	v_step := 6;			   
		IF retcode != 0 THEN
		RAISE e_error;
		END IF;

		XXNBTY_MSCREP01_PEGG_DEM_PKG.main_pr(errbuf        	
											,retcode       	 
											,p_plan_name        
											,p_org_code         
											,p_catalog_group	 
											,p_planner_code	 
											,p_purchased_flag   
											,p_item_name		 
											,p_main_from_date	 
											,p_main_to_date); 
	v_step := 7;
		IF retcode != 0 THEN
		RAISE e_error;
		END IF;
	ELSE --display error encountered
      FND_FILE.PUT_LINE(FND_FILE.LOG, l_err_msg);
      retcode := 2;
	  --Defect FIX 7/29/2015 AFlores
	  errbuf  := l_err_msg;
	  RAISE e_error;
	END IF;	
	
		--call concurrent program to generate the report in csv file
		generate_pegging_csv_report ( errbuf   		
									    ,retcode  
										,v_request_id
									    ,p_plan_name       
									    ,p_org_code        
									    ,p_catalog_group	
									    ,p_planner_code	
									    ,p_purchased_flag  
									    ,p_item_name		
									    ,p_main_from_date	
									    ,p_main_to_date	
									    ,p_pegging_type);	
									    
		IF retcode != 0 THEN
		RAISE e_error;
		END IF;				
    v_step := 8; 
		generate_pegging_email (errbuf  
								,retcode
								,v_request_id
								,p_pegging_type
								,p_email_ad);
					   
		IF retcode != 0 THEN		   
	    RAISE e_error;
	    END IF;				
	v_step := 9; 
	--7/16/2015 Additional Changes for CSV
	--END
	--FND_FILE.PUT_LINE(FND_FILE.LOG, 'End of  main_pr. End time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');
	EXCEPTION

		WHEN e_error THEN
		FND_FILE.PUT_LINE(FND_FILE.LOG, 'Return errbuf [' || errbuf || ']' );
		retcode := retcode;
			
			WHEN OTHERS THEN
			  v_mess := 'At step ['||v_step||'] for procedure main_pr(SUPPLY) - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
			  errbuf  := v_mess;
			  retcode := 2;
			  FND_FILE.PUT_LINE(FND_FILE.LOG,'Error message : ' || v_mess);	
	END main_pr;
	
	--procedure that will get root report
	PROCEDURE get_root_rep( errbuf        	 OUT VARCHAR2
                          ,retcode       	 OUT NUMBER
                          ,p_plan_name       msc_orders_v.compile_designator%TYPE
                          ,p_org_code        msc_orders_v.organization_code%TYPE
                          ,p_catalog_group	 VARCHAR2
                          ,p_planner_code	 msc_orders_v.planner_code%TYPE
                          ,p_purchased_flag  msc_orders_v.purchasing_enabled_flag%TYPE
                          ,p_item_name		 msc_orders_v.item_segments%TYPE
                          ,p_from_date	     msc_orders_v.new_due_date%TYPE
                          ,p_to_date		 msc_orders_v.new_due_date%TYPE)
	IS
	c_rep_root	           SYS_REFCURSOR; --3/20/2015 AFLORES
    l_rep_root     icc_tab_type;
	l_query	      VARCHAR2(4000);
	
	v_step          NUMBER;
	v_mess          VARCHAR2(500);
	e_error         EXCEPTION;	  
	BEGIN
	--FND_FILE.PUT_LINE(FND_FILE.LOG, 'Start of  get_root_rep. Start time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');
	v_step := 1;
	--get db link of EBS
	OPEN c_db_link;
	FETCH c_db_link INTO g_db_link;
	CLOSE c_db_link;
	v_step := 2;
	--dynamic query to retrieve root report
	l_query := ' SELECT   mov.item_segments item '
                       ||' ,mov.description item_description ' 
                       ||' ,mov.organization_code org_code ' 
                       ||' ,mtp.partner_name org_description '
                       ||' ,0 excess_qty '
                       ||' ,mov.order_type_text order_type ' 
                       ||' ,mov.new_due_date due_date ' 
                       ||' ,mov.order_number order_number ' 
                       ||' ,mov.quantity_rate order_quantity ' 
					   ||' ,mov.demand_priority order_priority ' 			--7/21/2015 AFlores
					   ||' ,mov.source_dmd_priority source_order_priority ' --7/21/2015 AFlores
                       ||' ,NULL pegging_order_no '
                       ||' ,mov.lot_number lot_number ' 
                       ||' ,mov.expiration_date psd_expiry_date ' 
                       ||' ,mov.source_organization_code source_org ' 
                       ||' ,xcst.icc catalog_group' --3/25/2015 Albert Flores
                       ||' ,NULL '
                       ||' ,mov.plan_id '
                       ||' ,mov.organization_id '
                       ||' ,mov.inventory_item_id '
                       ||' ,mov.sr_instance_id '
                       ||' ,mov.transaction_id '
               ||' FROM     msc_orders_v mov ' 
                       ||' ,msc_trading_partners mtp ' 
                       ||' ,msc_plans mp '
					   ||' ,xxnbty_catalog_staging_tbl xcst '
               ||' WHERE   mov.organization_code       = mtp.organization_code '
               ||' AND     mov.item_segments           = xcst.item_name ' --3/25/2015 Albert Flores
               ||' AND     xcst.organization_id        = mtp.sr_tp_id ' --3/25/2015 Albert Flores
               ||' AND     mov.plan_id                 = mp.plan_id '
               ||' AND     mov.compile_designator      = mp.compile_designator '
               ||' AND     mov.source_table            = ''MSC_SUPPLIES'' '
               ||' AND     mov.category_set_id         = :1 '
               ||' AND     mp.plan_run_date IS NOT NULL '
               ||' AND     mov.new_due_date IS NOT NULL '
               ||' AND     mov.compile_designator      = :2 '
               ||' AND     mov.organization_code       = :3 '
               ||' AND     xcst.icc			           = NVL(:4, xcst.icc) '
               ||' AND     mov.planner_code            = NVL(:5, mov.planner_code) '
               ||' AND     mov.purchasing_enabled_flag = NVL(:6, mov.purchasing_enabled_flag) '
               ||' AND     xcst.item_name               = NVL(:7, xcst.item_name) '
               ||' AND     TRUNC(mov.new_due_date)    BETWEEN TRUNC(:8) AND TRUNC(:9) '
               ||' AND     mov.order_type_text         = ''Planned order'' ';
	v_step := 3;
	OPEN c_rep_root FOR l_query USING ctgry_id_constant
                                 ,p_plan_name
                                 ,p_org_code
                                 ,p_catalog_group
                                 ,p_planner_code
                                 ,p_purchased_flag
                                 ,p_item_name
                                 ,p_from_date
                                 ,p_to_date;
	v_step := 4;							 
   LOOP --loop_c_rep_root --3/20/2015 AFLORES
      
   FETCH c_rep_root BULK COLLECT INTO l_rep_root LIMIT c_limit; --Applied for review points 3/20/2015 Albert Flores
   --CLOSE c_rep;
    v_step := 5;
      FOR i IN 1..l_rep_root.COUNT
      LOOP

		 g_rm_index_ctr   := 0;
         g_bl_index_ctr   := 0;
         g_bc_index_ctr   := 0;
         g_fg_index_ctr   := 0;
         g_dd_index_ctr   := 0;
		 
		 --03/30/2015 Albert Flores
		 collect_rep( errbuf
				 ,retcode
				 ,l_rep_root(i));
				 
		  IF retcode != 0 THEN
			RAISE e_error;
		  END IF;
	  	  
       --get pegging report of current root record
         get_pegging_details( errbuf
                             ,retcode
                             ,l_rep_root(i));
		  IF retcode != 0 THEN
			RAISE e_error;
		  END IF;					 
         
         g_rm_index   := g_temp_rec.COUNT;
         g_bl_index   := g_temp_rec.COUNT;
         g_bc_index   := g_temp_rec.COUNT;
         g_fg_index   := g_temp_rec.COUNT;
         g_dd_index   := g_temp_rec.COUNT;
		 
       --dump collected records in temp table
		populate_temp_table( errbuf
                          ,retcode
                          ,g_temp_rec);                 

		g_temp_rec.DELETE; 
		--CHANGE REQUEST 7/21/2015 Albert Flores
		g_dd_icc := NULL;
		g_fg_icc := NULL;

		  IF retcode != 0 THEN
			RAISE e_error;
		  END IF;	  
                        
      END LOOP;
	v_step := 6;  
 	  /*
      --dump collected records in temp table
      populate_temp_table( errbuf
                          ,retcode
                          ,g_temp_rec); 
     v_step := 7;                     

      g_temp_rec.DELETE;   
	  */
    EXIT WHEN c_rep_root%NOTFOUND; --3/20/2015 AFLORES
	v_step := 8;
  END LOOP; --loop_c_rep_root --3/20/2015 AFLORES
  CLOSE c_rep_root;  --3/20/2015 AFLORES  
	v_step := 9;
	--FND_FILE.PUT_LINE(FND_FILE.LOG, 'End of  get_root_rep. End time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');
	EXCEPTION
	
		WHEN e_error THEN
		FND_FILE.PUT_LINE(FND_FILE.LOG, 'Return errbuf [' || errbuf || ']' );
		retcode := retcode;
		
			WHEN OTHERS THEN
			  v_mess := 'At step ['||v_step||'] for procedure get_root_rep(SUPPLY) - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
			  errbuf  := v_mess;
			  retcode := 2; 
			  FND_FILE.PUT_LINE(FND_FILE.LOG,'Error message : ' || v_mess);	
	END get_root_rep;
   
   --procedure that will retrieve pegging report of root record
   PROCEDURE get_pegging_details( errbuf        OUT VARCHAR2
                                 ,retcode       OUT NUMBER
                                 ,p_pegging_rec icc_type)
   IS
      CURSOR c_get_pegging( p_plan_id           msc_flp_supply_demand_v3.plan_id%TYPE
                           ,p_organization_id   msc_flp_supply_demand_v3.organization_id%TYPE
                           ,p_item_id           msc_flp_supply_demand_v3.item_id%TYPE
                           ,p_sr_instance_id    msc_flp_supply_demand_v3.sr_instance_id%TYPE
                           ,p_transaction_id    msc_flp_supply_demand_v3.transaction_id%TYPE)
      IS
      SELECT pegging_id
        FROM msc_flp_supply_demand_v3
       WHERE plan_id = p_plan_id
         AND organization_id = p_organization_id
         AND item_id = p_item_id
         AND sr_instance_id = p_sr_instance_id
         AND transaction_id = p_transaction_id;
      
      --c_rep	         SYS_REFCURSOR; --3/20/2015 AFLORES
	  c_rep_root2	           SYS_REFCURSOR; --3/20/2015 AFLORES
      c_rep_order			   SYS_REFCURSOR; --3/20/2015 AFLORES
	  c_rep_demand 		   	   SYS_REFCURSOR; --3/20/2015 AFLORES
      l_pegging_rep  		   icc_tab_type;
      l_current_peg  		   icc_tab_type;
      l_orig_query	 		   VARCHAR2(32000);
      l_peg_query    		   VARCHAR2(32000);--7/11/2015 AFlores
      l_pegging_ids  		   VARCHAR2(32000);--7/11/2015 AFlores
      l_plan_id      		   NUMBER;
	  
	  v_step          NUMBER;
	  v_mess          VARCHAR2(500);
      --FIX 8/13/2015 Albert Flores
	  TYPE 	peg_tab_type 	IS TABLE OF xxnbty_dem_peg_id_tbl%ROWTYPE;
      v_tab_peg				peg_tab_type := peg_tab_type();
      ln_ctr				NUMBER := 0;
	  
   BEGIN
   --FND_FILE.PUT_LINE(FND_FILE.LOG, 'Start of get_pegging_details. Start time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');
    v_step := 1;

      l_orig_query := ' SELECT mov.item_segments item '
                             ||' ,mov.description item_description '
                             ||' ,mov.organization_code org_code '
                             ||' ,mtp.partner_name org_description '
                             ||' ,DECODE(SIGN(mfsdv.demand_id), -1, mfsdv.pegged_qty, 0)  excess_qty '
                             ||' ,mov.order_type_text order_type '
                             ||' ,mov.new_due_date due_date '
                             ||' ,mov.order_number order_number '
                             ||' ,mfsdv.pegged_qty order_quantity '
							 ||' ,mov.demand_priority order_priority ' 			--7/21/2015 AFlores
							 ||' ,mov.source_dmd_priority source_order_priority ' --7/21/2015 AFlores
                             ||' ,NULL pegging_order_no '
                             ||' ,mov.lot_number lot_number '
                             ||' ,mov.expiration_date psd_expiry_date '
                             ||' ,mov.source_organization_code source_org '
                             ||' ,xcst.icc catalog_group ' --3/25/2015 Albert Flores
                             ||' ,mfsdv.pegging_id '  
                             ||' ,mov.plan_id '
                             ||' ,mov.organization_id '
                             ||' ,mov.inventory_item_id '
                             ||' ,mov.sr_instance_id '
                             ||' ,mov.transaction_id '
                     ||' FROM     msc_orders_v mov '
                             ||' ,msc_trading_partners mtp '
                             ||' ,msc_plans mp '
							 ||' ,xxnbty_catalog_staging_tbl xcst '
                             ||' ,msc_flp_supply_demand_v3 mfsdv '
                     ||' WHERE   mov.organization_code       = mtp.organization_code '
                     ||' AND     mov.item_segments           = xcst.item_name ' --3/25/2015 Albert Flores
                     ||' AND     xcst.organization_id        = mtp.sr_tp_id ' --3/25/2015 Albert Flores
                     ||' AND     mov.plan_id                 = mp.plan_id '
                     ||' AND     mov.compile_designator      = mp.compile_designator '
                     ||' AND     mfsdv.transaction_id        = mov.transaction_id '
                     ||' AND     mfsdv.plan_id               = mov.plan_id '
                     ||' AND     mfsdv.organization_id       = mov.organization_id '
                     ||' AND     mfsdv.item_id               = mov.inventory_item_id '
                     ||' AND     mfsdv.sr_instance_id        = mov.sr_instance_id ';
      v_step := 2;
      l_peg_query := l_orig_query || ' AND mov.category_set_id   = :1 '
                                  || ' AND mov.plan_id           = :2 '
                                  || ' AND mov.organization_code = :3 '
                                  || ' AND mov.item_segments     = :4 '
                                  || ' AND mfsdv.transaction_id  = :5 ';
      v_step := 3;                           
      
      OPEN c_rep_root2 FOR l_peg_query USING ctgry_id_constant
                                     ,p_pegging_rec.plan_id
                                     ,p_pegging_rec.org_code
                                     ,p_pegging_rec.item
                                     ,p_pegging_rec.transaction_id;
	  v_step := 4;							 
	  LOOP 	--loop_c_rep_root2 --3/20/2015 AFLORES
  	  
      FETCH c_rep_root2 BULK COLLECT INTO l_pegging_rep LIMIT c_limit; --Applied for review points 3/20/2015 Albert Flores
      --CLOSE c_rep; --3/20/2015 AFLORES
      v_step := 5;
      FOR j IN 1..l_pegging_rep.COUNT
		LOOP
		  l_pegging_rep(j).pegging_order_no := p_pegging_rec.order_number;
		  v_step := 5.5;
         /*collect_rep( errbuf
                     ,retcode						--03/30/2015 Albert Flores
                     ,l_pegging_rep(j)); */
         --collect pegging ids of current level            
         l_pegging_ids := l_pegging_ids || l_pegging_rep(j).pegging_id || ',';
		 
		 --7/11/2015 Albert Flores
		 --insert to table xxnbty_dem_peg_id_tbl
	     INSERT INTO xxnbty_dem_peg_id_tbl(pegging_id, request_id, creation_date, created_by, last_update_date, last_updated_by) VALUES (l_pegging_rep(j).pegging_id, g_request_id, SYSDATE, g_created_by, SYSDATE, g_last_updated_by); --added who columns for xxnbty_dem_peg_id_tbl 7/14/2015 AFLORES
		 
		END LOOP;
	  COMMIT; --7/14/2015 Albert Flores
	  v_step := 6;		
      l_pegging_ids := RTRIM(l_pegging_ids, ',');   
	  
      l_peg_query := NULL; --clear dynamic query
      l_pegging_rep.DELETE; --clear collection
      v_step := 7;
      l_plan_id := p_pegging_rec.plan_id;
      --DBMS_OUTPUT.PUT_LINE('Order Number: ' || p_pegging_rec.order_number);   
      LOOP --loop_planned_order_demand	
		--planned order demand
		l_peg_query := ' SELECT mov.item_segments item '
                            ||'  ,mov.description item_description '
                            ||'  ,mov.organization_code org_code '
                            ||'  ,mtp.partner_name org_description '
                            ||'  ,DECODE(SIGN(mfsdv.demand_id), -1, mfsdv.pegged_qty, 0)  excess_qty '
                            ||'  ,mfsdv.origination_name order_type '
                            ||'  ,mfsdv.demand_date due_date '
                            ||'  ,mov.order_number order_number '
                            ||'  ,ABS(mfsdv.pegged_qty) order_quantity '
							||'  ,mov.demand_priority order_priority ' 			  --7/21/2015 AFlores
							||'  ,mov.source_dmd_priority source_order_priority ' --7/21/2015 AFlores
                            ||'  ,sub2.order_number pegging_order_no '
                            ||'  ,mov.lot_number lot_number '
                            ||'  ,mov.expiration_date psd_expiry_date '
                            ||'  ,mov.source_organization_code source_org '
                            --||'  ,xcst.icc catalog_group ' --3/25/2015 Albert Flores
							||'  ,XXNBTY_MSCREP01_MULTI_PEGG_PKG.xxnbty_get_catalog_fn(mov.item_segments,mtp.sr_tp_id)catalog_group ' --Added 26/03/2015 Albert Flores
                            ||'  ,mfsdv.pegging_id '
                            ||'  ,mov.plan_id '
                            ||'  ,mov.organization_id '
                            ||'  ,mov.inventory_item_id '
                            ||'  ,mov.sr_instance_id '
                            ||'  ,mfsdv.transaction_id '
                     ||' FROM     msc_orders_v mov '
                            ||'  ,msc_trading_partners mtp '
                            ||'  ,msc_plans mp '
                            ||'  ,(SELECT mfsdv2.pegging_id '
							||'			 ,mov2.order_number '
							||'		FROM msc_orders_v mov2  '
							||'			 ,msc_flp_supply_demand_v3 mfsdv2 '
							||'		WHERE mfsdv2.transaction_id = mov2.transaction_id '
							||'		AND   mfsdv2.plan_id          = mov2.plan_id '
							||'		AND   mfsdv2.organization_id  = mov2.organization_id '
							||'		AND   mfsdv2.item_id          = mov2.inventory_item_id '
							||'		AND   mfsdv2.sr_instance_id   = mov2.sr_instance_id '
							||'		AND   mov2.plan_id            = '|| l_plan_id ||' '
							||'		AND   mov2.category_set_id    = '|| ctgry_id_constant ||') sub2 '
                            ||'  ,msc_flp_supply_demand_v3 mfsdv '
							||'  ,xxnbty_dem_peg_id_tbl dpit ' --joined temp table 7/11/2015 AFLores
                             --||' ,xxnbty_catalog_staging_tbl xcst ' --Added 26/03/2015 Albert Flores
                    ||'  WHERE   mov.organization_code       = mtp.organization_code '
                    --||'  AND     mov.item_segments           = xcst.item_name ' --3/25/2015 Albert Flores
                    --||'  AND     xcst.organization_id        = mtp.sr_tp_id ' --3/25/2015 Albert Flores
                    ||'  AND     mov.plan_id                 = mp.plan_id '
                    ||'  AND     mov.compile_designator      = mp.compile_designator '
                    ||'  AND     mfsdv.demand_id             = mov.transaction_id '
                    ||'  AND     mfsdv.plan_id               = mov.plan_id '
                    ||'  AND     mfsdv.organization_id       = mov.organization_id '
                    ||'  AND     mfsdv.item_id               = mov.inventory_item_id '
                    ||'  AND     mfsdv.sr_instance_id        = mov.sr_instance_id '
                    ||'  AND     mov.source_table            = ''MSC_DEMANDS'' '
					||'  AND     sub2.pegging_id = mfsdv.prev_pegging_id '
					||'  AND mov.category_set_id     = ' || ctgry_id_constant || ' '
					||'  AND mov.plan_id             = '|| l_plan_id ||' '
					--||'  AND mfsdv.prev_pegging_id   IN (' || l_pegging_ids || ') ' 
					||'  AND     mfsdv.prev_pegging_id	     = dpit.pegging_id ' 		--where clause joining the temp table 7/11/2015 AFlores
					||'  AND     dpit.request_id 		     = ' || g_request_id || ' ' --where clause joining the temp table  7/11/2015 AFlores
					||'  ORDER BY mfsdv.pegging_id desc';
		 v_step := 8;
		 --FND_FILE.PUT_LINE(FND_FILE.LOG, 'Print of l_peg_query[ ' || l_peg_query || ' ]');
         OPEN c_rep_demand FOR l_peg_query; --3/20/2015 AFLORES
		 v_step := 9;
		 LOOP --loop_c_rep_demand --3/20/2015 AFLORES
		 FETCH c_rep_demand BULK COLLECT INTO l_current_peg LIMIT c_limit; --Applied for review points 3/20/2015 Albert Flores
			 --CLOSE c_rep;      --3/20/2015 AFLORES
		v_step := 10; 
			 l_peg_query := NULL; --clear dynamic query
			 l_pegging_ids := NULL; --clear collected pegging id
			 --FIX 8/13/2015 Albert Flores
			 /*
			 --delete from the staging table 7/11/2015 AFlores
			 DELETE FROM xxnbty_dem_peg_id_tbl
			 WHERE request_id = g_request_id;
			 COMMIT; --7/14/2015 Albert Flores
			 */
			 FOR k IN 1..l_current_peg.COUNT			 
			 LOOP 			 
				
				collect_rep( errbuf
							,retcode
							,l_current_peg(k));
				v_step := 11;
				--planned order
				l_peg_query := l_orig_query || ' AND mov.category_set_id            = :1 '
											|| ' AND mov.plan_id                    = :2 '
											|| ' AND mov.item_segments				= :3 '
											|| ' AND mov.organization_code 			= :4 '
											|| ' AND mov.sr_instance_id             = :5 '
											|| ' AND mov.transaction_id             = :6 '
											|| ' AND mfsdv.pegging_id               = :7 ';
				v_step := 12;						
				OPEN c_rep_order FOR l_peg_query USING ctgry_id_constant
												,l_current_peg(k).plan_id
												,l_current_peg(k).item
												,l_current_peg(k).org_code
												,l_current_peg(k).sr_instance_id
												,l_current_peg(k).transaction_id
												,l_current_peg(k).pegging_id;
				v_step := 13;								
				LOOP --loop_c_rep_order	3/20/2015 AFLORES							
				FETCH c_rep_order BULK COLLECT INTO l_pegging_rep LIMIT c_limit; --Applied for review points 3/20/2015 Albert Flores
					--CLOSE c_rep; 3/20/2015 AFLORES     
				v_step := 14;	
					--collect pegging ids from planned order  
					l_pegging_ids := l_pegging_ids || l_current_peg(k).pegging_id || ',';
					
					--START FIX 8/13/2015 Albert Flores
					/*
					--insert to table xxnbty_dem_peg_id_tbl 7/11/2015 AFlores
					INSERT INTO xxnbty_dem_peg_id_tbl(pegging_id, request_id, creation_date, created_by, last_update_date, last_updated_by) VALUES (l_current_peg(k).pegging_id, g_request_id, SYSDATE, g_created_by, SYSDATE, g_last_updated_by); --added who columns for xxnbty_dem_peg_id_tbl 7/14/2015 AFLORES
					COMMIT; --7/14/2015 Albert Flores
					*/
					ln_ctr := ln_ctr + 1;
					IF NOT v_tab_peg.EXISTS(ln_ctr) THEN
					   v_tab_peg.EXTEND;
					END IF;
					v_step := 11.5;
					v_tab_peg(ln_ctr).pegging_id	    := l_current_peg(k).pegging_id;
					v_tab_peg(ln_ctr).request_id        := g_request_id;
					v_tab_peg(ln_ctr).creation_date     := SYSDATE;
					v_tab_peg(ln_ctr).created_by        := g_created_by;
					v_tab_peg(ln_ctr).last_update_date  := SYSDATE;
					v_tab_peg(ln_ctr).last_updated_by   := g_last_updated_by;
					--END FIX 8/13/2015 Albert Flores
					
					FOR j IN 1..l_pegging_rep.COUNT
					LOOP
					v_step := 15;
					l_pegging_rep(j).pegging_order_no := l_current_peg(k).order_number;
	
					   collect_rep( errbuf
								   ,retcode
								   ,l_pegging_rep(j));
					END LOOP;
					v_step := 16;
				EXIT WHEN c_rep_order%NOTFOUND; --3/20/2015 AFLORES
				v_step := 17;
				END LOOP; --loop_c_rep_order --3/20/2015 AFLORES
				CLOSE c_rep_order; --3/20/2015 AFLORES
			 v_step := 18;	
			 END LOOP;
			 
			 l_pegging_ids := RTRIM(l_pegging_ids, ',');
			 
			 --EXIT WHEN l_pegging_ids IS NULL;
		 v_step := 19;
		 EXIT WHEN c_rep_demand%NOTFOUND;
		 END LOOP; --loop_c_rep_demand --3/20/2015 AFLORES
		 CLOSE c_rep_demand;
		 --START FIX 8/13/2015 Albert Flores
		 DELETE FROM xxnbty_dem_peg_id_tbl
		 WHERE request_id = g_request_id;
		 
		 FORALL i IN 1..v_tab_peg.COUNT
		 INSERT INTO xxnbty_dem_peg_id_tbl VALUES v_tab_peg(i);
		 
		 ln_ctr := 0;
		 v_tab_peg.DELETE;
		 
		 COMMIT; 
		 --END FIX 8/13/2015 Albert Flores
	     v_step := 20;
		 EXIT WHEN l_pegging_ids IS NULL;--7/10/2015
	  END LOOP; --loop_planned_order_demand
	  

	  v_step := 21;
	  EXIT WHEN c_rep_root2%NOTFOUND; --3/20/2015 AFLORES
	  END LOOP; --loop_c_rep_root2 --3/20/2015 AFLORES
	  CLOSE c_rep_root2; --3/20/2015 AFLORES
	  v_step := 22;
      l_peg_query := NULL; --clear dynamic query
      l_pegging_rep.DELETE; --clear collection 
	--FND_FILE.PUT_LINE(FND_FILE.LOG, 'End of  get_pegging_details. End time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');  
	EXCEPTION
			WHEN OTHERS THEN
			  v_mess := 'At step ['||v_step||'] for procedure get_pegging_details(SUPPLY) - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
			  errbuf  := v_mess;
			  retcode := 2;  
			  FND_FILE.PUT_LINE(FND_FILE.LOG,'Error message : ' || v_mess);	
   END get_pegging_details;
	
	--procedure that will re-assign records to designated icc type
	PROCEDURE collect_rep ( errbuf   OUT VARCHAR2
                          ,retcode  OUT NUMBER
                          ,p_icc	       icc_type)
	IS
	  v_step          NUMBER;
	  v_mess          VARCHAR2(500);	
	  dd_icc		  icc_type;
	  fg_icc		  icc_type;
	BEGIN
	--FND_FILE.PUT_LINE(FND_FILE.LOG, 'Start of  collect_rep. Start time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');				
		IF p_icc.catalog_group = icc_rm_constant THEN
         g_rm_index                                   := g_rm_index + 1;
		 g_rm_index_ctr                               := g_rm_index_ctr + 1;
		 v_step := 1;
         IF NOT g_temp_rec.EXISTS(g_rm_index_ctr) THEN
            g_temp_rec.EXTEND;
         END IF;
		 g_temp_rec(g_rm_index_ctr).record_id              := g_rm_index;
         g_temp_rec(g_rm_index_ctr).item_rm 			   := p_icc.item;
         g_temp_rec(g_rm_index_ctr).item_desc_rm		   := p_icc.item_desc;
         g_temp_rec(g_rm_index_ctr).org_code_rm			   := p_icc.org_code;
         g_temp_rec(g_rm_index_ctr).org_desc_rm			   := p_icc.org_desc;
         g_temp_rec(g_rm_index_ctr).excess_qty_rm		   := p_icc.excess_qty;
         g_temp_rec(g_rm_index_ctr).order_type_rm		   := p_icc.order_type;
         g_temp_rec(g_rm_index_ctr).due_date_rm			   := p_icc.due_date;
         g_temp_rec(g_rm_index_ctr).lot_number_rm		   := p_icc.lot_number;
         g_temp_rec(g_rm_index_ctr).psd_expiry_date_rm	   := p_icc.psd_expiry_date;
         g_temp_rec(g_rm_index_ctr).order_number_rm		   := p_icc.order_number;
         g_temp_rec(g_rm_index_ctr).source_org_rm		   := p_icc.source_org;
         g_temp_rec(g_rm_index_ctr).order_qty_rm		   := p_icc.order_qty;
         g_temp_rec(g_rm_index_ctr).pegging_order_no_rm	   := p_icc.pegging_order_no;
		 --Applied for review points 3/20/2015 Albert Flores
		 g_temp_rec(g_rm_index_ctr).last_update_date       := SYSDATE;
		 g_temp_rec(g_rm_index_ctr).last_updated_by        := g_last_updated_by;
		 g_temp_rec(g_rm_index_ctr).last_update_login      := g_last_updated_by;
		 g_temp_rec(g_rm_index_ctr).creation_date          := SYSDATE;
		 g_temp_rec(g_rm_index_ctr).created_by             := g_created_by;
		 g_temp_rec(g_rm_index_ctr).request_id             := g_request_id;
		 --Applied 3/31/2015 Albert Flores
		 g_temp_rec(g_rm_index_ctr).pegging_id             := p_icc.pegging_id;
		 --Applied 4/24/04/2015 Albert Flores
		 g_temp_rec(g_rm_index_ctr).pegging_type           := 'SUPPLY';
		 --Applied 7/21/2015 Albert Flores
		 g_temp_rec(g_rm_index_ctr).order_priority_rm      := p_icc.order_priority;
		 --CHANGE REQUEST 7/21/2015 Albert Flores
		 g_temp_rec(g_rm_index_ctr).item_dd 			     := NVL(g_dd_icc.item, NULL);
		 g_temp_rec(g_rm_index_ctr).item_desc_dd		     := NVL(g_dd_icc.item_desc, NULL);
		 g_temp_rec(g_rm_index_ctr).org_code_dd			     := NVL(g_dd_icc.org_code, NULL);
		 g_temp_rec(g_rm_index_ctr).org_desc_dd			     := NVL(g_dd_icc.org_desc, NULL);
		 g_temp_rec(g_rm_index_ctr).excess_qty_dd		     := NVL(g_dd_icc.excess_qty, NULL);
		 g_temp_rec(g_rm_index_ctr).order_type_dd		     := NVL(g_dd_icc.order_type, NULL);
		 g_temp_rec(g_rm_index_ctr).due_date_dd			     := NVL(g_dd_icc.due_date, NULL);
		 g_temp_rec(g_rm_index_ctr).lot_number_dd		     := NVL(g_dd_icc.lot_number, NULL);
		 g_temp_rec(g_rm_index_ctr).psd_expiry_date_dd	     := NVL(g_dd_icc.psd_expiry_date, NULL);
		 g_temp_rec(g_rm_index_ctr).order_number_dd		     := NVL(g_dd_icc.order_number, NULL);
		 g_temp_rec(g_rm_index_ctr).source_org_dd		     := NVL(g_dd_icc.source_org, NULL);
		 g_temp_rec(g_rm_index_ctr).order_qty_dd		     := NVL(g_dd_icc.order_qty, NULL);
		 g_temp_rec(g_rm_index_ctr).pegging_order_no_dd	     := NVL(g_dd_icc.pegging_order_no, NULL);
		 g_temp_rec(g_rm_index_ctr).order_priority_dd        := NVL(g_dd_icc.order_priority, NULL);
		 g_temp_rec(g_rm_index_ctr).source_order_priority_dd := NVL(g_dd_icc.source_order_priority, NULL);	  
		 g_temp_rec(g_rm_index_ctr).item_fg 			     := NVL(g_fg_icc.item, NULL);
         g_temp_rec(g_rm_index_ctr).item_desc_fg		     := NVL(g_fg_icc.item_desc, NULL);
         g_temp_rec(g_rm_index_ctr).org_code_fg			     := NVL(g_fg_icc.org_code, NULL);
         g_temp_rec(g_rm_index_ctr).org_desc_fg			     := NVL(g_fg_icc.org_desc, NULL);
         g_temp_rec(g_rm_index_ctr).excess_qty_fg		     := NVL(g_fg_icc.excess_qty, NULL);
         g_temp_rec(g_rm_index_ctr).order_type_fg		     := NVL(g_fg_icc.order_type, NULL);
         g_temp_rec(g_rm_index_ctr).due_date_fg			     := NVL(g_fg_icc.due_date, NULL);
         g_temp_rec(g_rm_index_ctr).lot_number_fg		     := NVL(g_fg_icc.lot_number, NULL);
         g_temp_rec(g_rm_index_ctr).psd_expiry_date_fg	     := NVL(g_fg_icc.psd_expiry_date, NULL);
         g_temp_rec(g_rm_index_ctr).order_number_fg		     := NVL(g_fg_icc.order_number, NULL);
         g_temp_rec(g_rm_index_ctr).source_org_fg		     := NVL(g_fg_icc.source_org, NULL);
         g_temp_rec(g_rm_index_ctr).order_qty_fg		     := NVL(g_fg_icc.order_qty, NULL);
         g_temp_rec(g_rm_index_ctr).pegging_order_no_fg	     := NVL(g_fg_icc.pegging_order_no, NULL);
         g_temp_rec(g_rm_index_ctr).order_priority_fg        := NVL(g_fg_icc.order_priority, NULL);
         g_temp_rec(g_rm_index_ctr).source_order_priority_fg := NVL(g_fg_icc.source_order_priority, NULL);
      
	  ELSIF p_icc.catalog_group = icc_bl_constant THEN
         g_bl_index                                    := g_bl_index + 1;
		 g_bl_index_ctr                                := g_bl_index_ctr + 1;
		 v_step := 2;
         IF NOT g_temp_rec.EXISTS(g_bl_index_ctr) THEN
            g_temp_rec.EXTEND;
         END IF;
		 g_temp_rec(g_bl_index_ctr).record_id              := g_bl_index;
         g_temp_rec(g_bl_index_ctr).item_bl 			   := p_icc.item;
         g_temp_rec(g_bl_index_ctr).item_desc_bl		   := p_icc.item_desc;
         g_temp_rec(g_bl_index_ctr).org_code_bl			   := p_icc.org_code;
         g_temp_rec(g_bl_index_ctr).org_desc_bl			   := p_icc.org_desc;
         g_temp_rec(g_bl_index_ctr).excess_qty_bl		   := p_icc.excess_qty;
         g_temp_rec(g_bl_index_ctr).order_type_bl		   := p_icc.order_type;
         g_temp_rec(g_bl_index_ctr).due_date_bl			   := p_icc.due_date;
         g_temp_rec(g_bl_index_ctr).lot_number_bl		   := p_icc.lot_number;
         g_temp_rec(g_bl_index_ctr).psd_expiry_date_bl	   := p_icc.psd_expiry_date;
         g_temp_rec(g_bl_index_ctr).order_number_bl		   := p_icc.order_number;
         g_temp_rec(g_bl_index_ctr).source_org_bl		   := p_icc.source_org;
         g_temp_rec(g_bl_index_ctr).order_qty_bl		   := p_icc.order_qty;
         g_temp_rec(g_bl_index_ctr).pegging_order_no_bl	   := p_icc.pegging_order_no;
		 --Applied for review points 3/20/2015 Albert Flores
		 g_temp_rec(g_bl_index_ctr).last_update_date       := SYSDATE;
		 g_temp_rec(g_bl_index_ctr).last_updated_by        := g_last_updated_by;
		 g_temp_rec(g_bl_index_ctr).last_update_login      := g_last_updated_by;
		 g_temp_rec(g_bl_index_ctr).creation_date          := SYSDATE;
		 g_temp_rec(g_bl_index_ctr).created_by             := g_created_by;
		 g_temp_rec(g_bl_index_ctr).request_id             := g_request_id;		
		 --Applied 3/31/2015 Albert Flores
		 g_temp_rec(g_bl_index_ctr).pegging_id             := p_icc.pegging_id;
		 --Applied 4/24/04/2015 Albert Flores
		 g_temp_rec(g_bl_index_ctr).pegging_type           := 'SUPPLY';
		 --Applied 7/21/2015 Albert Flores
		 g_temp_rec(g_bl_index_ctr).order_priority_bl       := p_icc.order_priority;	
		 --CHANGE REQUEST 7/21/2015 Albert Flores
		 g_temp_rec(g_bl_index_ctr).item_dd 			     := NVL(g_dd_icc.item, NULL);
		 g_temp_rec(g_bl_index_ctr).item_desc_dd		     := NVL(g_dd_icc.item_desc, NULL);
		 g_temp_rec(g_bl_index_ctr).org_code_dd			     := NVL(g_dd_icc.org_code, NULL);
		 g_temp_rec(g_bl_index_ctr).org_desc_dd			     := NVL(g_dd_icc.org_desc, NULL);
		 g_temp_rec(g_bl_index_ctr).excess_qty_dd		     := NVL(g_dd_icc.excess_qty, NULL);
		 g_temp_rec(g_bl_index_ctr).order_type_dd		     := NVL(g_dd_icc.order_type, NULL);
		 g_temp_rec(g_bl_index_ctr).due_date_dd			     := NVL(g_dd_icc.due_date, NULL);
		 g_temp_rec(g_bl_index_ctr).lot_number_dd		     := NVL(g_dd_icc.lot_number, NULL);
		 g_temp_rec(g_bl_index_ctr).psd_expiry_date_dd	     := NVL(g_dd_icc.psd_expiry_date, NULL);
		 g_temp_rec(g_bl_index_ctr).order_number_dd		     := NVL(g_dd_icc.order_number, NULL);
		 g_temp_rec(g_bl_index_ctr).source_org_dd		     := NVL(g_dd_icc.source_org, NULL);
		 g_temp_rec(g_bl_index_ctr).order_qty_dd		     := NVL(g_dd_icc.order_qty, NULL);
		 g_temp_rec(g_bl_index_ctr).pegging_order_no_dd	     := NVL(g_dd_icc.pegging_order_no, NULL);
		 g_temp_rec(g_bl_index_ctr).order_priority_dd        := NVL(g_dd_icc.order_priority, NULL);
		 g_temp_rec(g_bl_index_ctr).source_order_priority_dd := NVL(g_dd_icc.source_order_priority, NULL);	  
		 g_temp_rec(g_bl_index_ctr).item_fg 			     := NVL(g_fg_icc.item, NULL);
         g_temp_rec(g_bl_index_ctr).item_desc_fg		     := NVL(g_fg_icc.item_desc, NULL);
         g_temp_rec(g_bl_index_ctr).org_code_fg			     := NVL(g_fg_icc.org_code, NULL);
         g_temp_rec(g_bl_index_ctr).org_desc_fg			     := NVL(g_fg_icc.org_desc, NULL);
         g_temp_rec(g_bl_index_ctr).excess_qty_fg		     := NVL(g_fg_icc.excess_qty, NULL);
         g_temp_rec(g_bl_index_ctr).order_type_fg		     := NVL(g_fg_icc.order_type, NULL);
         g_temp_rec(g_bl_index_ctr).due_date_fg			     := NVL(g_fg_icc.due_date, NULL);
         g_temp_rec(g_bl_index_ctr).lot_number_fg		     := NVL(g_fg_icc.lot_number, NULL);
         g_temp_rec(g_bl_index_ctr).psd_expiry_date_fg	     := NVL(g_fg_icc.psd_expiry_date, NULL);
         g_temp_rec(g_bl_index_ctr).order_number_fg		     := NVL(g_fg_icc.order_number, NULL);
         g_temp_rec(g_bl_index_ctr).source_org_fg		     := NVL(g_fg_icc.source_org, NULL);
         g_temp_rec(g_bl_index_ctr).order_qty_fg		     := NVL(g_fg_icc.order_qty, NULL);
         g_temp_rec(g_bl_index_ctr).pegging_order_no_fg	     := NVL(g_fg_icc.pegging_order_no, NULL);
         g_temp_rec(g_bl_index_ctr).order_priority_fg        := NVL(g_fg_icc.order_priority, NULL);
         g_temp_rec(g_bl_index_ctr).source_order_priority_fg := NVL(g_fg_icc.source_order_priority, NULL);
		 
      ELSIF p_icc.catalog_group = icc_bc_constant THEN
         g_bc_index                                    := g_bc_index + 1;
		 g_bc_index_ctr                                := g_bc_index_ctr + 1;
		 v_step := 3;
         IF NOT g_temp_rec.EXISTS(g_bc_index_ctr) THEN
            g_temp_rec.EXTEND;
         END IF;
		 g_temp_rec(g_bc_index_ctr).record_id              := g_bc_index;
         g_temp_rec(g_bc_index_ctr).item_bc 			   := p_icc.item;
         g_temp_rec(g_bc_index_ctr).item_desc_bc		   := p_icc.item_desc;
         g_temp_rec(g_bc_index_ctr).org_code_bc			   := p_icc.org_code;
         g_temp_rec(g_bc_index_ctr).org_desc_bc			   := p_icc.org_desc;
         g_temp_rec(g_bc_index_ctr).excess_qty_bc		   := p_icc.excess_qty;
         g_temp_rec(g_bc_index_ctr).order_type_bc		   := p_icc.order_type;
         g_temp_rec(g_bc_index_ctr).due_date_bc			   := p_icc.due_date;
         g_temp_rec(g_bc_index_ctr).lot_number_bc		   := p_icc.lot_number;
         g_temp_rec(g_bc_index_ctr).psd_expiry_date_bc	   := p_icc.psd_expiry_date;
         g_temp_rec(g_bc_index_ctr).order_number_bc		   := p_icc.order_number;
         g_temp_rec(g_bc_index_ctr).source_org_bc		   := p_icc.source_org;
         g_temp_rec(g_bc_index_ctr).order_qty_bc		   := p_icc.order_qty;
         g_temp_rec(g_bc_index_ctr).pegging_order_no_bc	   := p_icc.pegging_order_no;
		 --Applied for review points 3/20/2015 Albert Flores
		 g_temp_rec(g_bc_index_ctr).last_update_date       := SYSDATE;
		 g_temp_rec(g_bc_index_ctr).last_updated_by        := g_last_updated_by;
		 g_temp_rec(g_bc_index_ctr).last_update_login      := g_last_updated_by;
		 g_temp_rec(g_bc_index_ctr).creation_date          := SYSDATE;
		 g_temp_rec(g_bc_index_ctr).created_by             := g_created_by;
		 g_temp_rec(g_bc_index_ctr).request_id             := g_request_id;	
		 --Applied 3/31/2015 Albert Flores
		 g_temp_rec(g_bc_index_ctr).pegging_id             := p_icc.pegging_id;
		 --Applied 4/24/04/2015 Albert Flores
		 g_temp_rec(g_bc_index_ctr).pegging_type           := 'SUPPLY';
		 --Applied 7/21/2015 Albert Flores
		 g_temp_rec(g_bc_index_ctr).order_priority_bc      := p_icc.order_priority;
		 --CHANGE REQUEST 7/21/2015 Albert Flores
		 g_temp_rec(g_bc_index_ctr).item_dd 			     := NVL(g_dd_icc.item, NULL);
		 g_temp_rec(g_bc_index_ctr).item_desc_dd		     := NVL(g_dd_icc.item_desc, NULL);
		 g_temp_rec(g_bc_index_ctr).org_code_dd			     := NVL(g_dd_icc.org_code, NULL);
		 g_temp_rec(g_bc_index_ctr).org_desc_dd			     := NVL(g_dd_icc.org_desc, NULL);
		 g_temp_rec(g_bc_index_ctr).excess_qty_dd		     := NVL(g_dd_icc.excess_qty, NULL);
		 g_temp_rec(g_bc_index_ctr).order_type_dd		     := NVL(g_dd_icc.order_type, NULL);
		 g_temp_rec(g_bc_index_ctr).due_date_dd			     := NVL(g_dd_icc.due_date, NULL);
		 g_temp_rec(g_bc_index_ctr).lot_number_dd		     := NVL(g_dd_icc.lot_number, NULL);
		 g_temp_rec(g_bc_index_ctr).psd_expiry_date_dd	     := NVL(g_dd_icc.psd_expiry_date, NULL);
		 g_temp_rec(g_bc_index_ctr).order_number_dd		     := NVL(g_dd_icc.order_number, NULL);
		 g_temp_rec(g_bc_index_ctr).source_org_dd		     := NVL(g_dd_icc.source_org, NULL);
		 g_temp_rec(g_bc_index_ctr).order_qty_dd		     := NVL(g_dd_icc.order_qty, NULL);
		 g_temp_rec(g_bc_index_ctr).pegging_order_no_dd	     := NVL(g_dd_icc.pegging_order_no, NULL);
		 g_temp_rec(g_bc_index_ctr).order_priority_dd        := NVL(g_dd_icc.order_priority, NULL);
		 g_temp_rec(g_bc_index_ctr).source_order_priority_dd := NVL(g_dd_icc.source_order_priority, NULL);	  
		 g_temp_rec(g_bc_index_ctr).item_fg 			     := NVL(g_fg_icc.item, NULL);
         g_temp_rec(g_bc_index_ctr).item_desc_fg		     := NVL(g_fg_icc.item_desc, NULL);
         g_temp_rec(g_bc_index_ctr).org_code_fg			     := NVL(g_fg_icc.org_code, NULL);
         g_temp_rec(g_bc_index_ctr).org_desc_fg			     := NVL(g_fg_icc.org_desc, NULL);
         g_temp_rec(g_bc_index_ctr).excess_qty_fg		     := NVL(g_fg_icc.excess_qty, NULL);
         g_temp_rec(g_bc_index_ctr).order_type_fg		     := NVL(g_fg_icc.order_type, NULL);
         g_temp_rec(g_bc_index_ctr).due_date_fg			     := NVL(g_fg_icc.due_date, NULL);
         g_temp_rec(g_bc_index_ctr).lot_number_fg		     := NVL(g_fg_icc.lot_number, NULL);
         g_temp_rec(g_bc_index_ctr).psd_expiry_date_fg	     := NVL(g_fg_icc.psd_expiry_date, NULL);
         g_temp_rec(g_bc_index_ctr).order_number_fg		     := NVL(g_fg_icc.order_number, NULL);
         g_temp_rec(g_bc_index_ctr).source_org_fg		     := NVL(g_fg_icc.source_org, NULL);
         g_temp_rec(g_bc_index_ctr).order_qty_fg		     := NVL(g_fg_icc.order_qty, NULL);
         g_temp_rec(g_bc_index_ctr).pegging_order_no_fg	     := NVL(g_fg_icc.pegging_order_no, NULL);
         g_temp_rec(g_bc_index_ctr).order_priority_fg        := NVL(g_fg_icc.order_priority, NULL);
         g_temp_rec(g_bc_index_ctr).source_order_priority_fg := NVL(g_fg_icc.source_order_priority, NULL);
		 
		 		 
      ELSIF p_icc.catalog_group = icc_fg_constant THEN
         g_fg_index                                    := g_fg_index + 1;
		 g_fg_index_ctr                                := g_fg_index_ctr + 1;
		 v_step := 4;
         IF NOT g_temp_rec.EXISTS(g_fg_index_ctr) THEN
            g_temp_rec.EXTEND;
         END IF;
		 g_temp_rec(g_fg_index_ctr).record_id              := g_fg_index;
         g_temp_rec(g_fg_index_ctr).item_fg 			   := p_icc.item;
		 g_temp_rec(g_fg_index_ctr).item_desc_fg		   := p_icc.item_desc;
		 g_temp_rec(g_fg_index_ctr).org_code_fg			   := p_icc.org_code;
		 g_temp_rec(g_fg_index_ctr).org_desc_fg			   := p_icc.org_desc;
		 g_temp_rec(g_fg_index_ctr).excess_qty_fg		   := p_icc.excess_qty;
		 g_temp_rec(g_fg_index_ctr).order_type_fg		   := p_icc.order_type;
		 g_temp_rec(g_fg_index_ctr).due_date_fg			   := p_icc.due_date;
		 g_temp_rec(g_fg_index_ctr).lot_number_fg		   := p_icc.lot_number;
		 g_temp_rec(g_fg_index_ctr).psd_expiry_date_fg	   := p_icc.psd_expiry_date;
		 g_temp_rec(g_fg_index_ctr).order_number_fg		   := p_icc.order_number;
		 g_temp_rec(g_fg_index_ctr).source_org_fg		   := p_icc.source_org;
		 g_temp_rec(g_fg_index_ctr).order_qty_fg		   := p_icc.order_qty;
		 g_temp_rec(g_fg_index_ctr).pegging_order_no_fg	   := p_icc.pegging_order_no;
		 --Applied for review points 3/20/2015 Albert Flores
		 g_temp_rec(g_fg_index_ctr).last_update_date       := SYSDATE;
		 g_temp_rec(g_fg_index_ctr).last_updated_by        := g_last_updated_by;
		 g_temp_rec(g_fg_index_ctr).last_update_login      := g_last_updated_by;
		 g_temp_rec(g_fg_index_ctr).creation_date          := SYSDATE;
		 g_temp_rec(g_fg_index_ctr).created_by             := g_created_by;
		 g_temp_rec(g_fg_index_ctr).request_id             := g_request_id;	
		 --Applied 3/31/2015 Albert Flores
		 g_temp_rec(g_fg_index_ctr).pegging_id             := p_icc.pegging_id;
		 --Applied 4/24/04/2015 Albert Flores
		 g_temp_rec(g_fg_index_ctr).pegging_type           := 'SUPPLY';
		 --Applied 7/21/2015 Albert Flores
		 g_temp_rec(g_fg_index_ctr).order_priority_fg         := p_icc.order_priority;
		 g_temp_rec(g_fg_index_ctr).source_order_priority_fg  := p_icc.source_order_priority;	
		 --CHANGE REQUEST 7/21/2015 Albert Flores
		 g_fg_icc.item									     := p_icc.item;
		 g_fg_icc.item_desc                                  := p_icc.item_desc;
		 g_fg_icc.org_code                                   := p_icc.org_code;
		 g_fg_icc.org_desc                                   := p_icc.org_desc;
		 g_fg_icc.excess_qty                                 := p_icc.excess_qty;
		 g_fg_icc.order_type                                 := p_icc.order_type;
		 g_fg_icc.due_date                                   := p_icc.due_date;
		 g_fg_icc.lot_number                                 := p_icc.lot_number;
		 g_fg_icc.psd_expiry_date                            := p_icc.psd_expiry_date;
		 g_fg_icc.order_number                               := p_icc.order_number;
		 g_fg_icc.source_org                                 := p_icc.source_org;
		 g_fg_icc.order_qty                                  := p_icc.order_qty;
		 g_fg_icc.pegging_order_no                           := p_icc.pegging_order_no;
		 g_fg_icc.order_priority                             := p_icc.order_priority;
		 g_fg_icc.source_order_priority                      := p_icc.source_order_priority;
		 g_temp_rec(g_fg_index_ctr).item_dd 			     := NVL(g_dd_icc.item, NULL);
		 g_temp_rec(g_fg_index_ctr).item_desc_dd		     := NVL(g_dd_icc.item_desc, NULL);
		 g_temp_rec(g_fg_index_ctr).org_code_dd			     := NVL(g_dd_icc.org_code, NULL);
		 g_temp_rec(g_fg_index_ctr).org_desc_dd			     := NVL(g_dd_icc.org_desc, NULL);
		 g_temp_rec(g_fg_index_ctr).excess_qty_dd		     := NVL(g_dd_icc.excess_qty, NULL);
		 g_temp_rec(g_fg_index_ctr).order_type_dd		     := NVL(g_dd_icc.order_type, NULL);
		 g_temp_rec(g_fg_index_ctr).due_date_dd			     := NVL(g_dd_icc.due_date, NULL);
		 g_temp_rec(g_fg_index_ctr).lot_number_dd		     := NVL(g_dd_icc.lot_number, NULL);
		 g_temp_rec(g_fg_index_ctr).psd_expiry_date_dd	     := NVL(g_dd_icc.psd_expiry_date, NULL);
		 g_temp_rec(g_fg_index_ctr).order_number_dd		     := NVL(g_dd_icc.order_number, NULL);
		 g_temp_rec(g_fg_index_ctr).source_org_dd		     := NVL(g_dd_icc.source_org, NULL);
		 g_temp_rec(g_fg_index_ctr).order_qty_dd		     := NVL(g_dd_icc.order_qty, NULL);
		 g_temp_rec(g_fg_index_ctr).pegging_order_no_dd	     := NVL(g_dd_icc.pegging_order_no, NULL);
		 g_temp_rec(g_fg_index_ctr).order_priority_dd        := NVL(g_dd_icc.order_priority, NULL);
		 g_temp_rec(g_fg_index_ctr).source_order_priority_dd := NVL(g_dd_icc.source_order_priority, NULL);

      ELSIF p_icc.catalog_group = icc_dd_constant THEN
         g_dd_index                                    := g_dd_index + 1;
		 g_dd_index_ctr                                := g_dd_index_ctr + 1;
		 v_step := 5;
         IF NOT g_temp_rec.EXISTS(g_dd_index_ctr) THEN
            g_temp_rec.EXTEND;
         END IF;
		 g_temp_rec(g_dd_index_ctr).record_id              := g_dd_index;
         g_temp_rec(g_dd_index_ctr).item_dd 			   := p_icc.item;
         g_temp_rec(g_dd_index_ctr).item_desc_dd		   := p_icc.item_desc;
         g_temp_rec(g_dd_index_ctr).org_code_dd			   := p_icc.org_code;
         g_temp_rec(g_dd_index_ctr).org_desc_dd			   := p_icc.org_desc;
         g_temp_rec(g_dd_index_ctr).excess_qty_dd		   := p_icc.excess_qty;
         g_temp_rec(g_dd_index_ctr).order_type_dd		   := p_icc.order_type;
         g_temp_rec(g_dd_index_ctr).due_date_dd			   := p_icc.due_date;
         g_temp_rec(g_dd_index_ctr).lot_number_dd		   := p_icc.lot_number;
         g_temp_rec(g_dd_index_ctr).psd_expiry_date_dd	   := p_icc.psd_expiry_date;
         g_temp_rec(g_dd_index_ctr).order_number_dd		   := p_icc.order_number;
         g_temp_rec(g_dd_index_ctr).source_org_dd		   := p_icc.source_org;
         g_temp_rec(g_dd_index_ctr).order_qty_dd		   := p_icc.order_qty;
         g_temp_rec(g_dd_index_ctr).pegging_order_no_dd	   := p_icc.pegging_order_no;
		 --Applied for review points 3/20/2015 Albert Flores
		 g_temp_rec(g_dd_index_ctr).last_update_date       := SYSDATE;
		 g_temp_rec(g_dd_index_ctr).last_updated_by        := g_last_updated_by;
		 g_temp_rec(g_dd_index_ctr).last_update_login      := g_last_updated_by;
		 g_temp_rec(g_dd_index_ctr).creation_date          := SYSDATE;
		 g_temp_rec(g_dd_index_ctr).created_by             := g_created_by;
		 g_temp_rec(g_dd_index_ctr).request_id             := g_request_id;	
		--Applied 3/31/2015 Albert Flores
		 g_temp_rec(g_dd_index_ctr).pegging_id             := p_icc.pegging_id;
		 --Applied 4/24/04/2015 Albert Flores
		 g_temp_rec(g_dd_index_ctr).pegging_type           := 'SUPPLY';
		 --Applied 7/21/2015 Albert Flores
		 g_temp_rec(g_dd_index_ctr).order_priority_dd         := p_icc.order_priority;
		 g_temp_rec(g_dd_index_ctr).source_order_priority_dd  := p_icc.source_order_priority;	
		 --CHANGE REQUEST 7/21/2015 Albert Flores
		 g_dd_icc.item									     := p_icc.item;
		 g_dd_icc.item_desc                                  := p_icc.item_desc;
		 g_dd_icc.org_code                                   := p_icc.org_code;
		 g_dd_icc.org_desc                                   := p_icc.org_desc;
		 g_dd_icc.excess_qty                                 := p_icc.excess_qty;
		 g_dd_icc.order_type                                 := p_icc.order_type;
		 g_dd_icc.due_date                                   := p_icc.due_date;
		 g_dd_icc.lot_number                                 := p_icc.lot_number;
		 g_dd_icc.psd_expiry_date                            := p_icc.psd_expiry_date;
		 g_dd_icc.order_number                               := p_icc.order_number;
		 g_dd_icc.source_org                                 := p_icc.source_org;
		 g_dd_icc.order_qty                                  := p_icc.order_qty;
		 g_dd_icc.pegging_order_no                           := p_icc.pegging_order_no;
		 g_dd_icc.order_priority                             := p_icc.order_priority;
		 g_dd_icc.source_order_priority                      := p_icc.source_order_priority;

	  v_step := 5; 
      END IF;
    --FND_FILE.PUT_LINE(FND_FILE.LOG, 'End of collect_rep. End time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');  
	EXCEPTION
			WHEN OTHERS THEN
			  v_mess := 'At step ['||v_step||'] for procedure collect_rep(SUPPLY) - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
			  errbuf  := v_mess;
			  retcode := 2; 	
			  FND_FILE.PUT_LINE(FND_FILE.LOG,'Error message : ' || v_mess);	
	END collect_rep;
  
	--procedure that will populate temp table
	PROCEDURE populate_temp_table( errbuf   		OUT VARCHAR2
                                  ,retcode  		 OUT NUMBER
                                  ,p_temp_tab	     temp_tab_type)
	IS
	--l_request_id    NUMBER := fnd_global.conc_request_id;
	  v_step          NUMBER;
	  v_mess          VARCHAR2(500);	
	
	BEGIN
	--FND_FILE.PUT_LINE(FND_FILE.LOG, 'Start of  populate_temp_table. Start time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');
	v_step := 1;
	/*
      --delete old records
      DELETE FROM xxnbty_pegging_temp_tbl
      WHERE (TRUNC(SYSDATE) - TO_DATE(creation_date)) > 5;
      COMMIT; 
	*/
	v_step := 2;  
      --insert new records 

      FORALL i IN 1..p_temp_tab.COUNT	  
      INSERT /*+APPEND*/ INTO xxnbty_pegging_temp_tbl VALUES p_temp_tab(i); --Applied for review points 3/20/2015 Albert Flores
      COMMIT;
	v_step := 3;  
      /*
	  UPDATE xxnbty_pegging_temp_tbl
      SET  last_update_date  = SYSDATE
          ,last_updated_by   = g_last_updated_by
          ,last_update_login = g_last_updated_by						    --Removed for review points 3/20/2015 Albert Flores
          ,creation_date     = SYSDATE
          ,created_by        = g_created_by
          ,request_id        = l_request_id
	  WHERE  request_id is null;
          
      COMMIT;    
	  */
	--FND_FILE.PUT_LINE(FND_FILE.LOG, 'End of  populate_temp_table. End time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');  
	EXCEPTION
			WHEN OTHERS THEN
			  v_mess := 'At step ['||v_step||'] for procedure populate_temp_table(SUPPLY) - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
			  errbuf  := v_mess;
			  retcode := 2;  
			  FND_FILE.PUT_LINE(FND_FILE.LOG,'Error message : ' || v_mess);	
	END populate_temp_table;
	
	PROCEDURE generate_pegging_report( errbuf   		 OUT VARCHAR2
                                 	  ,retcode  		 OUT NUMBER
                                      ,x_request_id	  	 NUMBER
									  ,p_plan_name       msc_orders_v.compile_designator%TYPE
									  ,p_org_code        msc_orders_v.organization_code%TYPE
									  ,p_catalog_group	 VARCHAR2
									  ,p_planner_code	 msc_orders_v.planner_code%TYPE
									  ,p_purchased_flag  msc_orders_v.purchasing_enabled_flag%TYPE
									  ,p_item_name		 msc_orders_v.item_segments%TYPE
									  ,p_main_from_date	 VARCHAR2
									  ,p_main_to_date	 VARCHAR2
									  ,p_pegging_type    VARCHAR2) --Added 24/04/2015 Albert Flores
    IS
	    r_request_id  NUMBER;
	    l_flag1        BOOLEAN;
	    l_flag2        BOOLEAN;
	
	BEGIN
	--FND_FILE.PUT_LINE(FND_FILE.LOG, 'Start of  generate_pegging_report. Start time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');
	IF p_pegging_type = 'BOTH' THEN --Added 24/04/2015 Albert Flores
	
		XXNBTY_MSCREP01_PEGG_DEM_PKG.main_pr(errbuf        	
												  ,retcode       	 
												  ,p_plan_name        
												  ,p_org_code         
												  ,p_catalog_group	 
												  ,p_planner_code	 
												  ,p_purchased_flag   
												  ,p_item_name		 
												  ,p_main_from_date	 
												  ,p_main_to_date); --Added 24/04/2015 Albert Flores
	ELSE
		--create layout for Pegging Report
		l_flag1 := FND_REQUEST.ADD_LAYOUT ('XXNBTY',
										  'XXNBTY_MSC_GEN_PEG_REPORT',
										  'En',
										  'US',
										  'EXCEL' );
		IF (l_flag1) THEN
		  FND_FILE.PUT_LINE(FND_FILE.LOG, 'The layout has been submitted');
		ELSE
		  FND_FILE.PUT_LINE(FND_FILE.LOG, 'The layout has not been submitted');
		END IF;

    r_request_id := FND_REQUEST.SUBMIT_REQUEST(application   => 'XXNBTY'
                                               ,program      => 'XXNBTY_MSC_GEN_PEG_REPORT'
                                               ,start_time   => NULL --Applied for review points 3/20/2015 Albert Flores
                                               ,sub_request  => FALSE
                                               ,Argument1 	 => x_request_id
											   ,Argument2	 => p_plan_name
											   ,Argument3	 => p_org_code
											   ,Argument4 	 => p_catalog_group
											   ,Argument5	 => p_planner_code
											   ,Argument6	 => p_purchased_flag
											   ,Argument7 	 => p_item_name
											   ,Argument8	 => p_main_from_date
											   ,Argument9	 => p_main_to_date
                                               );
    FND_CONCURRENT.AF_COMMIT;
	--FND_FILE.PUT_LINE(FND_FILE.LOG, 'End of generate_pegging_report. End time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');
    END IF;
    EXCEPTION
    WHEN OTHERS THEN
      retcode := 2;
      errbuf := SQLERRM;
	  FND_FILE.PUT_LINE(FND_FILE.LOG,'Error message : ' || errbuf);	
    END generate_pegging_report; 
	--ADDED 7/15/2015 AFLORES
	--START
	PROCEDURE generate_pegging_csv_log (errbuf   		 	OUT VARCHAR2
										  ,retcode  		 	OUT NUMBER
										  ,p_plan_name       	msc_orders_v.compile_designator%TYPE 
										  ,p_org_code        	msc_orders_v.organization_code%TYPE 
										  ,p_catalog_group	 	VARCHAR2 
										  ,p_planner_code	 	msc_orders_v.planner_code%TYPE 
										  ,p_purchased_flag  	msc_orders_v.purchasing_enabled_flag%TYPE 
										  ,p_item_name		 	msc_orders_v.item_segments%TYPE 
										  ,p_main_from_date		VARCHAR2 
										  ,p_main_to_date	 	VARCHAR2 
										  ,p_pegging_type	 	VARCHAR2
										  ,p_request_id			NUMBER)                            
    IS
		  
		CURSOR c_gen_sup_peg_rep (p_main_request_id NUMBER)
		IS
		SELECT '"'||pegging_type
				|| '","' ||item_rm 
				|| '","' ||item_desc_rm 
				|| '","' ||org_code_rm 
				|| '","' ||org_desc_rm 
				|| '","' ||excess_qty_rm 
				|| '","' ||order_type_rm 
				|| '","' ||TO_CHAR(due_date_rm, 'DD-MON-YYYY') 
				|| '","' ||lot_number_rm 
				|| '","' ||TO_CHAR(psd_expiry_date_rm, 'DD-MON-YYYY') 
				|| '","' ||order_number_rm 
				|| '","' ||source_org_rm 
				|| '","' ||order_qty_rm 
				|| '","' ||order_priority_rm --7/21/2015 AFlores
				|| '","' ||pegging_order_no_rm 
				|| '","' ||item_bl 
				|| '","' ||item_desc_bl 
				|| '","' ||org_code_bl 
				|| '","' ||org_desc_bl 
				|| '","' ||excess_qty_bl 
				|| '","' ||order_type_bl 
				|| '","' ||TO_CHAR(due_date_bl, 'DD-MON-YYYY') 
				|| '","' ||lot_number_bl 
				|| '","' ||TO_CHAR(psd_expiry_date_bl, 'DD-MON-YYYY') 
				|| '","' ||order_number_bl 
				|| '","' ||source_org_bl 
				|| '","' ||order_qty_bl 
				|| '","' ||order_priority_bl --7/21/2015 AFlores
				|| '","' ||pegging_order_no_bl 
				|| '","' ||item_bc 
				|| '","' ||item_desc_bc 
				|| '","' ||org_code_bc 
				|| '","' ||org_desc_bc 
				|| '","' ||excess_qty_bc 
				|| '","' ||order_type_bc 
				|| '","' ||TO_CHAR(due_date_bc, 'DD-MON-YYYY') 
				|| '","' ||lot_number_bc 
				|| '","' ||TO_CHAR(psd_expiry_date_bc, 'DD-MON_YYYY') 
				|| '","' ||order_number_bc 
				|| '","' ||source_org_bc 
				|| '","' ||order_qty_bc 
				|| '","' ||order_priority_bc --7/21/2015 AFlores
				|| '","' ||pegging_order_no_bc 
				|| '","' ||item_fg 
				|| '","' ||item_desc_fg 
				|| '","' ||org_code_fg 
				|| '","' ||org_desc_fg 
				|| '","' ||excess_qty_fg 
				|| '","' ||order_type_fg 
				|| '","' ||TO_CHAR(due_date_fg, 'DD-MON-YYYY') 
				|| '","' ||lot_number_fg 
				|| '","' ||TO_CHAR(psd_expiry_date_fg, 'DD-MON-YYYY') 
				|| '","' ||order_number_fg 
				|| '","' ||source_org_fg 
				|| '","' ||order_qty_fg
				|| '","' ||order_priority_fg --7/21/2015 AFlores
				|| '","' ||source_order_priority_fg --7/21/2015 AFlores
				|| '","' ||pegging_order_no_fg 
				|| '","' ||item_dd 
				|| '","' ||item_desc_dd 
				|| '","' ||org_code_dd 
				|| '","' ||org_desc_dd 
				|| '","' ||excess_qty_dd 
				|| '","' ||order_type_dd 
				|| '","' ||TO_CHAR(due_date_dd,'DD-MON-YYYY') 
				|| '","' ||lot_number_dd 
				|| '","' ||TO_CHAR(psd_expiry_date_dd, 'DD-MON-YYYY') 
				|| '","' ||order_number_dd 
				|| '","' ||source_org_dd 
				|| '","' ||order_qty_dd
				|| '","' ||order_priority_dd --7/21/2015 AFlores
				|| '","' ||source_order_priority_dd --7/21/2015 AFlores
				|| '","' ||pegging_order_no_dd||'"'  PEGGING_TABLE   
				FROM xxnbty_pegging_temp_tbl 
				WHERE pegging_type = 'SUPPLY' AND abs(request_id) = p_main_request_id;
				
		CURSOR c_gen_dem_peg_rep (p_main_request_id NUMBER)
		IS
		SELECT '"'||pegging_type
				|| '","' ||item_rm 
				|| '","' ||item_desc_rm 
				|| '","' ||org_code_rm 
				|| '","' ||org_desc_rm 
				|| '","' ||excess_qty_rm 
				|| '","' ||order_type_rm 
				|| '","' ||TO_CHAR(due_date_rm, 'DD-MON-YYYY') 
				|| '","' ||lot_number_rm 
				|| '","' ||TO_CHAR(psd_expiry_date_rm, 'DD-MON-YYYY') 
				|| '","' ||order_number_rm 
				|| '","' ||source_org_rm 
				|| '","' ||order_qty_rm 
				|| '","' ||order_priority_rm --7/21/2015 AFlores
				|| '","' ||pegging_order_no_rm 
				|| '","' ||item_bl 
				|| '","' ||item_desc_bl 
				|| '","' ||org_code_bl 
				|| '","' ||org_desc_bl 
				|| '","' ||excess_qty_bl 
				|| '","' ||order_type_bl 
				|| '","' ||TO_CHAR(due_date_bl, 'DD-MON-YYYY') 
				|| '","' ||lot_number_bl 
				|| '","' ||TO_CHAR(psd_expiry_date_bl, 'DD-MON-YYYY') 
				|| '","' ||order_number_bl 
				|| '","' ||source_org_bl 
				|| '","' ||order_qty_bl 
				|| '","' ||order_priority_bl --7/21/2015 AFlores
				|| '","' ||pegging_order_no_bl 
				|| '","' ||item_bc 
				|| '","' ||item_desc_bc 
				|| '","' ||org_code_bc 
				|| '","' ||org_desc_bc 
				|| '","' ||excess_qty_bc 
				|| '","' ||order_type_bc 
				|| '","' ||TO_CHAR(due_date_bc, 'DD-MON-YYYY') 
				|| '","' ||lot_number_bc 
				|| '","' ||TO_CHAR(psd_expiry_date_bc, 'DD-MON_YYYY') 
				|| '","' ||order_number_bc 
				|| '","' ||source_org_bc 
				|| '","' ||order_qty_bc 
				|| '","' ||order_priority_bc --7/21/2015 AFlores
				|| '","' ||pegging_order_no_bc 
				|| '","' ||item_fg 
				|| '","' ||item_desc_fg 
				|| '","' ||org_code_fg 
				|| '","' ||org_desc_fg 
				|| '","' ||excess_qty_fg 
				|| '","' ||order_type_fg 
				|| '","' ||TO_CHAR(due_date_fg, 'DD-MON-YYYY') 
				|| '","' ||lot_number_fg 
				|| '","' ||TO_CHAR(psd_expiry_date_fg, 'DD-MON-YYYY') 
				|| '","' ||order_number_fg 
				|| '","' ||source_org_fg 
				|| '","' ||order_qty_fg
				|| '","' ||order_priority_fg --7/21/2015 AFlores
				|| '","' ||source_order_priority_fg --7/21/2015 AFlores
				|| '","' ||pegging_order_no_fg 
				|| '","' ||item_dd 
				|| '","' ||item_desc_dd 
				|| '","' ||org_code_dd 
				|| '","' ||org_desc_dd 
				|| '","' ||excess_qty_dd 
				|| '","' ||order_type_dd 
				|| '","' ||TO_CHAR(due_date_dd,'DD-MON-YYYY') 
				|| '","' ||lot_number_dd 
				|| '","' ||TO_CHAR(psd_expiry_date_dd, 'DD-MON-YYYY') 
				|| '","' ||order_number_dd 
				|| '","' ||source_org_dd 
				|| '","' ||order_qty_dd
				|| '","' ||order_priority_dd --7/21/2015 AFlores
				|| '","' ||source_order_priority_dd --7/21/2015 AFlores
				|| '","' ||pegging_order_no_dd||'"'  PEGGING_TABLE     
				FROM xxnbty_pegging_temp_tbl 
				WHERE pegging_type = 'DEMAND' AND abs(request_id) = p_main_request_id;		
	
	TYPE sup_tab_type		   IS TABLE OF c_gen_sup_peg_rep%ROWTYPE;
	TYPE dem_tab_type		   IS TABLE OF c_gen_dem_peg_rep%ROWTYPE;
	  
	l_peg_sup_rep_tab	   	   sup_tab_type; 
	l_peg_dem_rep_tab	   	   dem_tab_type; 
	v_step          		   NUMBER;
	v_mess          		   VARCHAR2(500);
	 
   BEGIN
	v_step := 1;						
	FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'PARAMETERS');
	FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Plan Name,Organization Code,ICC,Planner Code,Purchased Flag,Item Name, From Date, To Date');
	FND_FILE.PUT_LINE(FND_FILE.OUTPUT, p_plan_name ||','||p_org_code||','||p_catalog_group||','||p_planner_code||','||p_purchased_flag||','||p_item_name||','||p_main_from_date||','||p_main_to_date);
	FND_FILE.PUT_LINE(FND_FILE.OUTPUT,' , , , , , ,Raw Material, , , , , , , , , , , , ,Blend, , , , , , , , , , , , ,Bulk/Component, , , , , , , , , , , , ,Finished Good, , , , , , , , , , , , ,Deals & Display, , , , , , ');
	FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Pegging Type,Item,Item Description,Org Code,Org Description,Excess Quantity,Order Type,Due Date,Lot Number,Lot Expiry Date,Order Number,Source Org,Order Quantity, Order Priority,Pegging Order Number,Item,Item Description,Org Code,Org Description,Excess Quantity,Order Type,Due Date,Lot Number,Lot Expiry Date,Order Number,Source Org,Order Quantity, Order Priority,Pegging Order Number,Item,Item Description,Org Code,Org Description,Excess Quantity,Order Type,Due Date,Lot Number,Lot Expiry Date,Order Number,Source Org,Order Quantity, Order Priority,Pegging Order Number,Item,Item Description,Org Code,Org Description,Excess Quantity,Order Type,Due Date,Lot Number,Lot Expiry Date,Order Number,Source Org,Order Quantity, Order Priority, Source Order Priority,Pegging Order Number,Item,Item Description,Org Code,Org Description,Excess Quantity,Order Type,Due Date,Lot Number,Lot Expiry Date,Order Number,Source Org,Order Quantity, Order Priority, Source Order Priority,Pegging Order Number');
	v_step := 2;	
	IF p_pegging_type = 'SUPPLY' THEN
		OPEN c_gen_sup_peg_rep(p_request_id);
		FETCH c_gen_sup_peg_rep BULK COLLECT INTO l_peg_sup_rep_tab;
		FOR i in 1..l_peg_sup_rep_tab.COUNT
			LOOP
				FND_FILE.PUT_LINE(FND_FILE.OUTPUT, l_peg_sup_rep_tab(i).PEGGING_TABLE );
			END LOOP;
		CLOSE c_gen_sup_peg_rep;
	v_step := 3;
	ELSIF p_pegging_type = 'DEMAND' THEN
		OPEN c_gen_dem_peg_rep(p_request_id);
		FETCH c_gen_dem_peg_rep BULK COLLECT INTO l_peg_dem_rep_tab;
		FOR i in 1..l_peg_dem_rep_tab.COUNT
			LOOP
				FND_FILE.PUT_LINE(FND_FILE.OUTPUT, l_peg_dem_rep_tab(i).PEGGING_TABLE );
			END LOOP;
		CLOSE c_gen_dem_peg_rep;
	v_step := 4;
	ELSE
		OPEN c_gen_sup_peg_rep(p_request_id);
		FETCH c_gen_sup_peg_rep BULK COLLECT INTO l_peg_sup_rep_tab;
		FOR i in 1..l_peg_sup_rep_tab.COUNT
			LOOP
				FND_FILE.PUT_LINE(FND_FILE.OUTPUT, l_peg_sup_rep_tab(i).PEGGING_TABLE );
			END LOOP;
		CLOSE c_gen_sup_peg_rep;
	v_step := 5;	
		OPEN c_gen_dem_peg_rep(p_request_id);
		FETCH c_gen_dem_peg_rep BULK COLLECT INTO l_peg_dem_rep_tab;
		FOR i in 1..l_peg_dem_rep_tab.COUNT
			LOOP
				FND_FILE.PUT_LINE(FND_FILE.OUTPUT, l_peg_dem_rep_tab(i).PEGGING_TABLE );
			END LOOP;
		CLOSE c_gen_dem_peg_rep;
	END IF;
	v_step := 6;	
	EXCEPTION
		WHEN OTHERS THEN
		  v_mess := 'At step ['||v_step||'] - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
		  errbuf  := v_mess;
		  retcode := 2; 

    END generate_pegging_csv_log;
	
	--Procedure to call the concurrent of generation of pegging report in .csv
	PROCEDURE generate_pegging_csv_report ( errbuf   		 OUT VARCHAR2
											  ,retcode  		 OUT NUMBER
											  ,x_request_id	  	 OUT NUMBER
											  ,p_plan_name       msc_orders_v.compile_designator%TYPE
											  ,p_org_code        msc_orders_v.organization_code%TYPE
											  ,p_catalog_group	 VARCHAR2
											  ,p_planner_code	 msc_orders_v.planner_code%TYPE
											  ,p_purchased_flag  msc_orders_v.purchasing_enabled_flag%TYPE
											  ,p_item_name		 msc_orders_v.item_segments%TYPE
											  ,p_main_from_date	 VARCHAR2
											  ,p_main_to_date	 VARCHAR2
											  ,p_pegging_type    VARCHAR2)
											
	IS
		--x_request_id 		NUMBER;
		ln_wait             BOOLEAN;
		lc_phase            VARCHAR2(100)   := NULL;
		lc_status           VARCHAR2(30)    := NULL;
		lc_devphase         VARCHAR2(100)   := NULL;
		lc_devstatus        VARCHAR2(100)   := NULL;
		lc_mesg             VARCHAR2(50)    := NULL;
		
	BEGIN

		x_request_id := FND_REQUEST.SUBMIT_REQUEST(application  => 'XXNBTY'
													,program      => 'XXNBTY_MSC_REP01_GEN_CSV_REP'
													,start_time   => NULL
													,sub_request  => FALSE
													,argument1    => p_plan_name      
													,argument2    => p_org_code       
													,argument3    => p_catalog_group	
													,argument4    => p_planner_code	
													,argument5    => p_purchased_flag 
													,argument6    => p_item_name		
													,argument7    => p_main_from_date	
													,argument8    => p_main_to_date	
													,argument9    => p_pegging_type	
													,argument10   => g_request_id
													);
													
		FND_CONCURRENT.AF_COMMIT;
		
		ln_wait := fnd_concurrent.wait_for_request( request_id      => x_request_id
												  , interval        => 30
												  , max_wait        => ''
												  , phase           => lc_phase
												  , status          => lc_status
												  , dev_phase       => lc_devphase
												  , dev_status      => lc_devstatus
												  , message         => lc_mesg
												  );
		FND_CONCURRENT.AF_COMMIT;
		
		--check for the report completion
		IF (lc_devphase = 'COMPLETE' AND lc_devstatus = 'NORMAL') THEN 
		  FND_FILE.PUT_LINE(FND_FILE.LOG,'Concurrent program for generating of pegging report has completed successfully'); 
		  FND_FILE.PUT_LINE(FND_FILE.LOG,'Request ID of XXNBTY Supply Pegging Report is ' || x_request_id); 
		ELSE
		  FND_FILE.PUT_LINE(FND_FILE.LOG,'Generating Supply pegging report for '|| x_request_id || ' failed.' );   
		END IF;
	EXCEPTION
	WHEN OTHERS THEN
		retcode := 2;
	    errbuf := SQLERRM;
        FND_FILE.PUT_LINE(FND_FILE.LOG,'Error message : ' || errbuf);	
	
	END generate_pegging_csv_report;
	
	--Procedure that will send Supply pegging report to the user
	PROCEDURE generate_pegging_email (errbuf   		 OUT VARCHAR2
							         ,retcode  		 OUT NUMBER
							         ,p_request_id	 NUMBER
							         ,pegging_type	 VARCHAR2
									 ,p_email_ad	 VARCHAR2)
								
	IS
		
    --cursor to get the email address of the current user(for sending of email)
    CURSOR c_email_ad 
    IS
       SELECT email_address
        FROM fnd_user
       WHERE email_address IS NOT NULL
         AND user_id = g_last_updated_by;
            
	l_request_id    NUMBER;
	lp_email_to     VARCHAR2(1000);
	l_old_filename  VARCHAR2(200);
	l_new_filename	VARCHAR2(200);
	l_subject		VARCHAR2(1000);
	l_message		VARCHAR2(1000);		
			
	v_step          NUMBER;
	v_mess          VARCHAR2(500);
	e_error         EXCEPTION;				
			
    BEGIN
		v_step := 1;
		--get output file after report generation.
		SELECT outfile_name
		INTO l_old_filename
		FROM fnd_concurrent_requests
		WHERE request_id = p_request_id;
		v_step := 2;
		/*
		--retrieve email add of the user_id
		OPEN c_email_ad;
		FETCH c_email_ad INTO lp_email_to;
		CLOSE c_email_ad;
		*/
		lp_email_to := p_email_ad;
		v_step := 3;
		--File Name of the CSV for Pegging Report
		l_new_filename := 'XXNBTY_MULTI_PEGGING_REPORT_' ||g_request_id|| '.csv';
		v_step := 4;
		--Email Subject
		l_subject := 'Multilevel Pegging Report';
		v_step := 5;
		--Email Message
		l_message := 'Attached is the Multilevel Pegging Report for Request ID: '||g_request_id;
		v_step := 6;
		IF lp_email_to IS NULL THEN
		  FND_FILE.PUT_LINE(FND_FILE.LOG,'Cannot proceed in sending email due the user has no email address registered in FND_USER.');
		ELSE --send email if recipient is valid.
		--get request id generated after running concurrent program
		l_request_id := FND_REQUEST.SUBMIT_REQUEST(application  => 'XXNBTY'
												   ,program      => 'XXNBTY_VCP_SEND_EMAIL_LOG'   
												   ,start_time   => NULL
												   ,sub_request  => FALSE
												   ,argument1    => l_new_filename
												   ,argument2    => l_old_filename
												   ,argument3    => lp_email_to
												   ,argument4    => NULL
												   ,argument5    => NULL
												   ,argument6    => l_subject
												   ,argument7    => l_message
												   );
		FND_CONCURRENT.AF_COMMIT;
		END IF; 
		v_step := 7;
												   
		IF l_request_id != 0 THEN 
		  FND_FILE.PUT_LINE(FND_FILE.LOG,'Sending successful.');  
		v_step := 8;
		ELSE
		  FND_FILE.PUT_LINE(FND_FILE.LOG,'Error in sending email.'); 
		v_step := 9;
		END IF;
		v_step := 10;
		
	EXCEPTION
	
		WHEN e_error THEN
		FND_FILE.PUT_LINE(FND_FILE.LOG, 'Return errbuf [' || errbuf || ']' );
		retcode := retcode;
		
			WHEN OTHERS THEN
			  v_mess := 'At step ['||v_step||'] for procedure generate_email(SUPPLY) - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
			  errbuf  := v_mess;
			  retcode := 2; 
			  FND_FILE.PUT_LINE(FND_FILE.LOG,'Error message : ' || v_mess);	
			  
    END generate_pegging_email;
    --ADDED 7/15/2015 AFLORES
	--END                                  	
END XXNBTY_MSCREP01_MULTI_PEGG_PKG;

/

show errors;
