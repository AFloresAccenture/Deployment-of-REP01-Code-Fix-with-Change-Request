create or replace PACKAGE BODY       XXNBTY_MSCREP01_PEGG_DEM_PKG
/*
Package Name	: XXNBTY_MSCREP01_PEGG_DEM_PKG
Author's name	: Albert John Flores
Date written	: 24-APR-2015
RICEFW Object id: 
Description		: Package that will generate multi-pegging report details.
Program Style	:  

Maintenance History:
Date 		   Issue# 			    Name 				                  Remarks
-----------   -------- 				---- 				            ------------------------------------------
24-APR-2015							Albert John Flores				Initial Draft
14-JUL-2015						    Albert John Flores				Added who columns for xxnbty_dem_peg_id_tbl
15-JUL-2015						    Albert John Flores				Added 2 procedures due to OPP issues(REPORT AS CSV)
21-JUL-2015	  Change Request	    Albert John Flores				Added the additional columns and printing functions for the change request
13-AUG-2015							Albert John Flores				Fix for the issues encountered in prod
*/
----------------------------------------------------------------------
IS

	--PROCEDURE to populate temp table of xxnbty_dem_peg_id_tbl
	PROCEDURE xxnbty_populate_peg_id_tbl(  errbuf             OUT VARCHAR2
										, retcode            OUT NUMBER
										, p_plan_id 		 IN NUMBER
										, p_item_segments 	 IN VARCHAR2
										, p_item_id 		 IN NUMBER
										, p_org_code 		 IN VARCHAR2 
										, p_organization_id  IN NUMBER 
										, p_category_instant IN NUMBER 
										, p_order_num 		 IN VARCHAR2
										)
	IS
	CURSOR c_peg_id ( p_category_instant  NUMBER
								  , p_plan_id           msc_orders_v.plan_id%TYPE
								  , p_org_code          msc_orders_v.organization_code%TYPE
								  , p_item_segments     msc_orders_v.item_segments%TYPE
								  , p_organization_id   msc_orders_v.organization_id%TYPE
								  , p_item_id           msc_orders_v.inventory_item_id%TYPE
								  , p_order_num			msc_orders_v.order_number%TYPE)
	IS	
		 SELECT  mfsdv.pegging_id pegging_id, g_request_id request_id, SYSDATE creation_date, g_created_by created_by, SYSDATE last_update_date, g_last_updated_by last_updated_by --added who columns for xxnbty_dem_peg_id_tbl 7/14/2015 AFLORES 
		  FROM    msc_orders_v mov 
				 ,msc_trading_partners mtp 
				 ,msc_plans mp 
				 ,xxnbty_catalog_staging_tbl xcst 
				 ,msc_flp_supply_demand_v3 mfsdv 
		 WHERE   mov.organization_code       = mtp.organization_code 
		 AND     mov.item_segments           = xcst.item_name 
		 AND     xcst.organization_id        = mtp.sr_tp_id 
		 AND     mov.plan_id                 = mp.plan_id 
		 AND     mov.compile_designator      = mp.compile_designator 
		 AND 	 mfsdv.demand_id    		 = mov.transaction_id 
		 AND     mfsdv.plan_id               = mov.plan_id 
		 AND     mfsdv.organization_id       = mov.organization_id 
		 AND     mfsdv.item_id               = mov.inventory_item_id 
		 AND     mfsdv.sr_instance_id        = mov.sr_instance_id 
		 AND 	 mov.category_set_id      	 = p_category_instant 
		 AND 	 mov.plan_id              	 = p_plan_id 
		 AND 	 mov.organization_code    	 = p_org_code
		 AND 	 mov.item_segments        	 = p_item_segments 
		 AND 	 mov.transaction_id       	 IN (SELECT mfp.demand_id
											 FROM msc_full_pegging mfp
											 WHERE mfp.plan_id           = mov.plan_id
											 AND   mfp.organization_id   = p_organization_id
											 AND   mfp.inventory_item_id = p_item_id
											 AND  TO_CHAR( mfp.transaction_id)	 = p_order_num)
		 AND	 TO_CHAR(mfsdv.transaction_id)		 = p_order_num;	
	
    TYPE peg_tab_type		   IS TABLE OF c_peg_id%ROWTYPE;
	  
	l_peg_ids		    peg_tab_type;
    v_step          	NUMBER;
    v_mess          	VARCHAR2(500);
	
	BEGIN
	v_step := 1;
	DELETE FROM xxnbty_dem_peg_id_tbl
	WHERE request_id = g_request_id;
	COMMIT;
	v_step := 2;	

		OPEN c_peg_id (p_category_instant  
					  , p_plan_id  
					  , p_org_code  
					  , p_item_segments   
					  , p_organization_id   
					  , p_item_id
					  , p_order_num);
	v_step := 3;				  
		LOOP			  
			FETCH c_peg_id BULK COLLECT INTO l_peg_ids LIMIT c_limit;
			IF l_peg_ids.FIRST IS NOT NULL THEN
				FORALL i IN 1..l_peg_ids.COUNT
				  INSERT /*+APPEND*/ INTO xxnbty_dem_peg_id_tbl VALUES l_peg_ids(i);      
				  COMMIT;			
				EXIT WHEN c_peg_id%NOTFOUND;
			END IF;
		END LOOP;
		CLOSE c_peg_id;
	v_step := 4;	
	
	EXCEPTION
		WHEN OTHERS THEN
		  v_mess := 'At step ['||v_step||'] for procedure xxnbty_populate_peg_id_tbl(DEMAND) - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
		  FND_FILE.PUT_LINE(FND_FILE.LOG, 'When others v_mess ['|| v_mess ||']');  
		  errbuf  := v_mess;
		  retcode := 2; 
			
	END xxnbty_populate_peg_id_tbl;  

	--Function xxnbty_get_pegging_id
	FUNCTION xxnbty_get_pegging_id( p_plan_id 		   IN NUMBER
								  , p_item_segments    IN VARCHAR2
								  , p_item_id 		   IN NUMBER
								  , p_org_code 		   IN VARCHAR2 
								  , p_organization_id  IN NUMBER 
								  , p_category_instant IN NUMBER 
								  , p_order_num 	   IN VARCHAR2
								  )  RETURN VARCHAR2 IS  
	l_all_peg_id 	VARCHAR2(4000);
	
	CURSOR c_peg_id ( p_category_instant  NUMBER
								  , p_plan_id           msc_orders_v.plan_id%TYPE
								  , p_org_code          msc_orders_v.organization_code%TYPE
								  , p_item_segments     msc_orders_v.item_segments%TYPE
								  , p_organization_id   msc_orders_v.organization_id%TYPE
								  , p_item_id           msc_orders_v.inventory_item_id%TYPE
								  , p_order_num			msc_orders_v.order_number%TYPE)
	IS	
	  SELECT mfsdv.pegging_id                   
	  FROM    msc_orders_v mov 
			 ,msc_trading_partners mtp 
			 ,msc_plans mp 
			 ,xxnbty_catalog_staging_tbl xcst 
			 ,msc_flp_supply_demand_v3 mfsdv 
	 WHERE   mov.organization_code       = mtp.organization_code 
	 AND     mov.item_segments           = xcst.item_name 
	 AND     xcst.organization_id        = mtp.sr_tp_id 
	 AND     mov.plan_id                 = mp.plan_id 
	 AND     mov.compile_designator      = mp.compile_designator 
	 AND 	 mfsdv.demand_id    		 = mov.transaction_id 
	 AND     mfsdv.plan_id               = mov.plan_id 
	 AND     mfsdv.organization_id       = mov.organization_id 
	 AND     mfsdv.item_id               = mov.inventory_item_id 
	 AND     mfsdv.sr_instance_id        = mov.sr_instance_id 
	 AND 	 mov.category_set_id      	 = p_category_instant 
	 AND 	 mov.plan_id              	 = p_plan_id 
	 AND 	 mov.organization_code    	 = p_org_code
	 AND 	 mov.item_segments        	 = p_item_segments 
	 AND 	 mov.transaction_id       	 IN (SELECT mfp.demand_id
                                         FROM msc_full_pegging mfp
                                         WHERE mfp.plan_id           = mov.plan_id
                                         AND   mfp.organization_id   = p_organization_id
                                         AND   mfp.inventory_item_id = p_item_id
										 AND   TO_CHAR(mfp.transaction_id)	 = p_order_num) --FIX 8/13/2015 Albert Flores
	 AND	 TO_CHAR(mfsdv.transaction_id)		    = p_order_num;							--FIX 8/13/2015 Albert Flores
										 
		  	  
    TYPE peg_tab_type		   IS TABLE OF c_peg_id%ROWTYPE;
	  
	l_peg_ids		   		   peg_tab_type; 									 
	
	BEGIN 
	  --FND_FILE.PUT_LINE(FND_FILE.LOG, 'Start of  xxnbty_get_pegging_id. Start time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');
	l_all_peg_id := NULL;
	
	  OPEN c_peg_id ( p_category_instant  
									  , p_plan_id  
									  , p_org_code  
									  , p_item_segments   
									  , p_organization_id   
									  , p_item_id
					  , p_order_num);
	  --FETCH c_peg_id BULK COLLECT INTO l_peg_ids; --FIX 8/13/2015 Albert Flores
	  FETCH c_peg_id INTO l_all_peg_id;
	  CLOSE c_peg_id;
		--START FIX 8/13/2015 Albert Flores
		/*FOR i IN 1..l_peg_ids.COUNT
			LOOP
		
				l_all_peg_id := l_all_peg_id || l_peg_ids(i).pegging_id || ',';
		  
			END LOOP;		
		*/
		--END FIX 8/13/2015 Albert Flores
	  RETURN l_all_peg_id;
	  --FND_FILE.PUT_LINE(FND_FILE.LOG, 'End of  xxnbty_get_pegging_id. End time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');
	  EXCEPTION
	  WHEN OTHERS THEN
	  --for debugging
	  FND_FILE.PUT_LINE(FND_FILE.LOG, 'When others v_mess ['|| SQLCODE|| '] - ' ||substr(SQLERRM,1,100) ||']');  
	  RETURN NULL;

  END;
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
                     ,p_main_to_date	 VARCHAR2)
	IS
	  l_err_msg		    VARCHAR(100);
      l_from_date 		DATE := TO_DATE (p_main_from_date, 'YYYY/MM/DD HH24:MI:SS');
      l_to_date   		DATE := TO_DATE (p_main_to_date, 'YYYY/MM/DD HH24:MI:SS');
	  v_request_id		NUMBER;
	  v_step          	NUMBER;
	  v_mess          	VARCHAR2(500);
	
	e_error           EXCEPTION;
	BEGIN
		--FND_FILE.PUT_LINE(FND_FILE.LOG, 'Start of  main_pr. Start time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');
		--define last updated by and created by
		g_last_updated_by := fnd_global.user_id;
		g_created_by      := fnd_global.user_id;	 
		g_request_id	  := fnd_global.conc_request_id; 
		
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
		IF l_err_msg IS NULL THEN --proceed if all parameters are valid     
			
			--delete from the temp table 7/11/2015 AFlores
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
		v_step := 3;
		  IF retcode != 0 THEN
			RAISE e_error;
		  END IF;
		  /*
			--call concurrent program for xml publisher		   
			generate_pegging_report( errbuf   
								,retcode   
								,g_request_id
								,p_plan_name
								,p_org_code
								,p_catalog_group
								,p_planner_code
								,p_purchased_flag
								,p_item_name
								,p_main_from_date
								,p_main_to_date); 	
		  IF retcode != 0 THEN
			RAISE e_error;
		  END IF;
		
		    --ADDED 7/15/2015
		    --call concurrent program to generate the report in csv file
		    generate_supply_pegging_report ( errbuf   		
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
									    ,'DEMAND');
									 
		    IF retcode != 0 THEN
			RAISE e_error;
		    END IF;	
		v_step := 4;
			generate_pegging_email (errbuf  
								,retcode
								,v_request_id
								,'DEMAND');
					   
			IF retcode != 0 THEN		   
	        RAISE e_error;
	        END IF;				
		v_step := 5;
		*/
		ELSE --display error encountered
		  FND_FILE.PUT_LINE(FND_FILE.LOG, l_err_msg);
		  retcode := 2;
		  errbuf  := l_err_msg;
		  RAISE e_error;
		  
		END IF;
		--FND_FILE.PUT_LINE(FND_FILE.LOG, 'End of  main_pr. End time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');
		EXCEPTION
		  WHEN e_error THEN
			FND_FILE.PUT_LINE(FND_FILE.LOG, 'Return errbuf [' || errbuf || ']' );
			retcode := retcode;
			
				WHEN OTHERS THEN
				  v_mess := 'At step ['||v_step||'] for procedure main_pr(DEMAND) - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
				  FND_FILE.PUT_LINE(FND_FILE.LOG, 'When others v_mess ['|| v_mess ||']');  
				  errbuf  := v_mess;
				  retcode := 2;
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
	CURSOR c_rep_root(p_category_set_id	 NUMBER
					  ,p_plan_name			VARCHAR2
					  ,p_org_code			VARCHAR2
					  ,p_catalog_group		VARCHAR2
					  ,p_planner_code		VARCHAR2
					  ,p_purchased_flag		msc_orders_v.purchasing_enabled_flag%TYPE
					  ,p_item_name			VARCHAR2
					  ,p_from_date			DATE
					  ,p_to_date			DATE)	 IS
		SELECT   mov.item_segments item 
                 ,mov.description item_description 
                 ,mov.organization_code org_code 
                 ,mtp.partner_name org_description 
                 ,0 excess_qty 
                 ,mov.order_type_text order_type 
                 ,mov.new_due_date due_date 
                 ,mov.order_number order_number  
                 ,mov.quantity_rate order_quantity  
				 ,mov.demand_priority order_priority 			 --7/21/2015 AFlores
				 ,mov.source_dmd_priority source_order_priority  --7/21/2015 AFlores
                 ,NULL pegging_order_no 
                 ,mov.lot_number lot_number  
                 ,mov.expiration_date psd_expiry_date  
                 ,mov.source_organization_code source_org  
                 ,xcst.icc catalog_group
                 ,NULL 
                 ,NULL 
                 ,mov.plan_id 
                 ,mov.organization_id 
                 ,mov.inventory_item_id 
                 ,mov.sr_instance_id 
                 ,mov.transaction_id 
               FROM     msc_orders_v mov  
                       ,msc_trading_partners mtp  
                       ,msc_plans mp 
					   ,xxnbty_catalog_staging_tbl xcst 
               WHERE   mov.organization_code       = mtp.organization_code 
               AND     mov.item_segments           = xcst.item_name  
               AND     xcst.organization_id        = mtp.sr_tp_id  
               AND     mov.plan_id                 = mp.plan_id 
               AND     mov.compile_designator      = mp.compile_designator 
               AND     mov.source_table            = 'MSC_SUPPLIES' 
               AND     mov.category_set_id         = p_category_set_id
               AND     mp.plan_run_date IS NOT NULL 
               AND     mov.new_due_date IS NOT NULL 
               AND     mov.compile_designator      = p_plan_name 
               AND     mov.organization_code       = p_org_code
               AND     xcst.icc			           = NVL(p_catalog_group, xcst.icc) 
               AND     mov.planner_code            = NVL(p_planner_code, mov.planner_code) 
               AND     mov.purchasing_enabled_flag = NVL(p_purchased_flag, mov.purchasing_enabled_flag) 
               AND     xcst.item_name              = NVL(p_item_name, xcst.item_name) 
               AND     TRUNC(mov.new_due_date)    BETWEEN p_from_date AND p_to_date
			   AND 	   mov.order_type_text		   = 'Planned order';
		
		
    l_rep_root      icc_tab_type;
	l_query	        VARCHAR2(4000);
	
	v_step          NUMBER;
	v_mess          VARCHAR2(500);	
    e_error         EXCEPTION;
	BEGIN
		v_step := 1;
		--FND_FILE.PUT_LINE(FND_FILE.LOG, 'Start of  get_root_rep. Start time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');
		v_step := 2;
		
		OPEN c_rep_root( ctgry_id_constant	
						,p_plan_name		
						,p_org_code		
						,p_catalog_group	
						,p_planner_code	
						,p_purchased_flag	
						,p_item_name		
						,p_from_date		
						,p_to_date	);
						
		v_step := 4;
	    LOOP --loop_c_rep_root 
	    FETCH c_rep_root BULK COLLECT INTO l_rep_root LIMIT c_limit; 
		v_step := 5;
		  FOR i IN 1..l_rep_root.COUNT
		  LOOP --loop_inside_loop_c_rep_root	  
			 --7/11/2015 AFlores
			 g_rm_index_ctr   := 0;
			 g_bl_index_ctr   := 0;
			 g_bc_index_ctr   := 0;
			 g_fg_index_ctr   := 0;
			 g_dd_index_ctr   := 0;
		  
			 collect_rep( errbuf
			 ,retcode
			 ,l_rep_root(i));
			 
			 IF retcode != 0 THEN
			  RAISE e_error;
			 END IF;
	  
		   --get pegging report of current root record
			 get_pegging_details( errbuf
								 ,retcode
								 ,l_rep_root(i)
								 ,p_from_date
								 ,p_to_date);
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
			
		  END LOOP;--loop_inside_loop_c_rep_root
		v_step := 6;  
		/* 7/11/2015 AFlores
		  --dump collected records in temp table
		  populate_temp_table( errbuf
							  ,retcode
							  ,g_temp_rec); 
		 v_step := 7;                     

		  g_temp_rec.DELETE;   
		*/
		EXIT WHEN c_rep_root%NOTFOUND; 
		v_step := 8;
	    END LOOP; --loop_c_rep_root 
	    CLOSE c_rep_root;  
		v_step := 9;
		--FND_FILE.PUT_LINE(FND_FILE.LOG, 'End of get_root_rep. End time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');
		EXCEPTION
		  WHEN e_error THEN
			FND_FILE.PUT_LINE(FND_FILE.LOG, 'Return errbuf [' || errbuf || ']' );
			retcode := retcode;
	  
		  WHEN OTHERS THEN
		  v_mess := 'At step ['||v_step||'] for procedure get_root_rep(DEMAND) - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
		  FND_FILE.PUT_LINE(FND_FILE.LOG, 'When others v_mess ['|| v_mess ||']');  
		  errbuf  := v_mess;
		  retcode := 2; 
	END get_root_rep;
   
   --procedure that will retrieve pegging report of root record
   PROCEDURE get_pegging_details( errbuf        OUT VARCHAR2
                                 ,retcode       OUT NUMBER
                                 ,p_pegging_rec icc_type
                                 ,p_from_date   VARCHAR2
                                 ,p_to_date     VARCHAR2)
   IS
   CURSOR c_rep_order (p_category_set_id	NUMBER
					  ,p_plan_id			NUMBER
					  ,p_instance_id		NUMBER
					  ,p_order_number		VARCHAR2
					  ,p_pegging_id			NUMBER)
	IS
		SELECT  mov.item_segments item , 
				mov.description item_description , 
				mov.organization_code org_code , 
				mtp.partner_name org_description , 
				DECODE(SIGN(mfsdv.demand_id), -1, mfsdv.pegged_qty, 0) excess_qty , 
				mov.order_type_text order_type , 
				mov.new_due_date due_date , 
				mov.order_number order_number , 
				mfsdv.pegged_qty order_quantity , 
				mov.demand_priority order_priority 	,			--7/21/2015 AFlores
				mov.source_dmd_priority source_order_priority , --7/21/2015 AFlores
				NULL pegging_order_no , 
				mov.lot_number lot_number , 
				mov.expiration_date psd_expiry_date , 
				mov.source_organization_code source_org , 
				--xcst.icc catalog_group , 
				XXNBTY_MSCREP01_MULTI_PEGG_PKG.xxnbty_get_catalog_fn(mov.item_segments,mtp.sr_tp_id)catalog_group,
				mfsdv.pegging_id ,  --TO BE PASSED TO PLANNED ORDER DEMAND
				mfsdv.prev_pegging_id ,  --NEEDED FOR IDENTIFIER OF PLANNED ORDER
				mov.plan_id , 
				mov.organization_id , 
				mov.inventory_item_id , 
				mov.sr_instance_id , 
				mov.transaction_id 
		FROM 	msc_orders_v mov , 
				msc_trading_partners mtp , 
				msc_plans mp , 
				--xxnbty_catalog_staging_tbl xcst , 
				msc_flp_supply_demand_v3 mfsdv 
		WHERE 	mov.organization_code = mtp.organization_code 
		--AND 	mov.item_segments       = xcst.item_name 
		--AND 	xcst.organization_id    = mtp.sr_tp_id 
		AND 	mov.plan_id             = mp.plan_id 
		AND 	mov.compile_designator  = mp.compile_designator 
		--AND 	mov.order_number        = TO_CHAR(mov.transaction_id) 		   --FIX 8/14/2015 Aflores
		AND 	TO_CHAR(mov.disposition_id)      = TO_CHAR(mov.transaction_id) --FIX 8/14/2015 Aflores
		AND 	mfsdv.plan_id           = mov.plan_id 
		AND 	mfsdv.item_id           = mov.inventory_item_id 
		AND 	mfsdv.sr_instance_id    = mov.sr_instance_id 
		AND 	mov.category_set_id     = p_category_set_id 
		AND 	mov.plan_id             = p_plan_id 
		--	AND 	mov.item_segments       = :3 --REMOVED FOR DETAILS ISSUE
		AND 	mov.sr_instance_id      = p_instance_id 
		--AND 	mov.order_number        = p_order_number 					  --FIX 8/14/2015 Aflores
		AND 	TO_CHAR(mov.disposition_id)      = TO_CHAR(p_order_number) 	  --FIX 8/14/2015 Aflores
		AND 	mfsdv.pegging_id        = p_pegging_id; 
   
	  c_rep_root2	           SYS_REFCURSOR;  
	  c_rep_demand 		   	   SYS_REFCURSOR; 
      l_pegging_rep  		   icc_tab_type;
      l_current_peg  		   icc_tab_type;
      l_orig_query	 		   VARCHAR2(32000);
      l_peg_query    		   VARCHAR2(32000);
      l_pegging_ids  		   VARCHAR2(32000);
      l_plan_id      		   NUMBER;	  
	  v_step          		   NUMBER;
	  v_mess          		   VARCHAR2(500);	 
      e_error           	   EXCEPTION;
	  --FIX 8/13/2015 Albert Flores
	  TYPE 	peg_tab_type 	IS TABLE OF xxnbty_dem_peg_id_tbl%ROWTYPE;
	  v_tab_peg				peg_tab_type := peg_tab_type();
	  ln_ctr				NUMBER := 0;
	  
   BEGIN
	  v_step := 1;
	  --FND_FILE.PUT_LINE(FND_FILE.LOG, 'Start of  get_pegging_details. Start time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');
	  v_step := 2;		
      l_pegging_ids := XXNBTY_MSCREP01_PEGG_DEM_PKG.xxnbty_get_pegging_id( p_pegging_rec.plan_id , p_pegging_rec.item , p_pegging_rec.item_id , p_pegging_rec.org_code , p_pegging_rec.org_id , ctgry_id_constant , p_pegging_rec.order_number);   
	  
	  xxnbty_populate_peg_id_tbl( errbuf
							, retcode
							, p_pegging_rec.plan_id 
							, p_pegging_rec.item 
							, p_pegging_rec.item_id 
							, p_pegging_rec.org_code 
							, p_pegging_rec.org_id 
							, ctgry_id_constant 
							, p_pegging_rec.order_number);  
      
      l_pegging_ids := RTRIM(l_pegging_ids, ',');   
	  
      l_peg_query := NULL; --clear dynamic query 
      --l_pegging_rep.DELETE; --clear collection
      v_step := 3;
      l_plan_id := p_pegging_rec.plan_id; 
	  IF l_pegging_ids IS NOT NULL THEN  
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
                            --||'  ,sub2.order_number pegging_order_no '
							||'  ,mfsdv.transaction_id pegging_order_no '
                            ||'  ,mov.lot_number lot_number '
                            ||'  ,mov.expiration_date psd_expiry_date '
                            ||'  ,mov.source_organization_code source_org '
							||'  ,XXNBTY_MSCREP01_MULTI_PEGG_PKG.xxnbty_get_catalog_fn(mov.item_segments,mtp.sr_tp_id)catalog_group ' 
                            ||'  ,mfsdv.pegging_id '
							||'  ,mfsdv.prev_pegging_id '
                            ||'  ,mov.plan_id '
                            ||'  ,mov.organization_id '
                            ||'  ,mov.inventory_item_id '
                            ||'  ,mov.sr_instance_id '
                            ||'  ,mfsdv.transaction_id '
                     ||' FROM     msc_orders_v mov '
                            ||'  ,msc_trading_partners mtp '
                            ||'  ,msc_plans mp '
                            /*06/25/2015
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
							||'		AND   mov2.category_set_id    = '|| ctgry_id_constant ||') sub2 '*/
                            ||'  ,msc_flp_supply_demand_v3 mfsdv '
							||'  ,xxnbty_dem_peg_id_tbl dpit ' --joined temp table
                    ||'  WHERE   mov.organization_code       = mtp.organization_code '
                    ||'  AND     mov.plan_id                 = mp.plan_id '
                    ||'  AND     mov.compile_designator      = mp.compile_designator '
                    ||'  AND     mfsdv.plan_id               = mov.plan_id '
                    ||'  AND     mfsdv.organization_id       = mov.organization_id '
                    ||'  AND     mfsdv.item_id               = mov.inventory_item_id '
                    ||'  AND     mfsdv.sr_instance_id        = mov.sr_instance_id '
					||'  AND 	 mfsdv.demand_id    	 	 = mov.transaction_id '
					||'  AND     mfsdv.pegging_id 		     = dpit.pegging_id ' 		--where clause joining the temp table
					||'  AND     dpit.request_id 		     = ' || g_request_id || ' ' --where clause joining the temp table 
                    ||'  AND     mov.source_table            = ''MSC_DEMANDS'' '
					--||'  AND     sub2.pegging_id 		     = mfsdv.pegging_id '
					--||'  AND 	 sub2.order_number       	 = TO_CHAR(mfsdv.transaction_id) '
					||'  AND 	 mov.category_set_id         = ' || ctgry_id_constant || ' '
					||'  AND 	 mov.plan_id                 = '|| l_plan_id ||' '
					--||'  AND 	 mfsdv.pegging_id   IN (' || l_pegging_ids  || ') ' 
					||'  ORDER BY mfsdv.pegging_id desc';
		 v_step := 4;
       OPEN c_rep_demand FOR l_peg_query; 
		 v_step := 5;
		 LOOP --loop_c_rep_demand 
			 FETCH c_rep_demand BULK COLLECT INTO l_current_peg LIMIT c_limit; 
				
			 v_step := 6; 
				 l_peg_query := NULL; --clear dynamic query
				 l_pegging_ids := NULL; --clear collected pegging id
				 --FIX 8/13/2015 Albert Flores
				 /*
				 --delete from the staging table
				 	DELETE FROM xxnbty_dem_peg_id_tbl
					WHERE request_id = g_request_id;
					COMMIT; 
				*/	
				 FOR k IN 1..l_current_peg.COUNT			 
				 LOOP --loop_FOR k IN 1..l_current_peg.COUNT		 
						
						collect_rep( errbuf
									,retcode
									,l_current_peg(k));
					  
						v_step := 7;
						--for planned order 
						v_step := 8;						
						OPEN c_rep_order ( ctgry_id_constant
										  ,l_current_peg(k).plan_id
										  --,l_current_peg(k).item REMOVED FOR DETAILS ISSUE
										  ,l_current_peg(k).sr_instance_id
										  ,l_current_peg(k).order_number
										  ,l_current_peg(k).prev_pegging_id);
					                    
						v_step := 9;
						LOOP --loop_c_rep_order								
							FETCH c_rep_order BULK COLLECT INTO l_pegging_rep LIMIT c_limit; 
								   
							v_step := 10;	
								--collect pegging ids for planned order demand  
								--l_pegging_ids := l_pegging_ids || l_current_peg(k).pegging_id || ',';		
								FOR j IN 1..l_pegging_rep.COUNT
								LOOP --loop_inside_c_rep_order
									v_step := 11;
									l_pegging_ids := l_pegging_ids || l_pegging_rep(j).pegging_id || ',';
									--START FIX 8/13/2015 Albert Flores
									/*
									--insert to table xxnbty_dem_peg_id_tbl
									INSERT INTO xxnbty_dem_peg_id_tbl(pegging_id, request_id, creation_date, created_by, last_update_date, last_updated_by) VALUES (l_pegging_rep(j).pegging_id, g_request_id, SYSDATE, g_created_by, SYSDATE, g_last_updated_by); --added who columns for xxnbty_dem_peg_id_tbl 7/14/2015 AFlores
									*/
									--v_tab_peg.EXTEND;
									ln_ctr := ln_ctr + 1;
									IF NOT v_tab_peg.EXISTS(ln_ctr) THEN
									   v_tab_peg.EXTEND;
									END IF;
									v_step := 11.5;
									v_tab_peg(ln_ctr).pegging_id	    := l_pegging_rep(j).pegging_id;
									v_tab_peg(ln_ctr).request_id        := g_request_id;
									v_tab_peg(ln_ctr).creation_date     := SYSDATE;
									v_tab_peg(ln_ctr).created_by        := g_created_by;
									v_tab_peg(ln_ctr).last_update_date  := SYSDATE;
									v_tab_peg(ln_ctr).last_updated_by   := g_last_updated_by;
									--END FIX 8/13/2015 Albert Flores
									l_pegging_rep(j).pegging_order_no := l_current_peg(k).order_number; 	
									   collect_rep( errbuf
												   ,retcode
												   ,l_pegging_rep(j));
								END LOOP;
								--COMMIT; --7/14/2015 Albert Flores
								v_step := 12;
							EXIT WHEN c_rep_order%NOTFOUND; 
							v_step := 13;
						END LOOP; --loop_c_rep_order 
						CLOSE c_rep_order; 
					 v_step := 14;		
				END LOOP; --loop_FOR k IN 1..l_current_peg.COUNT
				l_pegging_ids := RTRIM(l_pegging_ids, ',');
				 
				 --EXIT WHEN l_pegging_ids IS NULL;
			 v_step := 15;
			 EXIT WHEN c_rep_demand%NOTFOUND;
		  END LOOP; --loop_c_rep_demand 
		  CLOSE c_rep_demand;
		  v_step := 16;
		--START FIX 8/13/2015 Albert Flores
		DELETE FROM xxnbty_dem_peg_id_tbl
		WHERE request_id = g_request_id;
		
		FORALL i IN 1..v_tab_peg.COUNT
		INSERT INTO xxnbty_dem_peg_id_tbl VALUES v_tab_peg(i);
		
		ln_ctr := 0;
		v_tab_peg.DELETE;
		
		COMMIT; 
		--END FIX 8/13/2015 Albert Flores
	    EXIT WHEN l_pegging_ids IS NULL;
	    END LOOP; --loop_planned_order_demand
	    v_step := 17; 
	  
		l_peg_query := NULL; --clear dynamic query
		l_pegging_rep.DELETE; --clear collection 
      
      END IF;
      v_step := 18; 
	  --FND_FILE.PUT_LINE(FND_FILE.LOG, 'End of  get_pegging_details. End time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');
	  EXCEPTION
	  WHEN OTHERS THEN
	    v_mess := 'At step ['||v_step||'] for procedure get_pegging_details(DEMAND) - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
	    FND_FILE.PUT_LINE(FND_FILE.LOG, 'When others v_mess ['|| v_mess ||']');  
	    errbuf  := v_mess;
	    retcode := 2;  
        
   END get_pegging_details;
	
	--procedure that will re-assign records to designated icc type
	PROCEDURE collect_rep ( errbuf   OUT VARCHAR2
                          ,retcode  OUT NUMBER
                          ,p_icc	       icc_type)
	IS
	  v_step          NUMBER;
	  v_mess          VARCHAR2(500);	
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
		 g_temp_rec(g_rm_index_ctr).last_update_date       := SYSDATE;
		 g_temp_rec(g_rm_index_ctr).last_updated_by        := g_last_updated_by;
		 g_temp_rec(g_rm_index_ctr).last_update_login      := g_last_updated_by;
		 g_temp_rec(g_rm_index_ctr).creation_date          := SYSDATE;
		 g_temp_rec(g_rm_index_ctr).created_by             := g_created_by;
		 g_temp_rec(g_rm_index_ctr).request_id             := g_request_id;
		 g_temp_rec(g_rm_index_ctr).pegging_id             := p_icc.pegging_id;
		 g_temp_rec(g_rm_index_ctr).pegging_type           :='DEMAND';   
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
		 g_temp_rec(g_bl_index_ctr).last_update_date       := SYSDATE;
		 g_temp_rec(g_bl_index_ctr).last_updated_by        := g_last_updated_by;
		 g_temp_rec(g_bl_index_ctr).last_update_login      := g_last_updated_by;
		 g_temp_rec(g_bl_index_ctr).creation_date          := SYSDATE;
		 g_temp_rec(g_bl_index_ctr).created_by             := g_created_by;
		 g_temp_rec(g_bl_index_ctr).request_id             := g_request_id;
		 g_temp_rec(g_bl_index_ctr).pegging_id             := p_icc.pegging_id;
		 g_temp_rec(g_bl_index_ctr).pegging_type           :='DEMAND';
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
		 g_temp_rec(g_bc_index_ctr).last_update_date       := SYSDATE;
		 g_temp_rec(g_bc_index_ctr).last_updated_by        := g_last_updated_by;
		 g_temp_rec(g_bc_index_ctr).last_update_login      := g_last_updated_by;
		 g_temp_rec(g_bc_index_ctr).creation_date          := SYSDATE;
		 g_temp_rec(g_bc_index_ctr).created_by             := g_created_by;
		 g_temp_rec(g_bc_index_ctr).request_id             := g_request_id;	
		 g_temp_rec(g_bc_index_ctr).pegging_id             := p_icc.pegging_id;
		 g_temp_rec(g_bc_index_ctr).pegging_type           :='DEMAND';	
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
		 g_temp_rec(g_fg_index_ctr).last_update_date       := SYSDATE;
		 g_temp_rec(g_fg_index_ctr).last_updated_by        := g_last_updated_by;
		 g_temp_rec(g_fg_index_ctr).last_update_login      := g_last_updated_by;
		 g_temp_rec(g_fg_index_ctr).creation_date          := SYSDATE;
		 g_temp_rec(g_fg_index_ctr).created_by             := g_created_by;
		 g_temp_rec(g_fg_index_ctr).request_id             := g_request_id;	
		 g_temp_rec(g_fg_index_ctr).pegging_id             := p_icc.pegging_id;
		 g_temp_rec(g_fg_index_ctr).pegging_type           :='DEMAND';	
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
		 g_temp_rec(g_dd_index_ctr).last_update_date       := SYSDATE;
		 g_temp_rec(g_dd_index_ctr).last_updated_by        := g_last_updated_by;
		 g_temp_rec(g_dd_index_ctr).last_update_login      := g_last_updated_by;
		 g_temp_rec(g_dd_index_ctr).creation_date          := SYSDATE;
		 g_temp_rec(g_dd_index_ctr).created_by             := g_created_by;
		 g_temp_rec(g_dd_index_ctr).request_id             := g_request_id;	
		 g_temp_rec(g_dd_index_ctr).pegging_id             := p_icc.pegging_id;
		 g_temp_rec(g_dd_index_ctr).pegging_type           :='DEMAND';
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
    --FND_FILE.PUT_LINE(FND_FILE.LOG, 'End of  collect_rep. End time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');  
	EXCEPTION
			WHEN OTHERS THEN
			  v_mess := 'At step ['||v_step||'] for procedure collect_rep(DEMAND) - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
			  FND_FILE.PUT_LINE(FND_FILE.LOG, 'When others v_mess ['|| v_mess ||']');  
			  errbuf  := v_mess;
			  retcode := 2; 	
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
      --delete old records
	  /* 7/22/2015 AFlores
      DELETE FROM xxnbty_pegging_temp_tbl
      WHERE (TRUNC(SYSDATE) - TO_DATE(creation_date)) > 5;
      COMMIT; 
	  */
	v_step := 2;  
      --insert new records 

      FORALL i IN 1..p_temp_tab.COUNT	  
      INSERT /*+APPEND*/ INTO xxnbty_pegging_temp_tbl VALUES p_temp_tab(i); 
      COMMIT;
	v_step := 3;  
	--FND_FILE.PUT_LINE(FND_FILE.LOG, 'End of  populate_temp_table. End time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');
	EXCEPTION
			WHEN OTHERS THEN
			  v_mess := 'At step ['||v_step||'] for procedure populate_temp_table(DEMAND) - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
			  FND_FILE.PUT_LINE(FND_FILE.LOG, 'When others v_mess ['|| v_mess ||']');  
			  errbuf  := v_mess;
			  retcode := 2;  
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
									  ,p_main_to_date	 VARCHAR2)
    IS
	    r_request_id  NUMBER;
	    l_flag1        BOOLEAN;
	    l_flag2        BOOLEAN;
	
	BEGIN
	--FND_FILE.PUT_LINE(FND_FILE.LOG, 'Start of  generate_pegging_report. Start time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');
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
                                               ,start_time   => NULL 
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
    --FND_FILE.PUT_LINE(FND_FILE.LOG, 'End of  generate_pegging_report. End time:[' || TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS') || ']');
    EXCEPTION
    WHEN OTHERS THEN
      retcode := 2;
      errbuf := SQLERRM;
    
  END generate_pegging_report;  
  /*
	--Procedure to call the concurrent of generation of pegging report in .csv
	PROCEDURE generate_demand_pegging_report ( errbuf   		 OUT VARCHAR2
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
		  FND_FILE.PUT_LINE(FND_FILE.LOG,'Concurrent program for generating of demand pegging report has completed successfully'); 
		  FND_FILE.PUT_LINE(FND_FILE.LOG,'Request ID of XXNBTY Demand Pegging Report is ' || x_request_id); 
		ELSE
		  FND_FILE.PUT_LINE(FND_FILE.LOG,'Generating demand pegging report for '|| x_request_id || ' failed.' );   
		END IF;
	EXCEPTION
	WHEN OTHERS THEN
		retcode := 2;
	    errbuf := SQLERRM;
        FND_FILE.PUT_LINE(FND_FILE.LOG,'Error message : ' || errbuf);	
	
	END generate_demand_pegging_report;
	
	--Procedure that will send Supply pegging report to the user
	PROCEDURE generate_pegging_email (errbuf   		 OUT VARCHAR2
							         ,retcode  		 OUT NUMBER
							         ,p_request_id	 NUMBER
							         ,pegging_type	 VARCHAR2)
								
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
		--retrieve email add of the user_id
		OPEN c_email_ad;
		FETCH c_email_ad INTO lp_email_to;
		CLOSE c_email_ad;
		v_step := 3;
		--File Name of the CSV for Demand Pegging Report
		l_new_filename := 'XXNBTY_DEMAND_PEGGING_REPORT_' ||g_request_id|| '.csv';
		v_step := 4;
		--Email Subject
		l_subject := 'Multilevel Pegging Report for Demand';
		v_step := 5;
		--Email Message
		l_message := 'Attached is the Demand Pegging Report for Request ID: '||g_request_id;
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
	*/
END XXNBTY_MSCREP01_PEGG_DEM_PKG;

/

show errors;
