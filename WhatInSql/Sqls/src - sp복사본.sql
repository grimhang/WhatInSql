/*      
 * Program ID   : SCP0045_GET_SHIPMENT_REQUEST      
 * Description  : Shipment Request 조회      
 * Program History      
 *===================================================================================================      
 *   Date		In Charge	Description      
 *===================================================================================================      
 * 2019/08/26	hwyoon		Initial Release [PJ20170278] 전지본부 자동차 GSCM(DM/SCP) 구축 프로젝트      
 * 2019/10/31	hwyoon		BOH(STOCK_V) 조회 시 FORMATION_CHECK_PACKAGING 재고 포함
 * 2019/12/19	hwyoon		'SCP Plan' Measure 조회 시 Final Plan을 조회하도록 설정
 * 2020/01/03	hwyoon		Requestor 조회 시 Last Updated By 가 scp_batch인 것은 제외
 * 2020/04/21	hwyoon		조회쿼리 속도 개선 : scm_dnm_stock_v BOH 조회부분.
 * 2020/10/20   khj79       [C20201016-000147] 소형 SSP Daily Rolling을 위한 법인간 거래 일자별 출하 요청 화면 생성
 * 2020/11/03   khj79       [C20201016-000147] BOH 추가 수정
 * 2021/07/07   khj79		[PJ20209643] LGES Digital SCM Level.3 달성을 위한 개선 (Phase.2) - BOD 2단계 개발 : FROM,TO 추가 , scp_mst_bod_v=> scp_mst_bod_n_v
 * 2021/10/05	khj79	    [PJ20209643] LGES Digital SCM Level.3 달성을 위한 개선 (Phase.3) - W/S AS UI 변경
 */      
CREATE PROCEDURE [dbo].[SCP0045_GET_SHIPMENT_REQUEST]
	@p_division_id			NVARCHAR(50),
	@p_operation_group		NVARCHAR(50),
	@p_scm_site_id			NVARCHAR(MAX),
	@p_item_id				NVARCHAR(MAX)='',
	@p_from_yyyymmdd		NVARCHAR(8),
	@p_to_yyyymmdd			NVARCHAR(8),
	@p_program_id			NVARCHAR(300),
	@p_sheet_name			NVARCHAR(150),
	@p_user_id				NVARCHAR(300)='',
	@debug_mode				NVARCHAR(1)='F'
AS      
BEGIN      
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	declare @p_stock_yyyymmdd NVARCHAR(8);

	SET @p_stock_yyyymmdd = CONVERT(CHAR(8), DATEADD(DD, -3, CONVERT(VARCHAR, @p_from_yyyymmdd, 121)), 112); --FROM -3일

	DECLARE @v_division_id			NVARCHAR(50) = @p_division_id
	DECLARE @v_operation_group			NVARCHAR(50) = @p_operation_group
	DECLARE @v_from_yyyymmdd			NVARCHAR(8) = @p_from_yyyymmdd


	/********************************************************************************
	* 임시테이블만들기
	********************************************************************************/
    -- SCP Plan용
	IF OBJECT_ID('tempdb..#TblDynamic_PLAN') IS NOT NULL	
		DROP TABLE #TblDynamic_PLAN;

	-- SHIP Req용
	IF OBJECT_ID('tempdb..#TblDynamic_SHIP_REQ') IS NOT NULL	
		DROP TABLE #TblDynamic_SHIP_REQ;

	-- PIVOT 용
	IF OBJECT_ID('tempdb..#TblDynamic_SHIP_PIVOT') IS NOT NULL	
		DROP TABLE #TblDynamic_SHIP_PIVOT;

	-- ROW DATA 용
	IF OBJECT_ID('tempdb..#TblDynamic_SHIP_ROW') IS NOT NULL	
		DROP TABLE #TblDynamic_SHIP_ROW;

	-- Requestor
	IF OBJECT_ID('tempdb..#TblDynamic_REQUESTOR') IS NOT NULL	
		DROP TABLE #TblDynamic_REQUESTOR;

	-- BOH 계산용
	IF OBJECT_ID('tempdb..#TblDynamic_CAL_QTY') IS NOT NULL	
		DROP TABLE #TblDynamic_CAL_QTY;

	-- 필터용
	IF OBJECT_ID('tempdb..#TblDynamic_filter') IS NOT NULL	
		DROP TABLE #TblDynamic_filter;

	-- STOCK INV 조회용
	IF OBJECT_ID('tempdb..#STOCK') IS NOT NULL	
		DROP TABLE #STOCK;

	-- [C20201016-000147] : 소형(40) 사업부 기준 테이블
	IF OBJECT_ID('tempdb..#TblDynamic_SCP0045_40_STD') IS NOT NULL	
		DROP TABLE #TblDynamic_SCP0045_40_STD;



	CREATE TABLE #TblDynamic_PLAN (
		DIVISION_ID		NVARCHAR(30)	
		,ITEM_ID		NVARCHAR(50)
		,FROM_SITE		NVARCHAR(30)
		,TO_SITE		NVARCHAR(30)
		,TR_MODE		NVARCHAR(50)
		,INCOTERMS		NVARCHAR(10)
		,BOD_ID			NVARCHAR(20)	-- BOD 2단계 개발
		,MEASURE		NVARCHAR(50)
		,YYYYMMDD		NVARCHAR(8)
		,QTY			NUMERIC(20,10)
		,SEQ			INT
	);

	CREATE TABLE #TblDynamic_SHIP_ROW (
		DIVISION_ID		NVARCHAR(30)
		,ITEM_ID		NVARCHAR(50)
		,NICK_NAME		NVARCHAR(500)
		,FROM_SITE		NVARCHAR(30)
		,TO_SITE		NVARCHAR(30)
		,TR_MODE		NVARCHAR(50)
		,INCOTERMS		NVARCHAR(10)
		,BOD_ID			NVARCHAR(20)	-- BOD 2단계 개발
		,LT_DAY			NVARCHAR(50)
		,MEASURE		NVARCHAR(50)
		,YYYYMMDD		NVARCHAR(8)
		,QTY			NUMERIC(20,10)
		,SEQ			INT
	);

	CREATE TABLE #TblDynamic_CAL_QTY (
		DIVISION_ID		NVARCHAR(30)	
		,ITEM_ID		NVARCHAR(50)
		,NICK_NAME		NVARCHAR(500)
		,FROM_SITE		NVARCHAR(30)
		,YYYYMMDD		NVARCHAR(8)
		,PLAN_QTY		NUMERIC(20,10)
		,REQ_QTY		NUMERIC(20,10)
	);

	CREATE CLUSTERED INDEX [IX01_#TblDynamic_CAL_QTY] ON #TblDynamic_CAL_QTY            
            (            
             DIVISION_ID
			,ITEM_ID
			,FROM_SITE
			,YYYYMMDD
              );

	CREATE TABLE #TblDynamic_filter (
		DIVISION_ID		NVARCHAR(30)
		,ITEM_ID		NVARCHAR(50)
		,FROM_SITE		NVARCHAR(30)
	);

	PRINT '-------------START! : ' +  CONVERT(CHAR(23), getdate(), 21)

	-----------------------------------------------
	-- 1. SCP Plan : SCP(Weekly) plant향 Shipment Plan
	-----------------------------------------------
	INSERT INTO #TblDynamic_PLAN
	SELECT sp.division_id
		 , sp.item_id
		 , sp.from_site
		 , sp.to_site
		 , bod.transport_mode     AS tr_mode
		 , bod.incoterms          AS incoterms
		 , bod.bod_id			AS bod_id	-- BOD 2단계 개발
		 , 'SCP_PLAN'             AS measure
		 , sp.yyyymmdd
		 , sp.qty
		 , 1                     AS seq
	FROM   scp_anl_shipment_plan_semi sp WITH(NOLOCK)
	    INNER JOIN
        (
            SELECT division_id, plan_start_yyyymmdd, plan_type, plan_seq, plan_id, modeling_id, sort_seq
					, ROW_NUMBER() OVER (PARTITION BY division_id
											ORDER BY plan_start_yyyymmdd desc, sort_seq ASC, plan_seq DESC 
										) row_num 
            FROM  
            (
                SELECT division_id, plan_start_yyyymmdd, plan_type, plan_seq, plan_id, modeling_id
					, CASE WHEN plan_type = 'PR' THEN 4
							WHEN plan_type = 'MA' THEN 3
							WHEN plan_type = 'SE' THEN 2
							WHEN plan_type = 'FN' THEN 1
							ELSE 9
						END AS sort_seq
				FROM   scp_plan_version_v with(nolock)
				WHERE  1=1
				    AND    division_id          = @p_division_id -- 변수
				    AND    plan_cycle           = 'WEEKLY'
				    -- 191219 FN만 조회
				    --AND    plan_type       NOT IN ('TE', 'TM') 
				    AND    plan_type       ='FN'
				    AND    plan_start_yyyymmdd >= CONVERT(CHAR(8), DATEADD(DD, -14, dbo.FN_NEXT_DAY(GETDATE(), 'MON')), 112)
            ) a
        ) pv
		   ON  sp.division_id         = pv.division_id
		       AND sp.plan_start_yyyymmdd = pv.plan_start_yyyymmdd
		       AND sp.plan_type           = pv.plan_type
		       AND sp.seq                 = pv.plan_seq
		       AND pv.row_num             = 1
		       AND sp.measure             = 'SHIP_PLAN_AMEND'
		       AND sp.qty                 > 0
		       AND sp.operation_group	  = @p_operation_group
		       AND sp.yyyymmdd			  >= @p_from_yyyymmdd
		       AND sp.yyyymmdd			  <= @p_to_yyyymmdd
		       AND ( ( @p_scm_site_id IS NULL OR         @p_scm_site_id         ='' ) OR sp.from_site         IN (SELECT token FROM dbo.String_Split(@p_scm_site_id    ,',')) )
		       AND ( ( @p_item_id IS NULL OR         @p_item_id         ='' )	OR sp.item_id         IN (SELECT token FROM dbo.String_Split(@p_item_id    ,',')) )
	    -- BOD 2 단계 개발 : scp_mst_bod_v -> scp_mst_bod_n_v
	    INNER JOIN scp_mst_bod_n_v bod WITH(NOLOCK)	ON  sp.division_id = bod.division_id
												    AND sp.bod_id      = bod.bod_id
	    INNER JOIN SCM_MST_SITE FS with(nolock)		ON FS.DIVISION_ID=sp.division_id
												    AND FS.SCM_SITE_ID=sp.from_site
												    AND FS.VALID_YN='Y'
	    INNER JOIN SCM_MST_SITE TS with(nolock)		ON TS.DIVISION_ID=sp.division_id
												    AND TS.SCM_SITE_ID=sp.to_site
												    AND TS.VALID_YN='Y'
	WHERE 1=1
	    AND FS.PLANT_ID <> TS.PLANT_ID
	;

	PRINT '-------------SCP Plan : ' +  CONVERT(CHAR(23), getdate(), 21)

	-----------------------------------------------
	-- 2. Ship Plan : SSP(Daily) Plant향 Shipment Plan
	-----------------------------------------------
	INSERT INTO #TblDynamic_PLAN
	SELECT ssp.division_id
		 , ssp.item_id
		 , ssp.from_site
		 , ssp.to_site
		 , bod.transport_mode     AS tr_mode
		 , bod.incoterms          AS incoterms
		 , bod.bod_id			AS bod_id	-- BOD 2단계 개발
		 , 'SHIP_PLAN'            AS measure
		 , ssp.yyyymmdd
		 , ssp.qty
		 , 2                     AS seq
	FROM   ssp_anl_ship_confirm ssp WITH (NOLOCK)
			-- BOD 2 단계 개발 : scp_mst_bod_v -> scp_mst_bod_n_v
		   INNER JOIN scp_mst_bod_n_v bod WITH(NOLOCK)	ON  ssp.division_id = bod.division_id
														AND ssp.bod_id      = bod.bod_id
		   INNER JOIN scm_mst_site ts	ON  ssp.division_id = ts.division_id
										    AND ssp.to_site     = ts.scm_site_id
										    AND ts.site_type    = 'PLANT'  
										    AND ts.valid_yn     = 'Y'
		   INNER JOIN scm_mst_site fs	ON  ssp.division_id = fs.division_id
										    AND ssp.from_site     = fs.scm_site_id
										    AND fs.valid_yn     = 'Y'
	WHERE  1=1
	    AND	   ts.plant_id <> fs.plant_id
	    AND	   ssp.division_id  = @p_division_id -- 변수  
	    AND    ssp.qty         >  0
	    AND    ssp.yyyymmdd    >= @p_from_yyyymmdd
	    AND    ssp.yyyymmdd    <= @p_to_yyyymmdd
	    AND	   ssp.BIZ_TYPE = @p_operation_group
	    AND ( ( @p_scm_site_id IS NULL OR         @p_scm_site_id         ='' ) OR ssp.from_site         IN (SELECT token FROM dbo.String_Split(@p_scm_site_id    ,',')) )
	    AND ( ( @p_item_id IS NULL OR         @p_item_id         ='' )	OR ssp.item_id         IN (SELECT token FROM dbo.String_Split(@p_item_id    ,',')) )
	    AND    ssp.change_type  = 'C' 
	    ;

	PRINT '-------------SHIP Plan : ' +  CONVERT(CHAR(23), getdate(), 21)

	-----------------------------------------------
	-- 3. Ship Req : 출하 요청(Plant향 Ship Req)
	--               DM_PLN_SHIPMENT_REQ / MEASURE = 'SHIP_REQ'
	-----------------------------------------------
	SELECT r.division_id
			, r.item_id
			, r.plant_site_id        AS from_site
			, r.scm_site_id          AS to_site
			, r.transport_mode       AS tr_mode
			, r.incoterms            AS incoterms
			, r.bod_id				AS bod_id	-- BOD 2단계 개발
			, 'SHIP_REQ'             AS measure
			, r.yyyymmdd
			, r.qty
			, 3                     AS seq
			, r.last_updated_by
			, RANK() OVER(PARTITION BY r.DIVISION_ID, r.item_id, r.plant_site_id, r.scm_site_id, r.transport_mode, r.incoterms ORDER BY r.LAST_UPDATE_DATE desc) AS RN				 
			, CONVERT(CHAR(8), DATEADD(DD, isnull(fs.ship_frozen,0), CONVERT(VARCHAR, @p_from_yyyymmdd, 121)), 112) frozen_yyyymmdd -- Ship Frozen구간 다음일자
	INTO #TblDynamic_SHIP_REQ
	FROM   dm_pln_shipment_req r WITH(NOLOCK)
        INNER JOIN scm_mst_site fs	ON  r.division_id      = fs.division_id
							            AND r.plant_site_id    = fs.scm_site_id
							            AND fs.site_type       = 'PLANT'  
							            AND fs.operation_group = @p_operation_group--'A'
							            -- 2021.10.21 : W/S AS 수정 , OSP_YN 조건 제거
							            --AND fs.osp_yn          = 'N'
							            AND fs.valid_yn        = 'Y'	   
        INNER JOIN scm_mst_site ts	ON  r.division_id = ts.division_id
							            AND r.scm_site_id = ts.scm_site_id
							            AND ts.site_type  = 'PLANT'  
							            AND ts.valid_yn   = 'Y'
	WHERE  1=1
	    AND	   ts.plant_id <> fs.plant_id
	    AND    r.division_id      = @p_division_id -- 변수
	    AND    r.measure          = 'SHIP_REQ' -- 확정 후 수정할 것
	    AND    r.yyyymmdd        >= @p_from_yyyymmdd
	    AND    r.yyyymmdd        <= @p_to_yyyymmdd
	    AND    r.qty             >  0
	    AND ( ( @p_scm_site_id IS NULL OR         @p_scm_site_id         ='' ) OR r.plant_site_id         IN (SELECT token FROM dbo.String_Split(@p_scm_site_id    ,',')) )
	    AND ( ( @p_item_id IS NULL OR         @p_item_id         ='' )	OR r.item_id         IN (SELECT token FROM dbo.String_Split(@p_item_id    ,',')) )
	;
	
	PRINT '-------------SHIP Req : ' +  CONVERT(CHAR(23), getdate(), 21)
	
	--#TblDynamic_filter
	INSERT INTO #TblDynamic_filter
	SELECT DISTINCT A.DIVISION_ID, A.ITEM_ID, A.FROM_SITE
    FROM
    (
		SELECT DISTINCT DIVISION_ID, ITEM_ID, FROM_SITE
		FROM #TblDynamic_PLAN
		UNION 
		SELECT DISTINCT DIVISION_ID, ITEM_ID, FROM_SITE
		FROM #TblDynamic_SHIP_REQ
	) A

	PRINT '-------------filter : ' +  CONVERT(CHAR(23), getdate(), 21)


	-- [C20201016-000147] : 소형(40) 사업부 조회를 위한 기준 테이블 생성
	-- SSP_ANL_SHIP_PLAN_40 의 데이터 생성 시점이 달라 최신 생성 날짜를 조회한다.
	SELECT DISTINCT
	       DIVISION_ID
	     , FROM_SITE
		 , PLAN_START_YYYYMMDD
    INTO #TblDynamic_SCP0045_40_STD     -- 기준 데이터 저장
    FROM
    (
	    SELECT SP.DIVISION_ID
			    , SP.FROM_SITE
			    , SP.PLAN_START_YYYYMMDD
			    , RANK() OVER(PARTITION BY SP.FROM_SITE ORDER BY SP.PLAN_START_YYYYMMDD DESC) AS RANK
		FROM #TblDynamic_filter X1
		    INNER JOIN SSP_ANL_SHIP_PLAN_40 SP WITH(NOLOCK)
		        ON X1.DIVISION_ID = SP.DIVISION_ID
		            AND X1.FROM_SITE   = SP.FROM_SITE
		            AND X1.ITEM_ID     = SP.ITEM_ID
		WHERE SP.DIVISION_ID    = @p_division_id
		    AND SP.PLAN_START_YYYYMMDD >= CONVERT(VARCHAR(8) ,GETDATE() -1,112)  -- 전일
		    AND SP.PLAN_START_YYYYMMDD <= CONVERT(VARCHAR(8) ,GETDATE() ,112)    -- 당일
		    AND SP.MEASURE IN ( 'POSTP_PLAN','WH_IN','WH_STOCK' )
		    AND SP.YYYYMMDD        >= @p_from_yyyymmdd
		    AND SP.YYYYMMDD        <= @p_to_yyyymmdd
		    AND SP.QTY > 0
		    AND SP.DIVISION_ID = '40'
	    ) A
    WHERE RANK = 1
	;



	-- ROW DATA 생성
	INSERT INTO #TblDynamic_SHIP_ROW
	SELECT tot.division_id
		 , tot.item_id
		 , MAX(ISNULL(i.nick_name, ''))  AS NICK_NAME --NICK_NAME
		 , tot.from_site
		 , tot.to_site
		 , tot.tr_mode
		 , tot.incoterms
		 , bod.bod_id						AS BOD_ID	-- BOD 2단계 개발
		 , MAX(ISNULL(bod.lt_total, '')) AS LT_DAY
		 , tot.measure
		 , tot.yyyymmdd
		 , SUM(tot.qty)                  AS qty
		 , tot.seq
	FROM
    (

		-- 1.SCP PLAN & 2.SHIP PLAN 추가
		SELECT division_id
				, item_id
				, from_site
				, to_site
				, tr_mode
				, incoterms
				, bod_id		-- BOD 2단계 개발
				, measure
				, yyyymmdd
				, qty
				, seq
		FROM #TblDynamic_PLAN WITH(NOLOCK)

		UNION ALL

		-- 2.SHIP PLAN 추가 - Ship Frozen 이후 구간은 Ship Req의 수량을 더해준다.
		SELECT division_id
			 , item_id
			 , from_site
			 , to_site
			 , tr_mode
			 , incoterms
			 , bod_id		-- BOD 2단계 개발
			 , 'SHIP_PLAN' AS measure
			 , yyyymmdd
			 , qty
			 , 2                     AS seq
		FROM   #TblDynamic_SHIP_REQ WITH(NOLOCK)
		WHERE yyyymmdd >= frozen_yyyymmdd

		UNION ALL

		-- 3.SHIP REQ 추가
		SELECT division_id
			 , item_id
			 , from_site
			 , to_site
			 , tr_mode
			 , incoterms
			 , bod_id		-- BOD 2단계 개발
			 , measure
			 , yyyymmdd
			 , qty
			 , 3                     AS seq
		FROM   #TblDynamic_SHIP_REQ WITH(NOLOCK)

		-----------------------------------------------
		-- 4. Customer Plan : SSP(Daily) From Plant 기준 Sales향 Shipment Plan
		-----------------------------------------------

		UNION ALL

		SELECT ssp.division_id
			 , ssp.item_id
			 , ssp.from_site
			 , '-'                     AS to_site
			 , '-'                     AS tr_mode
			 , '-'                     AS incoterms
			 , '-'						AS bod_id	-- BOD 2단계 개발
			 , 'CUST_PLAN'        AS measure
			 , ssp.yyyymmdd
			 , ssp.qty
			 , 4                     AS seq
		FROM   ssp_anl_ship_confirm ssp WITH (NOLOCK)
		    -- BOD 2단계 개발 : scp_mst_bod_v -> scp_mst_bod_n_v
		    INNER JOIN scp_mst_bod_n_v bod	WITH(NOLOCK) ON ssp.division_id = bod.division_id
													     AND ssp.bod_id     = bod.bod_id
		    INNER JOIN scm_mst_site ts      ON  ssp.division_id = ts.division_id
										    AND ssp.to_site     = ts.scm_site_id
										    AND ts.site_type    = 'SALES'  
										    AND ts.valid_yn     = 'Y'
		    INNER JOIN #TblDynamic_filter f ON ssp.division_id = f.division_id
										    AND ssp.item_id	   = f.item_id
										    AND ssp.from_site  = f.from_site
		WHERE  ssp.division_id  = @p_division_id -- 변수  
		    AND    ssp.qty         >  0
		    AND    ssp.yyyymmdd    >= @p_from_yyyymmdd
		    AND    ssp.yyyymmdd    <= @p_to_yyyymmdd
		    AND	   ssp.biz_type		= @p_operation_group
		    AND ( ( @p_scm_site_id IS NULL OR         @p_scm_site_id         ='' ) OR ssp.from_site         IN (SELECT token FROM dbo.String_Split(@p_scm_site_id    ,',')) )
		    AND ( ( @p_item_id IS NULL OR         @p_item_id         ='' )	OR ssp.item_id         IN (SELECT token FROM dbo.String_Split(@p_item_id    ,',')) )
		    AND    ssp.change_type  = 'C' 

		-----------------------------------------------
		-- 5. Customer Req : 출하 요청(From Plant 기준 Sales향 Ship Req) 
		--                   DM_PLN_SHIPMENT_REQ / MEASURE = 'SHIP_REQ'
		-----------------------------------------------

		UNION ALL

		SELECT r.division_id
			 , r.item_id
			 , r.plant_site_id        AS from_site
			 , '-'                     AS to_site
			 , '-'                     AS tr_mode
			 , '-'                     AS incoterms
			 , '-'						AS bod_id	-- BOD 2단계 개발
			 , 'CUST_REQ'         AS measure
			 , r.yyyymmdd
			 , r.qty
			 , 5                     AS seq
		FROM   dm_pln_shipment_req r WITH(NOLOCK)
		    INNER JOIN scm_mst_site fs	ON  r.division_id      = fs.division_id
									    AND r.plant_site_id    = fs.scm_site_id
									    AND fs.site_type       = 'PLANT'  
									    AND fs.operation_group = @p_operation_group
									    -- 2021.10.21 : W/S AS 수정 , OSP_YN 조건 제거
									    --AND fs.osp_yn          = 'N'	   
									    AND fs.valid_yn        = 'Y'
		    INNER JOIN scm_mst_site ts	ON  r.division_id = ts.division_id
									    AND r.scm_site_id = ts.scm_site_id
									    AND ts.site_type  = 'SALES'  
									    AND ts.valid_yn   = 'Y'
		    INNER JOIN #TblDynamic_filter f ON r.division_id = f.division_id
										    AND r.item_id	   = f.item_id
										    AND r.plant_site_id  = f.from_site
		WHERE  1=1
		    AND    r.division_id      = @p_division_id
		    AND    r.measure          = 'SHIP_REQ'
		    AND    r.yyyymmdd        >= @p_from_yyyymmdd
		    AND    r.yyyymmdd        <= @p_to_yyyymmdd
		    AND ( ( @p_scm_site_id IS NULL OR         @p_scm_site_id         ='' ) OR r.plant_site_id         IN (SELECT token FROM dbo.String_Split(@p_scm_site_id    ,',')) )
		    AND ( ( @p_item_id IS NULL OR         @p_item_id         ='' )	OR r.item_id         IN (SELECT token FROM dbo.String_Split(@p_item_id    ,',')) )
		    AND    r.qty             >  0


		-----------------------------------------------
		-- 6. Internal movement
		-----------------------------------------------

		UNION ALL

		SELECT p.division_id
			 , p.item_id
			 , fs.scm_site_id                        AS from_site
			 , '-'                                    AS to_site
			 , '-'                                    AS tr_mode
			 , '-'                                    AS incoterms
			 , '-'										AS bod_id	-- BOD 2단계 개발
			 , 'INTN_MOVEMENT'                   AS measure
			 , CONVERT(VARCHAR(8), p.plan_date, 112) AS yyyymmdd
			 , p.qty
			 , 6                                    AS seq
		FROM   scm_dnm_cell_inhouse_plan_sn p WITH(NOLOCK)
		    INNER JOIN scm_mst_site fs	ON  p.division_id      = fs.division_id
									    AND p.plant_id         = fs.plant_id
									    AND fs.site_type       = 'PLANT'
									    AND fs.operation_group = @p_operation_group
									    -- 2021.10.21 : W/S AS 수정 , OSP_YN 조건 제거
									    --AND fs.osp_yn          = 'N'
									    AND fs.valid_yn        = 'Y'
		    INNER JOIN #TblDynamic_filter f ON p.division_id = f.division_id
										    AND p.item_id	   = f.item_id
										    AND fs.scm_site_id  = f.from_site
		WHERE  1=1
		    AND    p.division_id      = @p_division_id
		    AND    p.category         = 'MOVING'
		    AND    p.plan_date       >= @p_from_yyyymmdd
		    AND    p.plan_date       <= @p_to_yyyymmdd
		    AND ( ( @p_scm_site_id IS NULL OR         @p_scm_site_id         ='' ) OR fs.scm_site_id         IN (SELECT token FROM dbo.String_Split(@p_scm_site_id    ,',')) )
		    AND ( ( @p_item_id IS NULL OR         @p_item_id         ='' )	OR p.item_id         IN (SELECT token FROM dbo.String_Split(@p_item_id    ,',')) )
		    AND    p.qty             >  0
		    AND P.division_id <> '40'   -- [C20201016-000147] : 소형(40) 제외,KHJ79

		UNION ALL

		--[C20201016-000147] : 소형(40) 사업부 추가, KHJ79
		SELECT SP.DIVISION_ID
			 , SP.ITEM_ID
			 , SP.FROM_SITE
			 , SP.TO_SITE
			 , SP.TRANSPORT_MODE   AS TR_MODE
			 , SP.INCOTERMS
			 , SP.BOD_ID			-- BOD 2단계 개발
			 , 'INTN_MOVEMENT'     AS MEASURE
			, SP.YYYYMMDD
			, SP.QTY
			, 6     AS SEQ
		 FROM SSP_ANL_SHIP_PLAN_40 SP WITH(NOLOCK)

		    INNER JOIN SCM_MST_SITE FS
		       ON SP.DIVISION_ID	= FS.DIVISION_ID
		          AND SP.FROM_SITE      = FS.SCM_SITE_ID
		          AND FS.SITE_TYPE       = 'PLANT'
		      -- 2021.10.21 : W/S AS 수정 , OPERATION_GROUP 파라미터 처리 및 OSP_YN 조건 제거
		      --AND FS.OPERATION_GROUP = 'A'
		      --AND FS.OSP_YN          = 'N'
		      AND FS.OPERATION_GROUP = @v_operation_group
		      AND FS.VALID_YN        = 'Y'

		     INNER JOIN #TblDynamic_filter f 
		        ON SP.DIVISION_ID	= f.division_id
		       AND SP.ITEM_ID		= f.item_id
		       AND SP.FROM_SITE		= f.from_site

		     INNER JOIN #TblDynamic_SCP0045_40_STD ST
		        ON ST.DIVISION_ID = SP.DIVISION_ID
		       AND ST.FROM_SITE   = SP.FROM_SITE
		       AND ST.PLAN_START_YYYYMMDD = SP.PLAN_START_YYYYMMDD

		WHERE 1 = 1
            --AND SP.PLAN_START_YYYYMMDD = ST.PLAN_START_YYYYMMDD
            AND SP.MEASURE		= 'POSTP_PLAN'
            AND SP.DIVISION_ID    = @p_division_id
            AND SP.YYYYMMDD       >= @p_from_yyyymmdd
            AND SP.YYYYMMDD       <= @p_to_yyyymmdd
            AND (( @p_scm_site_id	IS NULL OR @p_scm_site_id ='' ) OR SP.FROM_SITE IN (SELECT token FROM dbo.String_Split(@p_scm_site_id ,',')))
            AND (( @p_item_id		IS NULL OR @p_item_id     ='' )	OR SP.item_id   IN (SELECT token FROM dbo.String_Split(@p_item_id		,',')))
            AND SP.qty            >  0
            AND SP.DIVISION_ID    = '40' -- 소형(40) 인 경우만 조회

		-----------------------------------------------
		-- 7. Inspection plan : FP 특성계획 
		-----------------------------------------------

		UNION ALL

		SELECT fp.division_id
			 , fp.item_id
			 , fp.scm_site_id                         AS from_site
			 , '-'                                     AS to_site
			 , '-'                                     AS tr_mode
			 , '-'                                     AS incoterms
			 , '-'										AS BOD_ID	-- BOD 2단계 개발
			 , 'INSP_PLAN'                      AS measure
			 , CONVERT(VARCHAR(8), fp.plan_date, 112) AS yyyymmdd
			 , fp.plan_qty                            AS qty
			 , 7                                     AS seq
		FROM   dbo.scm_dnm_plan_frozen_v fp WITH(NOLOCK)   
		    INNER JOIN scm_mst_site fs	ON  fp.division_id      = fs.division_id
									    AND fp.scm_site_id      = fs.scm_site_id
									    AND fs.site_type       = 'PLANT'
									    AND fs.operation_group = @p_operation_group
									    -- 2021.10.21 : W/S AS 수정 , OSP_YN 조건 제거
									    --AND fs.osp_yn          = 'N'
									    AND fs.valid_yn        = 'Y'
		    INNER JOIN #TblDynamic_filter f ON fp.division_id = f.division_id
										    AND fp.item_id	   = f.item_id
										    AND fp.scm_site_id  = f.from_site
		WHERE  fp.division_id  = @p_division_id
		    AND    fp.plan_date   >= @p_from_yyyymmdd
		    AND    fp.plan_date   <= @p_to_yyyymmdd
		    AND    fp.plan_qty     > 0 
		    AND    fp.plan_in_qty  > 0 
		    --   (참고) division_id <> '40' 일때는 'F6000' 데이터만 존재하므로 operation_id 조건에'F5300', 'F5500', 'F5600' 도 포함시켜도 상관없음                      
		    AND    fp.operation_id IN (SELECT segment1 AS operation_id 
									    FROM   scm_adm_lookup_master_detail WITH (NOLOCK)
									    WHERE  lookup_type = 'OPERATION_CHAR'
									    AND    valid_yn = 'Y'
								       )
		    AND ( ( @p_scm_site_id IS NULL OR         @p_scm_site_id         ='' ) OR fp.scm_site_id         IN (SELECT token FROM dbo.String_Split(@p_scm_site_id    ,',')) )
		    AND ( ( @p_item_id IS NULL OR         @p_item_id         ='' )	OR fp.item_id         IN (SELECT token FROM dbo.String_Split(@p_item_id    ,',')) )
		    AND fp.division_id <> '40'   -- C20201016-000147 : 소형(40) 제외,KHJ79

		UNION ALL

		--[C20201016-000147] : 소형(40) 사업부 추가, KHJ79
        SELECT SP.DIVISION_ID
		    , SP.ITEM_ID
		    , SP.FROM_SITE
		    , SP.TO_SITE
		    , SP.TRANSPORT_MODE   AS TR_MODE
		    , SP.INCOTERMS
		    , SP.BOD_ID			-- BOD 2단계 개발
		    , 'INSP_PLAN'         AS MEASURE
	        , SP.YYYYMMDD
	        , SP.QTY
	        , 7                    AS SEQ
	    FROM SSP_ANL_SHIP_PLAN_40 SP WITH(NOLOCK)

		    INNER JOIN SCM_MST_SITE FS
		        ON SP.DIVISION_ID	= FS.DIVISION_ID
		          AND SP.FROM_SITE      = FS.SCM_SITE_ID
		          AND FS.SITE_TYPE       = 'PLANT'
		          -- 2021.10.21 : W/S AS 수정 , OPERATION_GROUP 파라미터 처리 및 OSP_YN 조건 제거
		          --AND FS.OPERATION_GROUP = 'A'
		          --AND FS.OSP_YN          = 'N'
		          AND FS.OPERATION_GROUP = @v_operation_group
		          AND FS.VALID_YN        = 'Y'

            INNER JOIN #TblDynamic_filter f 
		        ON SP.DIVISION_ID	= f.division_id
		            AND SP.ITEM_ID		= f.item_id
		            AND SP.FROM_SITE		= f.from_site

		    INNER JOIN #TblDynamic_SCP0045_40_STD ST
		        ON ST.DIVISION_ID = SP.DIVISION_ID
		        AND ST.FROM_SITE   = SP.FROM_SITE
		        AND ST.PLAN_START_YYYYMMDD = SP.PLAN_START_YYYYMMDD

		 WHERE 1 = 1
		   --AND SP.PLAN_START_YYYYMMDD = CONVERT(VARCHAR(8),GETDATE() , 112) -- 당일(현재는 현재일 -1)
		   AND SP.MEASURE		= 'WH_IN'
		   AND SP.DIVISION_ID    = @p_division_id
		   AND SP.YYYYMMDD       >= @p_from_yyyymmdd
		   AND SP.YYYYMMDD       <= @p_to_yyyymmdd
		   AND (( @p_scm_site_id	IS NULL OR @p_scm_site_id ='' ) OR SP.FROM_SITE IN (SELECT token FROM dbo.String_Split(@p_scm_site_id ,',')))
		   AND (( @p_item_id		IS NULL OR @p_item_id     ='' )	OR SP.item_id     IN (SELECT token FROM dbo.String_Split(@p_item_id		,',')))
		   AND SP.qty            >  0
		   AND SP.DIVISION_ID    = '40' -- 소형(40) 인 경우만 조회

	) tot
	    -- BOD 2단계 개발 : scp_mst_bod_v -> scp_mst_bod_n_v
	    LEFT JOIN scp_mst_bod_n_v bod	WITH(NOLOCK) ON tot.division_id = bod.division_id
											     AND tot.from_site   = bod.from_site
											     AND tot.to_site     = bod.to_site
											     AND tot.tr_mode     = bod.transport_mode
											     AND bod.incoterms   = 'DAP' -- Semi 용 DAP 적용
											     AND tot.bod_id		 = bod.bod_id -- BOD 2단계 개발 : FROM , TO 조건 추가
	    LEFT JOIN
        (
            SELECT item_id, MAX(ISNULL(nick_name,'')) AS nick_name
			FROM   DBO.SCM_MST_ITEM_SN WITH(NOLOCK)
			WHERE  nick_name IS NOT NULL 
			GROUP BY item_id
        ) i ON  tot.item_id = i.item_id
	--GROUP BY tot.division_id, tot.item_id, tot.from_site, tot.to_site, tot.tr_mode, tot.incoterms, tot.measure, tot.yyyymmdd, tot.seq
	GROUP BY tot.division_id, tot.item_id, tot.from_site, tot.to_site, tot.tr_mode, tot.incoterms, tot.measure, tot.yyyymmdd, tot.seq , bod.bod_id  -- BOD 2단계 개발
	ORDER BY tot.division_id, tot.item_id, tot.from_site, tot.to_site DESC, tot.tr_mode, tot.incoterms, tot.seq
	;

	PRINT '-------------Row Data : ' +  CONVERT(CHAR(23), getdate(), 21)

	-- LT DAY 삭제
	UPDATE #TblDynamic_SHIP_ROW
	SET LT_DAY = '-'
	WHERE MEASURE IN ('CUST_PLAN','CUST_REQ','INTN_MOVEMENT','INSP_PLAN')
	;

	PRINT '-------------LT DAY : ' +  CONVERT(CHAR(23), getdate(), 21)


	-- BOH 계산용 MEASURE 추가(SHIP_REQ)
	/*
	INSERT INTO #TblDynamic_SHIP_ROW
	SELECT distinct A.division_id
			, A.item_id
			, A.NICK_NAME
			, A.from_site
			, A.to_site
			, A.tr_mode
			, A.incoterms
			, A.lt_day
			, M.measure
			, o.basis_yyyymmdd
			, NULL
			, M.seq
	FROM #TblDynamic_SHIP_ROW A WITH(NOLOCK)
		 CROSS APPLY (  SELECT basis_yyyymmdd 
								FROM scm_sys_calendar_m WITH(NOLOCK) 
								WHERE basis_yyyymmdd>=@p_from_yyyymmdd
								AND basis_yyyymmdd<=@p_to_yyyymmdd
								)  o
		CROSS APPLY (  SELECT COLUMN_NAME AS MEASURE
								,SORT_ORDER_NO AS SEQ
						FROM SCM_MST_SHEET_MEASURE WITH(NOLOCK)
						WHERE PROGRAM_ID=@p_program_id
						AND SHEET_NAME=@p_sheet_name
						AND COLUMN_NAME IN ('SHIP_REQ')
								)  M 
	WHERE 1=1
	and A.MEASURE IN ('SCP_PLAN','SHIP_PLAN','SHIP_REQ')
	AND NOT EXISTS (SELECT 'X' 
					FROM #TblDynamic_SHIP_ROW B 
					WHERE B.DIVISION_ID = A.DIVISION_ID
					AND B.ITEM_ID = A.ITEM_ID
					AND B.FROM_SITE = A.FROM_SITE
					AND B.TO_SITE = A.TO_SITE
					AND B.TR_MODE = A.TR_MODE
					AND B.INCOTERMS = A.INCOTERMS
					AND B.MEASURE = M.MEASURE
					AND B.YYYYMMDD = O.BASIS_YYYYMMDD
					)
	;

	PRINT '-------------MEASURE 1 : ' +  CONVERT(CHAR(23), getdate(), 21)


	-- BOH 계산용 MEASURE 추가(CUST_REQ)
	INSERT INTO #TblDynamic_SHIP_ROW
	SELECT distinct A.division_id
			, A.item_id
			, A.NICK_NAME
			, A.from_site
			, A.to_site
			, A.tr_mode
			, A.incoterms
			, A.lt_day
			, M.measure
			, o.basis_yyyymmdd
			, NULL
			, M.seq
	FROM #TblDynamic_SHIP_ROW A WITH(NOLOCK)
		 CROSS APPLY (  SELECT basis_yyyymmdd 
								FROM scm_sys_calendar_m WITH(NOLOCK) 
								WHERE basis_yyyymmdd>=@p_from_yyyymmdd
								AND basis_yyyymmdd<=@p_to_yyyymmdd
					)  o
		CROSS APPLY (  SELECT COLUMN_NAME AS MEASURE
								,SORT_ORDER_NO AS SEQ
						FROM SCM_MST_SHEET_MEASURE WITH(NOLOCK)
						WHERE PROGRAM_ID=@p_program_id
						AND SHEET_NAME=@p_sheet_name
						AND COLUMN_NAME IN ('CUST_REQ')
					)  M 
	WHERE 1=1
	and A.MEASURE IN ('CUST_PLAN','CUST_REQ','INTN_MOVEMENT','INSP_PLAN')
	AND NOT EXISTS (SELECT 'X' 
					FROM #TblDynamic_SHIP_ROW B 
					WHERE B.DIVISION_ID = A.DIVISION_ID
					AND B.ITEM_ID = A.ITEM_ID
					AND B.FROM_SITE = A.FROM_SITE
					AND B.TO_SITE = A.TO_SITE
					AND B.TR_MODE = A.TR_MODE
					AND B.INCOTERMS = A.INCOTERMS
					AND B.MEASURE = M.MEASURE
					AND B.YYYYMMDD = O.BASIS_YYYYMMDD
					)
	;

	PRINT '-------------MEASURE 2 : ' +  CONVERT(CHAR(23), getdate(), 21)
	;
	*/
	;
	/*
	SELECT  
		X.DIVISION_ID
		, X.ITEM_ID
		, X.FROM_SITE
		, X.YYYYMMDD
		, ISNULL( SUM(CASE  WHEN X.MEASURE= 'SHIP_PLAN'   THEN -1 * ISNULL(X.QTY,0)
									WHEN X.MEASURE= 'CUST_PLAN' THEN -1 * ISNULL(X.QTY,0)
									WHEN X.MEASURE= 'INTN_MOVEMENT' THEN -1 * ISNULL(X.QTY,0)
									WHEN X.MEASURE= 'INSP_PLAN' THEN ISNULL(X.QTY,0)
									ELSE 0.0  
			END),0)  AS PLAN_QTY
		, ISNULL( SUM(CASE  WHEN X.MEASURE= 'SHIP_REQ'   THEN -1 * ISNULL(X.QTY,0)
									WHEN X.MEASURE= 'CUST_REQ' THEN -1 * ISNULL(X.QTY,0)
									WHEN X.MEASURE= 'INTN_MOVEMENT' THEN -1 * ISNULL(X.QTY,0)
									WHEN X.MEASURE= 'INSP_PLAN' THEN ISNULL(X.QTY,0)
									ELSE 0.0  
			END),0) AS REQ_QTY
	INTO #TEST
	FROM #TblDynamic_SHIP_ROW X WITH(NOLOCK)   
	WHERE 1=1  
	AND X.MEASURE IN ( 'SHIP_PLAN', 'SHIP_REQ','CUST_PLAN', 'CUST_REQ', 'INTN_MOVEMENT', 'INSP_PLAN')
	GROUP BY X.DIVISION_ID, X.ITEM_ID, X.FROM_SITE, X.YYYYMMDD
	;

	PRINT '-------------TEST : ' +  CONVERT(CHAR(23), getdate(), 21)
	;
	*/

	SELECT inv.division_id
    		, inv.item_id
   			, inv.scm_site_id       AS from_site
  			, @p_from_yyyymmdd		AS yyyymmdd
  			, inv.ssp_qty           AS qty --SSP용
	INTO #STOCK
	FROM   scm_dnm_stock_v	inv WITH (NOLOCK)  
	    INNER JOIN 
        (
            SELECT division_id, site_id, max(cutoff_date) max_cutoff_date
			FROM   scm_dnm_stock_v WITH (NOLOCK)
			WHERE  division_id  = @v_division_id
				AND    cutoff_date >  @p_stock_yyyymmdd -- 현재일 - 3
				AND    cutoff_date <= @v_from_yyyymmdd -- 변수 : 현재일
			GROUP BY division_id, site_id
		) ms	
            ON   inv.division_id = ms.division_id 
				AND  inv.site_id     = ms.site_id
				AND	 inv.cutoff_date >  @p_stock_yyyymmdd
				AND  inv.cutoff_date = ms.max_cutoff_date
	    INNER JOIN
        (
            SELECT division_id, scm_site_id, operation_group, site_type
			FROM   scm_mst_site WITH (NOLOCK)
			WHERE  division_id     = @v_division_id
				AND    site_type       = 'PLANT' 
				AND    operation_group = @v_operation_group  -- Cell Plant Site
				AND    valid_yn        = 'Y'
        ) b		
            ON   inv.division_id = b.division_id 
			    AND  inv.scm_site_id = b.scm_site_id
	    INNER JOIN
        (
            SELECT DISTINCT
						a.storage_id
						,  a.location_code
						,  a.scm_site_id
						,  a.division_id
						,  a.OPERATION_ID
					FROM   scm_mst_location a WITH (NOLOCK)
						INNER JOIN (  SELECT scm_site_id  
										FROM   scm_mst_site
										WHERE  division_id     = @v_division_id
										AND    valid_yn        = 'Y'
										AND    operation_group = @v_operation_group  -- Cell Plant Site
									) b		ON a.scm_site_id = b.scm_site_id 
											WHERE  a.division_id = @v_division_id
											AND    a.valid_yn    = 'Y'
											-- 2019.10.31 BOH(STOCK_V) 조회 시 FORMATION_CHECK_PACKAGING 재고 포함
											AND    location_code IN ('CELL_OWMS','FORMATION_CHECK_PACKAGING') -- Cell 특성완료 이후 창고
											--AND    (storage_id IS NOT NULL AND storage_id <> '')
											AND (ISNULL(storage_id,'') <> '' OR ISNULL(OPERATION_ID,'') <> '')
        )  c -- 셀 storage_id 별 사용대상 조회
			ON   inv.division_id = c.division_id 
			    AND  inv.scm_site_id = c.scm_site_id  
			    --AND  inv.storage_id  = c.storage_id  
			    AND  (inv.storage_id  = c.storage_id OR inv.OPERATION_ID  = c.OPERATION_ID )
	WHERE '40' <> @v_division_id  -- [C20201016-000147] : 소형(40) 사업부 제외 ,khj79

	UNION ALL

	--[C20201016-000147] : 소형(40) 사업부 추가, khj79
	SELECT SP.DIVISION_ID
		, SP.ITEM_ID
		, SP.FROM_SITE
	    , SP.YYYYMMDD
	    , SP.QTY
	FROM SSP_ANL_SHIP_PLAN_40 SP WITH(NOLOCK)

	    INNER JOIN SCM_MST_SITE FS
		    ON SP.DIVISION_ID	= FS.DIVISION_ID
		        AND SP.FROM_SITE      = FS.SCM_SITE_ID
		        AND FS.SITE_TYPE       = 'PLANT'
		        -- 2021.10.21 : W/S AS 수정 , OPERATION_GROUP 파라미터 처리 및 OSP_YN 조건 제거
		        --AND FS.OPERATION_GROUP = 'A'
		        --AND FS.OSP_YN          = 'N'
		        AND FS.OPERATION_GROUP = @v_operation_group
		        AND FS.VALID_YN        = 'Y'

		INNER JOIN #TblDynamic_filter f 
		    ON SP.DIVISION_ID	= f.division_id
		        AND SP.ITEM_ID		= f.item_id
		        AND SP.FROM_SITE		= f.from_site

		        INNER JOIN #TblDynamic_SCP0045_40_STD ST
		        ON ST.DIVISION_ID = SP.DIVISION_ID
		        AND ST.FROM_SITE   = SP.FROM_SITE
		        AND ST.PLAN_START_YYYYMMDD = SP.PLAN_START_YYYYMMDD

	WHERE 1 = 1
		--AND SP.PLAN_START_YYYYMMDD = CONVERT(VARCHAR(8),GETDATE() , 112) -- 당일(현재는 현재일 -1)
		AND SP.MEASURE		= 'WH_STOCK'
		AND SP.DIVISION_ID    = @p_division_id
		AND SP.YYYYMMDD       = @p_from_yyyymmdd
		AND (( @p_scm_site_id	IS NULL OR @p_scm_site_id ='' ) OR SP.FROM_SITE IN (SELECT token FROM dbo.String_Split(@p_scm_site_id ,',')))
		AND (( @p_item_id		IS NULL OR @p_item_id     ='' )	OR SP.item_id   IN (SELECT token FROM dbo.String_Split(@p_item_id		,',')))
		AND SP.qty            >  0
		AND SP.DIVISION_ID    = '40' -- 소형(40) 인 경우만 조회


	PRINT '-------------STOCK INV : ' +  CONVERT(CHAR(23), getdate(), 21);

	WITH Z AS
    (
		SELECT DISTINCT DIVISION_ID
				,ITEM_ID
				,NICK_NAME
				,FROM_SITE
				,o.basis_yyyymmdd AS YYYYMMDD
		FROM scm_sys_calendar_m o WITH(NOLOCK) 
		    CROSS APPLY
            (
                SELECT DISTINCT DIVISION_ID
						,ITEM_ID
						,NICK_NAME
						,FROM_SITE
				FROM  #TblDynamic_SHIP_ROW  WITH(NOLOCK) 
            )  R
		WHERE o.basis_yyyymmdd>=@p_from_yyyymmdd
		    AND o.basis_yyyymmdd<=@p_to_yyyymmdd
	),
	QTY AS
    (
		SELECT  
			X.DIVISION_ID
			, X.ITEM_ID
			, X.FROM_SITE
			, X.YYYYMMDD
			, ISNULL( SUM(CASE  WHEN X.MEASURE= 'SHIP_PLAN'   THEN -1 * ISNULL(X.QTY,0)
										WHEN X.MEASURE= 'CUST_PLAN' THEN -1 * ISNULL(X.QTY,0)
										WHEN X.MEASURE= 'INTN_MOVEMENT' THEN -1 * ISNULL(X.QTY,0)
										WHEN X.MEASURE= 'INSP_PLAN' THEN ISNULL(X.QTY,0)
										ELSE 0.0  
				END),0)  AS PLAN_QTY
			, ISNULL( SUM(CASE  WHEN X.MEASURE= 'SHIP_REQ'   THEN -1 * ISNULL(X.QTY,0)
										WHEN X.MEASURE= 'CUST_REQ' THEN -1 * ISNULL(X.QTY,0)
										WHEN X.MEASURE= 'INTN_MOVEMENT' THEN -1 * ISNULL(X.QTY,0)
										WHEN X.MEASURE= 'INSP_PLAN' THEN ISNULL(X.QTY,0)
										ELSE 0.0  
				END),0) AS REQ_QTY
		FROM #TblDynamic_SHIP_ROW X WITH(NOLOCK)   
		WHERE 1=1  
		    AND X.MEASURE IN ( 'SHIP_PLAN', 'SHIP_REQ','CUST_PLAN', 'CUST_REQ', 'INTN_MOVEMENT', 'INSP_PLAN')
		GROUP BY X.DIVISION_ID, X.ITEM_ID, X.FROM_SITE, X.YYYYMMDD
	),
	BOH AS
    (   
	
		SELECT
			V.DIVISION_ID
			, ITEM_ID
			, FROM_SITE
			, YYYYMMDD
			, SUM(QTY) AS QTY
		FROM
        (
			SELECT inv.division_id
    				, inv.item_id
   					, inv.from_site
  					, inv.yyyymmdd
  					, inv.qty --SSP용
			FROM   #STOCK	inv WITH (NOLOCK)   -- 20200401 속도개선. TEMP Table 사용.
			    INNER JOIN scp_mst_final_item fi WITH (NOLOCK)
                    ON   inv.division_id    = fi.division_id 
						AND  inv.item_id        = fi.item_id
						AND  fi.operation_group = @p_operation_group
			WHERE  1=1
			    AND ( ( @p_scm_site_id IS NULL OR         @p_scm_site_id         ='' ) OR inv.from_site         IN (SELECT token FROM dbo.String_Split(@p_scm_site_id    ,',')) )
			    AND ( ( @p_item_id IS NULL OR         @p_item_id         ='' )	OR inv.item_id         IN (SELECT token FROM dbo.String_Split(@p_item_id    ,',')) )
		) V WHERE 1=1
		GROUP BY DIVISION_ID, ITEM_ID, FROM_SITE, YYYYMMDD
	)
	INSERT INTO #TblDynamic_CAL_QTY
	SELECT   
			Z.DIVISION_ID            
			,Z.ITEM_ID            
			,Z.NICK_NAME            
			,Z.FROM_SITE   
			,Z.YYYYMMDD  
			,( SELECT  
					ISNULL( SUM(PLAN_QTY),0)   
				FROM QTY X WITH(NOLOCK)   
				WHERE 1=1  
				AND X.DIVISION_ID          = Z.DIVISION_ID  
				AND X.ITEM_ID			   = Z.ITEM_ID           
				AND X.FROM_SITE            = Z.FROM_SITE  
				AND X.YYYYMMDD             < Z.YYYYMMDD        ) + ISNULL(BOH.QTY,0) AS PLAN_QTY
			,( SELECT  
					ISNULL( SUM(REQ_QTY),0)   
				FROM QTY X WITH(NOLOCK)   
				WHERE 1=1  
				AND X.DIVISION_ID          = Z.DIVISION_ID  
				AND X.ITEM_ID			   = Z.ITEM_ID           
				AND X.FROM_SITE            = Z.FROM_SITE  
				AND X.YYYYMMDD             < Z.YYYYMMDD        ) + ISNULL(BOH.QTY,0) AS REQ_QTY
	FROM Z WITH(NOLOCK)  
	    LEFT OUTER JOIN BOH WITH(NOLOCK) 
		    ON Z.DIVISION_ID		= BOH.DIVISION_ID  
		        AND Z.ITEM_ID			= BOH.ITEM_ID  
		        AND Z.FROM_SITE			= BOH.FROM_SITE  

	PRINT '-------------CAL BOH QTY : ' +  CONVERT(CHAR(23), getdate(), 21)
	;

	-----------------------------------------------
	-- 8. W/H BOH(Plan) : Cell Plant의 Cell 재고 ==> 기준 확정 필요함 : Cell 특성완료 이후 창고
	--                    일자별 BOH 계산  : BOH(D+1) = BOH(D) - Ship Plan(D) - Customer Plan(D) - Internal movement(D) + Inspection Plan(D)
	-----------------------------------------------
	INSERT INTO #TblDynamic_SHIP_ROW
	SELECT   
		Z.DIVISION_ID            
		,Z.ITEM_ID            
		,Z.NICK_NAME            
		,Z.FROM_SITE   
		,'-' AS TO_SITE
		,'-' AS TR_MODE
		,'-' AS INCOTERMS
		,'-'			AS BOD_ID	-- BOD 2단계 개발
		,'-' AS LT_DAY     
		,'WH_BOH_PLAN' AS MEASURE    
		,Z.YYYYMMDD  
		, ISNULL(Z.PLAN_QTY,0) AS QTY
		,8 AS SEQ
	FROM #TblDynamic_CAL_QTY Z WITH(NOLOCK)
	;
	/*
	WITH BOH AS (   
	
		SELECT
			V.DIVISION_ID
			, ITEM_ID
			, FROM_SITE
			, YYYYMMDD
			, SUM(QTY) AS QTY
		FROM (
			SELECT inv.division_id
    				, inv.item_id
   					, inv.scm_site_id       AS from_site
  					, @p_from_yyyymmdd		AS yyyymmdd
  					, inv.ssp_qty           AS qty --SSP용
			FROM   scm_dnm_stock_v	inv WITH (NOLOCK)  
			INNER JOIN (  SELECT division_id, site_id, max(cutoff_date) max_cutoff_date
							FROM   scm_dnm_stock_v WITH (NOLOCK)
							WHERE  division_id  = @p_division_id
							AND    cutoff_date >  @p_stock_yyyymmdd -- 현재일 - 3
							AND    cutoff_date <= @p_from_yyyymmdd -- 변수 : 현재일
							GROUP BY division_id, site_id
						) ms	ON   inv.division_id = ms.division_id 
								AND  inv.site_id     = ms.site_id
								AND	 inv.cutoff_date >  @p_stock_yyyymmdd
								AND  inv.cutoff_date = ms.max_cutoff_date
			INNER JOIN (  SELECT division_id, scm_site_id, operation_group, site_type
							FROM   scm_mst_site WITH (NOLOCK)
							WHERE  division_id     = @p_division_id
							AND    site_type       = 'PLANT' 
							AND    operation_group = @p_operation_group  -- Cell Plant Site
							AND    valid_yn        = 'Y'
						) b		ON   inv.division_id = b.division_id 
								AND  inv.scm_site_id = b.scm_site_id
			INNER JOIN ( SELECT DISTINCT
								a.storage_id
								,  a.location_code
								,  a.scm_site_id
								,  a.division_id
						 FROM   scm_mst_location a WITH (NOLOCK)
								INNER JOIN (  SELECT scm_site_id  
												FROM   scm_mst_site
												WHERE  division_id     = @p_division_id
												AND    valid_yn        = 'Y'
												AND    operation_group = @p_operation_group  -- Cell Plant Site
											) b		ON a.scm_site_id = b.scm_site_id 
													WHERE  a.division_id = @p_division_id
													AND    a.valid_yn    = 'Y'
													AND    location_code IN ('CELL_OWMS') -- Cell 특성완료 이후 창고
													AND    (storage_id IS NOT NULL AND storage_id <> '')
					)  c -- 셀 storage_id 별 사용대상 조회
					ON   inv.division_id = c.division_id 
					AND  inv.scm_site_id = c.scm_site_id  
					AND  inv.storage_id  = c.storage_id  
			INNER JOIN scp_mst_final_item fi WITH (NOLOCK)	ON   inv.division_id    = fi.division_id 
															AND  inv.item_id        = fi.item_id
															AND  fi.operation_group = @p_operation_group
			WHERE  1=1
			AND ( ( @p_scm_site_id IS NULL OR         @p_scm_site_id         ='' ) OR inv.scm_site_id         IN (SELECT token FROM dbo.String_Split(@p_scm_site_id    ,',')) )
			AND ( ( @p_item_id IS NULL OR         @p_item_id         ='' )	OR inv.item_id         IN (SELECT token FROM dbo.String_Split(@p_item_id    ,',')) )
		) V WHERE 1=1
		GROUP BY DIVISION_ID, ITEM_ID, FROM_SITE, YYYYMMDD
	),
	Z AS (
			SELECT DISTINCT DIVISION_ID
					,ITEM_ID
					,NICK_NAME
					,FROM_SITE
					,o.basis_yyyymmdd AS YYYYMMDD
			FROM scm_sys_calendar_m o WITH(NOLOCK) 
			CROSS APPLY (  SELECT DISTINCT DIVISION_ID
									,ITEM_ID
									,NICK_NAME
									,FROM_SITE
							FROM  #TblDynamic_SHIP_ROW  WITH(NOLOCK) 
								)  R
			WHERE o.basis_yyyymmdd>=@p_from_yyyymmdd
			AND o.basis_yyyymmdd<=@p_to_yyyymmdd
		)
	INSERT INTO #TblDynamic_SHIP_ROW
	SELECT   
			Z.DIVISION_ID            
			,Z.ITEM_ID            
			,Z.NICK_NAME            
			,Z.FROM_SITE   
			,'-' AS TO_SITE
			,'-' AS TR_MODE
			,'-' AS INCOTERMS
			,'-' AS LT_DAY     
			,'WH_BOH_PLAN' AS MEASURE    
			,Z.YYYYMMDD  
			,( SELECT  
					ISNULL( SUM(CASE  WHEN X.MEASURE= 'SHIP_PLAN'   THEN -1 * ISNULL(X.QTY,0)
											   WHEN X.MEASURE= 'CUST_PLAN' THEN -1 * ISNULL(X.QTY,0)
											   WHEN X.MEASURE= 'INTN_MOVEMENT' THEN -1 * ISNULL(X.QTY,0)
											   WHEN X.MEASURE= 'INSP_PLAN' THEN ISNULL(X.QTY,0)
											   ELSE 0.0  
						END),0)   
				FROM #TblDynamic_SHIP_ROW X WITH(NOLOCK)   
				WHERE 1=1  
				AND X.DIVISION_ID          = Z.DIVISION_ID  
				AND X.ITEM_ID			   = Z.ITEM_ID           
				AND X.FROM_SITE            = Z.FROM_SITE  
				AND X.MEASURE              IN ( 'SHIP_PLAN' ,'CUST_PLAN', 'INTN_MOVEMENT', 'INSP_PLAN')
				AND X.YYYYMMDD             < Z.YYYYMMDD        )   + ISNULL(BOH.QTY,0) AS QTY
			,8 AS SEQ
		FROM Z WITH(NOLOCK)   
		LEFT OUTER JOIN BOH WITH(NOLOCK) 
					ON Z.DIVISION_ID		= BOH.DIVISION_ID  
					AND Z.ITEM_ID			= BOH.ITEM_ID  
					AND Z.FROM_SITE			= BOH.FROM_SITE  
		INNER JOIN #TblDynamic_CAL_QTY TE WITH(NOLOCK)
					ON TE.DIVISION_ID = Z.DIVISION_ID
					AND TE.ITEM_ID = Z.ITEM_ID
					AND TE.FROM_SITE = Z.FROM_SITE
					AND TE.YYYYMMDD = Z.YYYYMMDD
		WHERE 1=1 
	;
	*/

	PRINT '-------------BOH(PLAN) : ' +  CONVERT(CHAR(23), getdate(), 21);

	-----------------------------------------------
	-- 9. W/H BOH(Req) : Cell Plant의 Cell 재고 ==> 기준 확정 필요함 : Cell 특성완료 이후 창고
	--                   일자별 BOH 계산  : BOH(D+1) = BOH(D) - Ship Req(D) - Customer Req(D) - Internal movement(D) + Inspection Plan(D)
	-----------------------------------------------
	INSERT INTO #TblDynamic_SHIP_ROW
	SELECT   
		Z.DIVISION_ID            
		,Z.ITEM_ID            
		,Z.NICK_NAME            
		,Z.FROM_SITE   
		,'-' AS TO_SITE
		,'-' AS TR_MODE
		,'-' AS INCOTERMS
		,'-'			AS BOD_ID	-- BOD 2단계 개발
		,'-' AS LT_DAY     
		,'WH_BOH_REQ' AS MEASURE    
		,Z.YYYYMMDD  
		, ISNULL(Z.REQ_QTY,0) AS QTY
		,9 AS SEQ
	FROM #TblDynamic_CAL_QTY Z WITH(NOLOCK)
	/*
	INSERT INTO #TblDynamic_SHIP_ROW
	SELECT DIVISION_ID
			, ITEM_ID
			, NICK_NAME
			, FROM_SITE
			, '-' AS TO_SITE
			, '-' AS TR_MODE
			, '-' AS INCOTERMS
			, '-' AS LT_DAY
			, 'WH_BOH_REQ' AS MEASURE
			, YYYYMMDD
			,ISNULL( SUM(CASE  WHEN MEASURE= 'SHIP_REQ'   THEN -1 * ISNULL(QTY,0)
											   WHEN MEASURE= 'CUST_REQ' THEN -1 * ISNULL(QTY,0)
											   WHEN MEASURE= 'INTN_MOVEMENT' THEN -1 * ISNULL(QTY,0)
											   WHEN MEASURE= 'WH_BOH_PLAN' THEN ISNULL(QTY,0)
											   ELSE 0.0  
						END),0) AS QTY
			, 9 AS SEQ
	FROM #TblDynamic_SHIP_ROW WITH(NOLOCK)
	WHERE 1=1
	  AND MEASURE IN ( 'SHIP_REQ' ,'CUST_REQ', 'INTN_MOVEMENT', 'WH_BOH_PLAN')
	GROUP BY DIVISION_ID
			, ITEM_ID
			, NICK_NAME
			, FROM_SITE
			, YYYYMMDD
	;


	PRINT '-------------BALANCE : ' +  CONVERT(CHAR(23), getdate(), 21);
	*/

	PRINT '-------------BOH(REQ) : ' +  CONVERT(CHAR(23), getdate(), 21);

	-----------------------------------------------
	-- 10. Requestor
	-----------------------------------------------
	/*
	SELECT distinct DIVISION_ID
		   , ITEM_ID
		   , FROM_SITE
		   , TO_SITE
		   , TR_MODE
		   , INCOTERMS
		   , MEASURE
		   , LAST_UPDATED_BY
	INTO #TblDynamic_REQUESTOR
	FROM #TblDynamic_SHIP_REQ WITH(NOLOCK)
	WHERE RN=1
	;
	*/
	
	-- 2020.01.03	Requestor 조회 시 Last Updated By 가 scp_batch인 것은 제외
	SELECT distinct A.DIVISION_ID
		   , A.ITEM_ID
		   , A.FROM_SITE
		   , A.TO_SITE
		   , A.TR_MODE
		   , A.INCOTERMS
		   , A.BOD_ID		-- BOD 2단계 개발
		   , A.MEASURE
		   , A.LAST_UPDATED_BY
	INTO #TblDynamic_REQUESTOR
	FROM #TblDynamic_SHIP_REQ A WITH(NOLOCK)
	WHERE A.RN=(SELECT ISNULL(MIN(B.RN),1) 
				FROM #TblDynamic_SHIP_REQ B 
				WHERE B.LAST_UPDATED_BY <> 'scp_batch'
				AND B.DIVISION_ID = A.DIVISION_ID
				AND B.ITEM_ID = A.ITEM_ID
				AND B.FROM_SITE = A.FROM_SITE
				AND B.TO_SITE = A.TO_SITE
				AND B.TR_MODE = A.TR_MODE
				AND B.INCOTERMS = A.INCOTERMS
				AND B.MEASURE = A.MEASURE
				)
	;

	PRINT '-------------REQUESTOR : ' +  CONVERT(CHAR(23), getdate(), 21);

	-- UI용 Measure 추가
	-- MEASURE : SCP_PLAN, SHIP_PLAN, SHIP_REQ
	INSERT INTO #TblDynamic_SHIP_ROW
	SELECT distinct A.division_id
			, A.item_id
			, A.NICK_NAME
			, A.from_site
			, A.to_site
			, A.tr_mode
			, A.incoterms
			, A.bod_id		-- BOD 2단계 개발
			, A.lt_day
			, M.measure
			, o.basis_yyyymmdd
			, NULL
			, M.seq
	FROM #TblDynamic_SHIP_ROW A WITH(NOLOCK)
		 CROSS APPLY (  SELECT basis_yyyymmdd 
								FROM scm_sys_calendar_m WITH(NOLOCK) 
								WHERE basis_yyyymmdd=@p_from_yyyymmdd
								--AND basis_yyyymmdd<=@p_to_yyyymmdd
								)  o
		CROSS APPLY (  SELECT COLUMN_NAME AS MEASURE
								,SORT_ORDER_NO AS SEQ
						FROM SCM_MST_SHEET_MEASURE WITH(NOLOCK)
						WHERE PROGRAM_ID=@p_program_id
						AND SHEET_NAME=@p_sheet_name
						AND COLUMN_NAME IN ('SCP_PLAN','SHIP_PLAN','SHIP_REQ')
								)  M 
	WHERE 1=1
	and A.MEASURE IN ('SCP_PLAN','SHIP_PLAN','SHIP_REQ')
	AND NOT EXISTS (SELECT 'X' 
					FROM #TblDynamic_SHIP_ROW B 
					WHERE B.DIVISION_ID = A.DIVISION_ID
					AND B.ITEM_ID = A.ITEM_ID
					AND B.FROM_SITE = A.FROM_SITE
					AND B.TO_SITE = A.TO_SITE
					AND B.TR_MODE = A.TR_MODE
					AND B.INCOTERMS = A.INCOTERMS
					AND B.BOD_ID		= A.BOD_ID  -- BOD 2단계 개발
					AND B.MEASURE = M.MEASURE
					AND B.YYYYMMDD = O.BASIS_YYYYMMDD
					)
	;

	PRINT '-------------MEASURE ADD 1 : ' +  CONVERT(CHAR(23), getdate(), 21)
	;

	-- MEASURE : CUST_PLAN, CUST_REQ, INTN_MOVEMENT, INSP_PLAN
	INSERT INTO #TblDynamic_SHIP_ROW
	SELECT distinct A.division_id
			, A.item_id
			, A.NICK_NAME
			, A.from_site
			, '-' AS to_site
			, '-' AS tr_mode
			, '-' AS incoterms
			, '-' AS lt_day
			, '-'	AS bod_id	-- BOD 2단계 개발
			, M.measure
			, o.basis_yyyymmdd
			, NULL
			, M.seq
	FROM #TblDynamic_SHIP_ROW A WITH(NOLOCK)
		 CROSS APPLY (  SELECT basis_yyyymmdd 
								FROM scm_sys_calendar_m WITH(NOLOCK) 
								WHERE basis_yyyymmdd=@p_from_yyyymmdd
								)  o
		CROSS APPLY (  SELECT COLUMN_NAME AS MEASURE
								,SORT_ORDER_NO AS SEQ
						FROM SCM_MST_SHEET_MEASURE WITH(NOLOCK)
						WHERE PROGRAM_ID=@p_program_id
						AND SHEET_NAME=@p_sheet_name
						AND COLUMN_NAME IN ('CUST_PLAN','CUST_REQ','INTN_MOVEMENT','INSP_PLAN')
								)  M 
	WHERE 1=1
	and A.MEASURE IN ('SCP_PLAN','SHIP_PLAN','SHIP_REQ')
	AND NOT EXISTS (SELECT 'X' 
					FROM #TblDynamic_SHIP_ROW B 
					WHERE B.DIVISION_ID = A.DIVISION_ID
					AND B.ITEM_ID = A.ITEM_ID
					AND B.FROM_SITE = A.FROM_SITE
					AND B.TO_SITE = '-'
					AND B.TR_MODE = '-'
					AND B.INCOTERMS = '-'
					AND B.BOD_ID	= '-'		-- BOD 2단계 개발
					AND B.MEASURE = M.MEASURE
					AND B.YYYYMMDD = O.BASIS_YYYYMMDD
					)
	;
	/*
	INSERT INTO #TblDynamic_SHIP_ROW
	SELECT distinct A.division_id
			, A.item_id
			, A.NICK_NAME
			, A.from_site
			, '-' AS to_site
			, '-' AS tr_mode
			, '-' AS incoterms
			, '-' AS lt_day
			, M.measure
			, o.basis_yyyymmdd
			, NULL
			, M.seq
	FROM #TblDynamic_SHIP_ROW A WITH(NOLOCK)
		 CROSS APPLY (  SELECT basis_yyyymmdd 
								FROM scm_sys_calendar_m WITH(NOLOCK) 
								WHERE basis_yyyymmdd=@p_from_yyyymmdd
								)  o
		CROSS APPLY (  SELECT COLUMN_NAME AS MEASURE
								,SORT_ORDER_NO AS SEQ
						FROM SCM_MST_SHEET_MEASURE WITH(NOLOCK)
						WHERE PROGRAM_ID=@p_program_id
						AND SHEET_NAME=@p_sheet_name
						AND COLUMN_NAME IN ('CUST_PLAN','CUST_REQ','INTN_MOVEMENT','INSP_PLAN')
								)  M 
	WHERE 1=1
	and A.MEASURE IN ('CUST_PLAN','CUST_REQ','INTN_MOVEMENT', 'INSP_PLAN')
	AND NOT EXISTS (SELECT 'X' 
					FROM #TblDynamic_SHIP_ROW B 
					WHERE B.DIVISION_ID = A.DIVISION_ID
					AND B.ITEM_ID = A.ITEM_ID
					AND B.FROM_SITE = A.FROM_SITE
					AND B.TO_SITE = A.TO_SITE
					AND B.TR_MODE = A.TR_MODE
					AND B.INCOTERMS = A.INCOTERMS
					AND B.MEASURE = M.MEASURE
					AND B.YYYYMMDD = O.BASIS_YYYYMMDD
					)
	;
	*/

	PRINT '-------------MEASURE ADD 2 : ' +  CONVERT(CHAR(23), getdate(), 21)
	;

	-- PIVOT용 Data정리
	SELECT A.DIVISION_ID
			, A.ITEM_ID
			, A.NICK_NAME
			, A.FROM_SITE
			, A.TO_SITE
			, A.TR_MODE
			, A.INCOTERMS
			, A.BOD_ID		-- BOD 2단계 개발
			, A.LT_DAY
			, A.MEASURE
			--, A.YYYYMMDD
			,'D_'+A.YYYYMMDD AS yyyymmdd
			,o.basis_yyyymm AS yyyymm
			,RIGHT(o.basis_yyyymm,4)+o.iso_week AS iso_week
			, A.QTY
			, A.SEQ
	INTO #TblDynamic_SHIP_PIVOT
	FROM #TblDynamic_SHIP_ROW A WITH(NOLOCK)
	INNER JOIN scm_sys_calendar_m o WITH(NOLOCK) on A.yyyymmdd = o.basis_yyyymmdd
	;

	PRINT '-------------PIVOT TABLE : ' +  CONVERT(CHAR(23), getdate(), 21);

	/********************************************************************************      
	* PIVOIT처리      
	********************************************************************************/
	BEGIN
		DECLARE @mQry_sum NVARCHAR(MAX);
		DECLARE @mEXEC NVARCHAR(MAX);
		DECLARE @mDAY_QTY NVARCHAR(MAX);

		-- PIVOIT 대상 날짜문자열 생성
		SET @mQry_sum = '';
			
		SELECT  @mQry_sum = @mQry_sum+','+ CASE WHEN CHARINDEX('M_', yyyymmdd) =1 THEN  'SUM(CASE WHEN yyyymm   = RIGHT('''+yyyymmdd+''',6) THEN QTY  END ) AS ' + yyyymmdd
												WHEN CHARINDEX('W_', yyyymmdd) =1 THEN  'SUM(CASE WHEN iso_week = RIGHT('''+yyyymmdd+''',6) THEN QTY  END ) AS ' + yyyymmdd
												WHEN CHARINDEX('D_', yyyymmdd) =1 THEN  'SUM(CASE WHEN yyyymmdd = '''+yyyymmdd+''' THEN QTY END ) AS ' + yyyymmdd
											END +''+CHAR(10)
		FROM
        ( 
			SELECT 'W_'+a.basis_yyyymm + a.iso_week AS yyyymmdd        
				, a.basis_start_date + CONVERT(CHAR(2), 21) AS sort_order_no
				FROM [dbo].[scm_sys_calendar_m] a 
			WHERE a.basis_yyyymmdd  BETWEEN @p_from_yyyymmdd AND @p_to_yyyymmdd
			GROUP BY a.basis_yyyymm, a.iso_week, a.basis_start_date

			UNION ALL

			SELECT 'M_'+a.basis_yyyymm  AS yyyymmdd
					,MIN(a.basis_start_date) + CONVERT(CHAR(2), '01') AS sort_order_no
				FROM [dbo].[scm_sys_calendar_m] a 
				WHERE a.basis_yyyymmdd  BETWEEN @p_from_yyyymmdd AND @p_to_yyyymmdd
			GROUP BY a.basis_yyyymm, a.month_name		

			UNION ALL

			SELECT 'D_'+a.basis_yyyymmdd   AS yyyymmdd      
					, a.basis_yyyymmdd + CONVERT(CHAR(2), 31) AS sort_order_no
				FROM [dbo].[scm_sys_calendar_m] a 
				WHERE a.basis_yyyymmdd  BETWEEN @p_from_yyyymmdd AND @p_to_yyyymmdd
			GROUP BY a.basis_yyyymmdd	
								
	    ) AS A
		ORDER BY sort_order_no  ;

		SET @mEXEC = '';
		SET @mEXEC = @mEXEC+'       SELECT															'+CHAR(10);
		SET @mEXEC = @mEXEC+'       	 P.DIVISION_ID												'+CHAR(10);
		SET @mEXEC = @mEXEC+'       	,P.ITEM_ID													'+CHAR(10);
		SET @mEXEC = @mEXEC+'       	,isnull(NULLIF(P.NICK_NAME, '''') , '' '') AS NICK_NAME		'+CHAR(10);
		SET @mEXEC = @mEXEC+' 			,P.FROM_SITE												'+CHAR(10);
		SET @mEXEC = @mEXEC+'       	,P.TO_SITE													'+CHAR(10);
		SET @mEXEC = @mEXEC+'       	,P.TR_MODE													'+CHAR(10);
		SET @mEXEC = @mEXEC+'       	,P.INCOTERMS												'+CHAR(10);
		SET @mEXEC = @mEXEC+'       	,P.BOD_ID													'+CHAR(10); -- BOD 2단계 개발
		SET @mEXEC = @mEXEC+'       	,B.FROM_YYYYMMDD	AS BOD_FROM_YYYYMMDD					'+CHAR(10); -- BOD 2단계 개발
		SET @mEXEC = @mEXEC+'       	,B.TO_YYYYMMDD		AS BOD_TO_YYYYMMDD						'+CHAR(10); -- BOD 2단계 개발
		SET @mEXEC = @mEXEC+'       	,P.LT_DAY													'+CHAR(10);
		SET @mEXEC = @mEXEC+'       	,C.USERNAME + ''('' + C.USERID + '')'' AS LAST_UPDATED_BY	'+CHAR(10);
		SET @mEXEC = @mEXEC+'       	,P.SEQ														'+CHAR(10);
		SET @mEXEC = @mEXEC+'       	,CONVERT(CHAR(8), DATEADD(DD, isnull(ship_frozen,0), CONVERT(VARCHAR, '''+@p_from_yyyymmdd+''', 121)), 112) AS FROZEN_YYYYMMDD '+CHAR(10);
		SET @mEXEC = @mEXEC+'       	,M.ATTRIBUTE3 AS MEASURE_COLOR								'+CHAR(10);
		--SET @mEXEC = @mEXEC+'       	,M.COLUMN_LABEL_NAME AS MEASURE_LABEL						'+CHAR(10);

		-- [C20201016-000147] : 소형(40) 사업부 추가 - 소형인 경우 MEASURE 명 변경
		SET @mEXEC = @mEXEC+'       	,CASE WHEN P.DIVISION_ID = ''40'' AND P.MEASURE = ''INSP_PLAN''     THEN ''WH in Plan''				' + CHAR(10);
		SET @mEXEC = @mEXEC+'       	      WHEN P.DIVISION_ID = ''40'' AND P.MEASURE = ''INTN_MOVEMENT'' THEN ''Post Process Plan''		' + CHAR(10);
		SET @mEXEC = @mEXEC+'       	      ELSE M.COLUMN_LABEL_NAME  END						AS MEASURE_LABEL							' + CHAR(10);
		SET @mEXEC = @mEXEC+'       	,P.MEASURE													'+CHAR(10);
		SET @mEXEC = @mEXEC+'       	'+@mQry_sum+CHAR(10);
		SET @mEXEC = @mEXEC+'       FROM #TblDynamic_SHIP_PIVOT P WITH(NOLOCK)								'+CHAR(10);
		SET @mEXEC = @mEXEC+'       LEFT JOIN  #TblDynamic_REQUESTOR R	ON R.DIVISION_ID = P.DIVISION_ID	'+CHAR(10);
		SET @mEXEC = @mEXEC+'											AND R.ITEM_ID = P.ITEM_ID			'+CHAR(10);
		SET @mEXEC = @mEXEC+'											AND R.FROM_SITE = P.FROM_SITE		'+CHAR(10);
		SET @mEXEC = @mEXEC+'											AND R.TO_SITE = P.TO_SITE			'+CHAR(10);
		SET @mEXEC = @mEXEC+'											AND R.TR_MODE = P.TR_MODE			'+CHAR(10);
		SET @mEXEC = @mEXEC+'											AND R.INCOTERMS = P.INCOTERMS		'+CHAR(10);
		SET @mEXEC = @mEXEC+'											AND R.BOD_ID	= P.BOD_ID			'+CHAR(10); -- BOD 2단계 개발
		SET @mEXEC = @mEXEC+'											AND R.MEASURE = P.MEASURE			'+CHAR(10);
		SET @mEXEC = @mEXEC+'       LEFT JOIN (SELECT UserID, UserName FROM TB_FX_User WITH(NOLOCK)) C					'+CHAR(10);
		SET @mEXEC = @mEXEC+'											ON R.last_updated_by = C.UserID		'+CHAR(10);
		-- BOD 2단계 개발 : FROM , TO 추가 시작
		SET @mEXEC = @mEXEC+'		LEFT JOIN SCP_MST_BOD_N_V B WITH(NOLOCK)								'+CHAR(10);
		SET @mEXEC = @mEXEC+'											ON P.BOD_ID = B.BOD_ID				'+CHAR(10);
		-- BOD 2단계 개발 : FROM , TO 추가 끝
		SET @mEXEC = @mEXEC+'       INNER JOIN  SCM_MST_SHEET_MEASURE M	WITH(NOLOCK) ON M.PROGRAM_ID = '''+@p_program_id+'''		'+CHAR(10);
		SET @mEXEC = @mEXEC+'											AND M.SHEET_NAME = '''+@p_sheet_name+'''	'+CHAR(10);
		SET @mEXEC = @mEXEC+'											AND M.COLUMN_NAME = P.MEASURE				'+CHAR(10);
		SET @mEXEC = @mEXEC+'       INNER JOIN  SCM_MST_SITE S	WITH(NOLOCK) ON S.DIVISION_ID = '''+@p_division_id+'''	'+CHAR(10); --@p_division_id
		SET @mEXEC = @mEXEC+'											AND S.OPERATION_GROUP = '''+@p_operation_group+'''			'+CHAR(10); --@p_operation_group
		SET @mEXEC = @mEXEC+'											AND S.SITE_TYPE=''PLANT''		'+CHAR(10);
		SET @mEXEC = @mEXEC+'											AND S.VALID_YN=''Y''			'+CHAR(10);
		SET @mEXEC = @mEXEC+'											AND S.SCM_SITE_ID=P.FROM_SITE			'+CHAR(10);
		SET @mEXEC = @mEXEC+'		GROUP BY  P.DIVISION_ID, P.ITEM_ID, P.NICK_NAME, P.FROM_SITE, P.TO_SITE, P.TR_MODE, P.INCOTERMS '+CHAR(10);
		SET @mEXEC = @mEXEC+'				  , P.LT_DAY, P.MEASURE, P.SEQ, C.USERID, C.USERNAME, M.COLUMN_LABEL_NAME, S.ship_frozen, M.ATTRIBUTE3	'+CHAR(10);
		SET @mEXEC = @mEXEC+'				  , P.BOD_ID, B.FROM_YYYYMMDD, B.TO_YYYYMMDD 															'+CHAR(10); -- BOD 2단계 개발
		-- BOD 2단계 개발 : BOD_ID 추가
		--SET @mEXEC = @mEXEC+'		ORDER BY  P.DIVISION_ID, P.ITEM_ID, P.FROM_SITE, P.TO_SITE DESC, P.TR_MODE, P.INCOTERMS, SEQ '+CHAR(10);
		SET @mEXEC = @mEXEC+'		ORDER BY  P.DIVISION_ID, P.ITEM_ID, P.FROM_SITE, P.TO_SITE DESC, P.TR_MODE, P.INCOTERMS, P.BOD_ID , SEQ '+CHAR(10);
			
		-----------------------------------------------------------
		-- DEBUG QRY 출력
		-----------------------------------------------------------	
		IF( @debug_mode ='T')
			BEGIN				
				DECLARE @POS INT =1;
				DECLARE @LEN INT =LEN(@mEXEC);
				WHILE @POS <= @LEN
					BEGIN
						PRINT SUBSTRING(@mEXEC,@POS,4000);
						SET @POS = @POS+4000;
					END;
			END;
		-----------------------------------------------------------

		EXEC (@mEXEC);

		PRINT '-------------PIVOT COMPLETE! : ' +  CONVERT(CHAR(23), getdate(), 21);

			
	END;


	-- 임시테이블 삭제
	IF OBJECT_ID('tempdb..#TblDynamic_PLAN') IS NOT NULL	
		DROP TABLE #TblDynamic_PLAN;

	IF OBJECT_ID('tempdb..#TblDynamic_SHIP_REQ') IS NOT NULL	
		DROP TABLE #TblDynamic_SHIP_REQ;

	IF OBJECT_ID('tempdb..#TblDynamic_SHIP_PIVOT') IS NOT NULL	
		DROP TABLE #TblDynamic_SHIP_PIVOT;

	IF OBJECT_ID('tempdb..#TblDynamic_SHIP_ROW') IS NOT NULL	
		DROP TABLE #TblDynamic_SHIP_ROW;

	IF OBJECT_ID('tempdb..#TblDynamic_REQUESTOR') IS NOT NULL	
		DROP TABLE #TblDynamic_REQUESTOR;

	IF OBJECT_ID('tempdb..#TblDynamic_CAL_QTY') IS NOT NULL	
		DROP TABLE #TblDynamic_CAL_QTY;

	IF OBJECT_ID('tempdb..#TblDynamic_filter') IS NOT NULL	
		DROP TABLE #TblDynamic_filter;

	IF OBJECT_ID('tempdb..#STOCK') IS NOT NULL	
		DROP TABLE #STOCK;


END 