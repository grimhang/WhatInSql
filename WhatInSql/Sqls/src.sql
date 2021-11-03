CREATE VIEW [dbo].[IF_FP_RELEASE_PLAN_V]
-- ================================================================================================
-- Program ID          : IF_FP_RELEASE_PLAN_V
--
-- Program Name        : IF_FP_RELEASE_PLAN_V
-- Param               :
-- Batch Period        : 
-- Description         : SCP 제공용 확정 Plan
--
-- Source System       : FP SDB
-- Destination System  : SCP SDB
-- Source Table        : FP_DAILY_PRODUCTIOIN_PLAN_H, SCM_DAILY_PRODUCT_RESULT_H, SCM_AGING_STOCK_H
-- Destination Table   : 
--
-- Create(Update) Date : 2020.07.22
-- Author              : kim choon dong
-- Version             : 2018-10-30 kimcd 소형 aging 재고, 조립 계획을 확정 계획으로 치환
--                       2018-11-20 kimcd 소형 aging 재고, 조립 계획을 확정 계획에서 Grading : 1일 L/T
--                                                                                   특성/포장 : 1일 L/T
--                                         리드 타임 반영하여 계획 일자 변경
--                       2018-11-29 kimcd 소형 조립 실적 기반으로 확정 계획 정보 형성
--                       2019-01-29 PIYONG SCM_FORMATION_YIELD_M 테이블에 MONTH 컬럼 삭제
--                       2019-05-20 kimcd 소형 ETW(F6200)은 WPP 기반으로 계획 반영
--                       2019-06-03 kimcd 소형 특성은 WPP 기반으로 계획 반영
--                                        F5300(원각특성), F5400(Pouch Grading), F5500(Pouch 특성), F5600(Pouch 특성 수작업), F6200(ETW) 공정 - WPP 전송
--                       2019-08-29 kimcd FORMATION_MMD_ROUTE_CONVERT SEGMENT4에 COMPANY_ID 추가에 따른 수정
--                       2019-10-02 kimcd 시업 시간별로 PLANT 조회하도록 수정
--                       2019-12-19 kimcd E2000 공정 TEST는 S-TEST로 임시 전환
--                       2020-01-29 kimcd E2000 공정 TEST는 S-TEST로 임시 전환 복원
--                       2020-07-22 kimcd 소형 ETW(F6200)은 Release 기반으로 계획 반영
-- ================================================================================================

AS

SELECT [COMPANY_ID]
      ,[DIVISION_ID]
      ,[SITE_ID]
      ,DPP.[PLANT_ID]
      ,[FACTORY_ID]
	  ,[OPERATION_ID]
      ,[LOCATION]
      ,[TOP_ITEM_ID]
      ,[ITEM_ID]
      ,DPP.[FP_PRODUCTION_TYPE]  -- 2019-12-19 kimcd E2000 공정 TEST는 S-TEST로 임시 전환 2020-01-29 kimcd 복원
      ,[MARKET]
      ,[LINE_ID]
      ,[ELECTRODE_TYPE]
      ,[PLAN_DATE]
      ,[PLAN_QTY]
      ,[PLAN_IN_QTY]
      ,[EQUIPMENT_ID]
 FROM FP_DAILY_PRODUCTIOIN_PLAN_H DPP WITH(NOLOCK)
	  , (SELECT SLV.SEGMENT1
	           ,SLP.SEGMENT1  AS PLANT_ID
			   ,SLV.ATTRIBUTE1
			   ,SLV.MODIFY_DATE
	     FROM   [DBO].[SCM_SYS_LOOKUP_VALUE]  SLV WITH(NOLOCK)
		       ,[DBO].[SCM_SYS_LOOKUP_VALUE]  SLP WITH(NOLOCK)
			   ,[DBO].[SCM_PLANT_M]           PM  WITH(NOLOCK)
		 WHERE  SLP.SEGMENT2         = SLV.SEGMENT2
		 AND    PM.SITE_ID           = SLV.SEGMENT1
		 AND    PM.PLANT_ID          = SLP.SEGMENT1
		 AND    SLV.LOOKUP_TYPE_CODE = 'AUTO_PLAN_CALL_FLAG'
         AND    SLV.ACTIVE_FLAG    = 'Y'
		 AND    SLP.LOOKUP_TYPE_CODE = 'BASIS_START_TIME_PLANT'
         AND    SLP.ACTIVE_FLAG    = 'Y'  )  SLV  -- 2019-10-02 kimcd 시업 시간별로 PLANT 조회하도록 수정
WHERE DPP.SITE_ID = SLV.SEGMENT1
  AND DPP.PLANT_ID  = SLV.PLANT_ID  -- 2019-10-02 kimcd 시업 시간별로 PLANT 조회하도록 수정
  AND ( ( DPP.PLAN_TYPE = 'RELEASE' AND DPP.OPERATION_ID NOT IN ( 'F5300', 'F5400', 'F5500', 'F5600', 'F6200' ) )
        OR (DPP.OPERATION_ID IN ( 'F5300', 'F5400', 'F5500', 'F5600'/*, 'F6200' 2020-07-22 제외 */) AND DPP.PLAN_TYPE = 'WPP')
		OR (DPP.OPERATION_ID = 'F6200' AND ( ( DPP.PLAN_TYPE = 'RELEASE' AND DPP.PLANT_ID != 'A010') OR ( DPP.PLAN_TYPE = 'WPP' AND DPP.PLANT_ID = 'A010') ) ) ) -- 2019-06-03 kimcd 남경 특성 WPP 기준 전송. 2019-05-20 kimcd 소형 ETW(F6200)은 WPP 기반으로 계획 반영
  AND ( ( DPP.PLAN_DATE >=  CONVERT(datetime,  ATTRIBUTE1 + ' 00:00:00', 120) AND DPP.OPERATION_ID NOT IN ( 'F5300', 'F5400', 'F5500', 'F5600', 'F6000') ) 
        OR (DPP.PLAN_DATE >=  CASE WHEN DATEADD(HH, 3, SLV.MODIFY_DATE) < GETDATE() THEN CONVERT(datetime,  ATTRIBUTE1 + ' 00:00:00', 120) ELSE DATEADD( D, -1, CONVERT(datetime,  ATTRIBUTE1 + ' 00:00:00', 120) ) END AND DPP.OPERATION_ID IN ( 'F5300', 'F54
00', 'F5500', 'F5600', 'F6000') ) )
		-- 2019-06-03 kimcd 특성 실적 취합 조건 분리
UNION ALL
SELECT [COMPANY_ID]
      ,[DIVISION_ID]
      ,[SITE_ID]
      ,DPR.[PLANT_ID]
      ,[FACTORY_ID]
	  ,[OPERATION_ID]
      ,[LOCATION]
      ,[TOP_ITEM_ID]
      ,[ITEM_ID]
	  ,DPR.[FP_PRODUCTION_TYPE]  -- 2019-12-19 kimcd E2000 공정 TEST는 S-TEST로 임시 전환 2020-01-29 kimcd 복원
      ,[MARKET]
      ,[LINE_ID]
      ,[ELECTRODE_TYPE]
      ,[PLAN_DATE]
      ,[ACTUAL_GOOD_QTY]  -- OUT 수량
      ,[ACTUAL_QTY]  -- IN 수량
      ,[EQUIPMENT_ID]
 FROM SCM_DAILY_PRODUCT_RESULT_H DPR WITH(NOLOCK)
      ,( SELECT SLV.SEGMENT1
	           ,SLP.SEGMENT1  AS PLANT_ID
			   ,SLV.ATTRIBUTE1
			   ,SLV.MODIFY_DATE
	     FROM   [DBO].[SCM_SYS_LOOKUP_VALUE]  SLV WITH(NOLOCK)
		       ,[DBO].[SCM_SYS_LOOKUP_VALUE]  SLP WITH(NOLOCK)
			   ,[DBO].[SCM_PLANT_M]           PM  WITH(NOLOCK)
		 WHERE  SLP.SEGMENT2         = SLV.SEGMENT2
		 AND    PM.SITE_ID           = SLV.SEGMENT1
		 AND    PM.PLANT_ID          = SLP.SEGMENT1
		 AND    SLV.LOOKUP_TYPE_CODE = 'AUTO_PLAN_CALL_FLAG'
         AND    SLV.ACTIVE_FLAG    = 'Y'
		 AND    SLP.LOOKUP_TYPE_CODE = 'BASIS_START_TIME_PLANT'
         AND    SLP.ACTIVE_FLAG    = 'Y'  ) SLV  -- 2019-10-02 kimcd 시업 시간별로 PLANT 조회하도록 수정
WHERE DPR.SITE_ID =  SLV.SEGMENT1
  AND SLV.PLANT_ID = DPR.PLANT_ID -- 2019-10-02 kimcd 시업 시간별로 PLANT 조회하도록 수정
  AND ( ( DPR.PLAN_DATE <  CONVERT(datetime,  ATTRIBUTE1 + ' 00:00:00', 120) AND DPR.OPERATION_ID NOT IN ( 'F5300', 'F5400', 'F5500', 'F5600', 'F6000') ) 
        OR (DPR.PLAN_DATE <  CASE WHEN DATEADD(HH, 3, SLV.MODIFY_DATE) < GETDATE() THEN CONVERT(datetime,  ATTRIBUTE1 + ' 00:00:00', 120) ELSE DATEADD( D, -1, CONVERT(datetime,  ATTRIBUTE1 + ' 00:00:00', 120) ) END AND DPR.OPERATION_ID IN ( 'F5300', 'F540
0', 'F5500', 'F5600', 'F6000') ) )
		-- 2019-06-03 kimcd 특성 실적 취합 조건 분리
  AND PLAN_DATE >= DATEADD(wk, (DATEDIFF(d, 0, ATTRIBUTE1) -7) / 7 , 0)  -- 2018-08-13 kimcd 일주 선행하도록 일자 조건 수정
UNION ALL
SELECT DPP.[COMPANY_ID]
      ,DPP.[DIVISION_ID]
      ,DPP.[SITE_ID]
      ,DPP.[PLANT_ID]
      ,DPP.[FACTORY_ID]
	  ,RIGHT(SI.FORMATION_FLOW_ID, 5) AS [OPERATION_ID]
      ,DPP.[LOCATION]
      ,DPP.[TOP_ITEM_ID]
      ,DPP.[ITEM_ID]
      ,DPP.[FP_PRODUCTION_TYPE]
      ,DPP.[MARKET]
      ,(SELECT TOP 1 FL.SEGMENT2
	    FROM   [DBO].[SCM_SYS_LOOKUP_VALUE]  FL WITH(NOLOCK)
		WHERE  FL.LOOKUP_TYPE_CODE = 'FORMATION_LINE_MAPPING' 
		AND    FL.ACTIVE_FLAG      = 'Y'
		AND    FL.SEGMENT1         = DPP.SITE_ID
		AND    FL.SEGMENT5         = DPP.LINE_ID) AS [LINE_ID]
      ,'-' AS [ELECTRODE_TYPE]
      ,DATEADD(DAY, ISNULL(( SELECT ST_SUM
	                         FROM   ( SELECT ISNULL(AIF.ROUTE_TOTAL_TIME/14400.0,0.0) + ISNULL(AIF.REMAIN_TIME/1440.0, 0.0)  AS ST_SUM
									       , ROW_NUMBER() OVER (ORDER BY AIF.OPERATION_SEQ, OPERATION_STEP) AS ROW_NUM
                                      FROM   SCM_AGING_ITEM_FLOW_M  AIF WITH(NOLOCK)
                                      WHERE  AIF.DEFAULT_ROUTE = 'Y'
									  AND   AIF.DEFAULT_FLAG = 'B' -- 기본 Route
                                      AND   AIF.COMPANY_ID   = DPP.COMPANY_ID
                                      AND   AIF.DIVISION_ID  = DPP.DIVISION_ID
                                      AND   AIF.SITE_ID      = DPP.SITE_ID
                                      AND   AIF.PLANT_ID     = DPP.PLANT_ID
                                      AND   AIF.FACTORY_ID   = DPP.FACTORY_ID
                                      AND   AIF.ITEM_ID      = DPP.ITEM_ID
                                      AND   AIF.LINE_ID      = (SELECT TOP 1 FL.SEGMENT2
																FROM   [DBO].[SCM_SYS_LOOKUP_VALUE]  FL WITH(NOLOCK)
																WHERE  FL.LOOKUP_TYPE_CODE = 'FORMATION_LINE_MAPPING' 
																AND    FL.ACTIVE_FLAG = 'Y'
																AND    FL.SEGMENT1 = DPP.SITE_ID
																AND    FL.SEGMENT5 = DPP.LINE_ID)) AIF 
							 WHERE ROW_NUM = 1), CONVERT(NUMERIC(20,10), FLO.ATTRIBUTE3) ) + 2 , DPP.[PLAN_DATE] ) AS PLAN_DATE -- 2018-11-20 kimcd grading, 특성 lead time으로 2일 추가
      ,FLOOR(DPP.PLAN_QTY * ISNULL(( SELECT CASE WHEN D.FORMATION_TOTAL_YIELD = 0 THEN 1 ELSE D.FORMATION_TOTAL_YIELD END * CASE WHEN D.CHARACTERIZATION_YIELD = 0 THEN 1 ELSE D.CHARACTERIZATION_YIELD END
	                                        -- 2018-11-20 kimcd 특성 yield 곱하기, 
									 FROM   SCM_FORMATION_YIELD_M D WITH(NOLOCK)
									 WHERE DPP.COMPANY_ID = D.COMPANY_ID
									 AND DPP.DIVISION_ID  = D.DIVISION_ID
									 AND DPP.SITE_ID      = D.SITE_ID
									 AND DPP.PLANT_ID     = D.PLANT_ID
									 AND DPP.FACTORY_ID   = D.FACTORY_ID
									 AND DPP.ITEM_ID      = D.ITEM_ID
									 AND DPP.LINE_ID      = D.LINE_ID
									 ),1)) AS [PLAN_QTY]
      ,DPP.PLAN_QTY AS [PLAN_IN_QTY]
      ,'-' AS [EQUIPMENT_ID]
 FROM FP_DAILY_PRODUCTIOIN_PLAN_H DPP WITH(NOLOCK)
	, [DBO].[SCM_ITEM_M]            SI WITH(NOLOCK)
	, (  SELECT SLV.SEGMENT1
	           ,SLP.SEGMENT1  AS PLANT_ID
			   ,SLV.ATTRIBUTE1
	     FROM   [DBO].[SCM_SYS_LOOKUP_VALUE]  SLV WITH(NOLOCK)
		       ,[DBO].[SCM_SYS_LOOKUP_VALUE]  SLP WITH(NOLOCK)
			   ,[DBO].[SCM_PLANT_M]           PM  WITH(NOLOCK)
		 WHERE  SLP.SEGMENT2         = SLV.SEGMENT2
		 AND    PM.SITE_ID           = SLV.SEGMENT1
		 AND    PM.PLANT_ID          = SLP.SEGMENT1
		 AND    SLV.LOOKUP_TYPE_CODE = 'AUTO_PLAN_CALL_FLAG'
         AND    SLV.ACTIVE_FLAG    = 'Y'
		 AND    SLP.LOOKUP_TYPE_CODE = 'BASIS_START_TIME_PLANT'
         AND    SLP.ACTIVE_FLAG    = 'Y'  )  SLV  -- 2019-10-02 kimcd 시업 시간별로 PLANT 조회하도록 수정
	, [DBO].[SCM_SYS_LOOKUP_VALUE]  FLO WITH(NOLOCK)
WHERE DPP.SITE_ID     = SI.SITE_ID
  AND DPP.COMPANY_ID  = SI.COMPANY_ID
  AND DPP.DIVISION_ID = SI.DIVISION_ID
  AND DPP.ITEM_ID     = SI.ITEM_ID
  AND DPP.SITE_ID     = SLV.SEGMENT1
  AND SLV.PLANT_ID    = DPP.PLANT_ID  -- 2019-10-02 kimcd 시업 시간별로 PLANT 조회하도록 수정
  AND DPP.SITE_ID     = FLO.SEGMENT1
  AND DPP.DIVISION_ID = FLO.SEGMENT2
  AND DPP.OPERATION_ID = FLO.SEGMENT3
  AND DPP.COMPANY_ID   = FLO.SEGMENT4 -- 2019-08-29 kimcd company id 추가
  AND FLO.LOOKUP_TYPE_CODE = 'FORMATION_MMD_ROUTE_CONVERT'
  AND FLO.ACTIVE_FLAG = 'Y'
  AND FLO.ATTRIBUTE2  = 'Y'
  AND DPP.PLAN_TYPE   = 'RELEASE'
  AND DPP.PLAN_DATE  >=  CONVERT(datetime,  SLV.ATTRIBUTE1 + ' 00:00:00', 120)
UNION ALL
/* 2018=11-29 kimcd 활성화 재고 기반 작업 제거
SELECT A.[COMPANY_ID]
      ,A.[DIVISION_ID]
      ,A.[SITE_ID]
      ,A.[PLANT_ID]
      ,A.[FACTORY_ID]
	  ,RIGHT(SI.FORMATION_FLOW_ID, 5) AS [OPERATION_ID]
      ,'-'                            AS [LOCATION]
      ,A.[ITEM_ID]                    AS [TOP_ITEM_ID]
      ,A.[ITEM_ID]
      ,A.[PRODUCTION_TYPE]
      ,'-'                            AS [MARKET]
      ,A.[LINE_ID]
      ,'-'                            AS [ELECTRODE_TYPE]
      ,DATEADD(DAY, 2, CASE WHEN A.[AGING_AVAILABLE_DATE] < A.[CUTOFF_DATE] THEN
								A.[CUTOFF_DATE]
						    ELSE A.[AGING_AVAILABLE_DATE] END ) AS [PLAN_DATE] -- 2018-11-20 kimcd grading, 특성 lead time으로 2일 추가
      ,FLOOR(A.[QTY] * ISNULL(( SELECT CASE WHEN D.CHARACTERIZATION_YIELD = 0 THEN 1 ELSE D.CHARACTERIZATION_YIELD END
								FROM   SCM_FORMATION_YIELD_M D WITH(NOLOCK)
								WHERE A.COMPANY_ID = D.COMPANY_ID
								AND A.DIVISION_ID  = D.DIVISION_ID
								AND A.SITE_ID      = D.SITE_ID
								AND A.PLANT_ID     = D.PLANT_ID
								AND A.FACTORY_ID   = D.FACTORY_ID
								AND A.ITEM_ID      = D.ITEM_ID
								AND A.LINE_ID      = D.LINE_ID
								AND D.MONTH        = CONVERT(NVARCHAR(6), GETDATE(), 112)),1)) AS [ACTUAL_GOOD_QTY]  -- 2018-11-20 kimcd 특성 yield 곱하기
      ,A.[INPUT_QTY]                  AS [ACTUAL_QTY]
	  ,'-'                            AS [EQUIPMENT_ID]
  FROM [DBO].[AGING_STOCK_V] A WITH(NOLOCK)
	  ,(SELECT  B.SITE_ID
				,MAX(B.CUTOFF_DATE) AS CUTOFF_DATE
		 FROM    [DBO].[SCM_AGING_STOCK_H] B WITH(NOLOCK)
		 GROUP BY B.SITE_ID ) B
	  , [DBO].[SCM_ITEM_M]            SI WITH(NOLOCK)
  	  , [DBO].[SCM_SYS_LOOKUP_VALUE]  FLO WITH(NOLOCK)
WHERE  A.SITE_ID     = B.SITE_ID
AND    A.CUTOFF_DATE = B.CUTOFF_DATE
AND    A.SITE_ID     = SI.SITE_ID
AND    A.COMPANY_ID  = SI.COMPANY_ID
AND    A.DIVISION_ID = SI.DIVISION_ID
AND    A.ITEM_ID     = SI.ITEM_ID
AND    SI.SITE_ID     = FLO.SEGMENT1
AND    SI.DIVISION_ID = FLO.SEGMENT2
AND    SI.FLOW_ID     = FLO.SEGMENT3
AND    SI.COMPANY_ID  = FLO.SEGMENT4 -- 2019-08-29 kimcd COMPANY_ID 추가
AND    FLO.LOOKUP_TYPE_CODE = 'FORMATION_MMD_ROUTE_CONVERT'
AND    FLO.ACTIVE_FLAG = 'Y'
AND    FLO.ATTRIBUTE2  = 'Y'
*/
-- 2018-11-29 kimcd 조립 실적 기반으로 특성 계획 형성 추가 시작
SELECT DPP.[COMPANY_ID]
      ,DPP.[DIVISION_ID]
      ,DPP.[SITE_ID]
      ,DPP.[PLANT_ID]
      ,DPP.[FACTORY_ID]
	  ,RIGHT(SI.FORMATION_FLOW_ID, 5) AS [OPERATION_ID]
      ,DPP.[LOCATION]
      ,DPP.[TOP_ITEM_ID]
      ,DPP.[ITEM_ID]
      ,DPP.[FP_PRODUCTION_TYPE]
      ,DPP.[MARKET]
      ,(SELECT TOP 1 FL.SEGMENT2
	    FROM   [DBO].[SCM_SYS_LOOKUP_VALUE]  FL WITH(NOLOCK)
		WHERE  FL.LOOKUP_TYPE_CODE = 'FORMATION_LINE_MAPPING' 
		AND    FL.ACTIVE_FLAG      = 'Y'
		AND    FL.SEGMENT1         = DPP.SITE_ID
		AND    FL.SEGMENT5         = DPP.LINE_ID) AS [LINE_ID]
      ,'-' AS [ELECTRODE_TYPE]
      ,DATEADD(DAY, ISNULL(( SELECT ST_SUM
	                         FROM   ( SELECT ISNULL(AIF.ROUTE_TOTAL_TIME/14400.0,0.0) + ISNULL(AIF.REMAIN_TIME/1440.0, 0.0)  AS ST_SUM
									       , ROW_NUMBER() OVER (ORDER BY AIF.OPERATION_SEQ, OPERATION_STEP) AS ROW_NUM
                                      FROM   SCM_AGING_ITEM_FLOW_M  AIF WITH(NOLOCK)
                                      WHERE  AIF.DEFAULT_ROUTE = 'Y'
									  AND   AIF.DEFAULT_FLAG = 'B' -- 기본 Route
                                      AND   AIF.COMPANY_ID   = DPP.COMPANY_ID
                                      AND   AIF.DIVISION_ID  = DPP.DIVISION_ID
                                      AND   AIF.SITE_ID      = DPP.SITE_ID
                                      AND   AIF.PLANT_ID     = DPP.PLANT_ID
                                      AND   AIF.FACTORY_ID   = DPP.FACTORY_ID
                                      AND   AIF.ITEM_ID      = DPP.ITEM_ID
                                      AND   AIF.LINE_ID      = (SELECT TOP 1 FL.SEGMENT2
																FROM   [DBO].[SCM_SYS_LOOKUP_VALUE]  FL WITH(NOLOCK)
																WHERE  FL.LOOKUP_TYPE_CODE = 'FORMATION_LINE_MAPPING' 
																AND    FL.ACTIVE_FLAG = 'Y'
																AND    FL.SEGMENT1 = DPP.SITE_ID
																AND    FL.SEGMENT5 = DPP.LINE_ID)) AIF 
							 WHERE ROW_NUM = 1), CONVERT(NUMERIC(20,10), FLO.ATTRIBUTE3) ) + 2 , DPP.[PLAN_DATE] ) AS PLAN_DATE -- 2018-11-20 kimcd grading, 특성 lead time으로 2일 추가
      ,FLOOR(DPP.ACTUAL_GOOD_QTY * ISNULL(( SELECT CASE WHEN D.FORMATION_TOTAL_YIELD = 0 THEN 1 ELSE D.FORMATION_TOTAL_YIELD END * CASE WHEN D.CHARACTERIZATION_YIELD = 0 THEN 1 ELSE D.CHARACTERIZATION_YIELD END
													-- 2018-11-20 kimcd 특성 yield 곱하기, 
											 FROM   SCM_FORMATION_YIELD_M D WITH(NOLOCK)
											 WHERE DPP.COMPANY_ID = D.COMPANY_ID
											 AND DPP.DIVISION_ID  = D.DIVISION_ID
											 AND DPP.SITE_ID      = D.SITE_ID
											 AND DPP.PLANT_ID     = D.PLANT_ID
											 AND DPP.FACTORY_ID   = D.FACTORY_ID
											 AND DPP.ITEM_ID      = D.ITEM_ID
											 AND DPP.LINE_ID      = D.LINE_ID ),1)) AS [PLAN_QTY]
      ,DPP.ACTUAL_GOOD_QTY AS [PLAN_IN_QTY]
      ,'-' AS [EQUIPMENT_ID]
 FROM SCM_DAILY_PRODUCT_RESULT_H    DPP WITH(NOLOCK)
	, [DBO].[SCM_ITEM_M]            SI  WITH(NOLOCK)
	, ( SELECT SLV.SEGMENT1
	           ,SLP.SEGMENT1  AS PLANT_ID
			   ,SLV.ATTRIBUTE1
	     FROM   [DBO].[SCM_SYS_LOOKUP_VALUE]  SLV WITH(NOLOCK)
		       ,[DBO].[SCM_SYS_LOOKUP_VALUE]  SLP WITH(NOLOCK)
			   ,[DBO].[SCM_PLANT_M]           PM  WITH(NOLOCK)
		 WHERE  SLP.SEGMENT2         = SLV.SEGMENT2
		 AND    PM.SITE_ID    = SLV.SEGMENT1
		 AND    PM.PLANT_ID          = SLP.SEGMENT1
		 AND    SLV.LOOKUP_TYPE_CODE = 'AUTO_PLAN_CALL_FLAG'
         AND    SLV.ACTIVE_FLAG    = 'Y'
		 AND    SLP.LOOKUP_TYPE_CODE = 'BASIS_START_TIME_PLANT'
         AND    SLP.ACTIVE_FLAG    = 'Y'  )  SLV -- 2019-10-02 kimcd 시업 시간별로 PLANT 조회하도록 수정
	, [DBO].[SCM_SYS_LOOKUP_VALUE]  FLO WITH(NOLOCK)
WHERE DPP.SITE_ID     = SI.SITE_ID
  AND DPP.COMPANY_ID  = SI.COMPANY_ID
  AND DPP.DIVISION_ID = SI.DIVISION_ID
  AND DPP.ITEM_ID     = SI.ITEM_ID
  AND DPP.SITE_ID     = SLV.SEGMENT1
  AND SLV.PLANT_ID    = DPP.PLANT_ID  -- 2019-10-02 kimcd 시업 시간별로 PLANT 조회하도록 수정
  AND DPP.SITE_ID     = FLO.SEGMENT1
  AND DPP.DIVISION_ID = FLO.SEGMENT2
  AND DPP.OPERATION_ID = FLO.SEGMENT3
  AND DPP.COMPANY_ID   = FLO.SEGMENT4 -- 2019-08-29 kimcd COMPANY_ID 추가
  AND FLO.LOOKUP_TYPE_CODE = 'FORMATION_MMD_ROUTE_CONVERT'
  AND FLO.ACTIVE_FLAG = 'Y'
  AND FLO.ATTRIBUTE2  = 'Y'
  AND DPP.PLAN_DATE  >=  DATEADD(DAY, - ISNULL(( SELECT ST_SUM
												 FROM   ( SELECT ISNULL(AIF.ROUTE_TOTAL_TIME/14400.0,0.0) + ISNULL(AIF.REMAIN_TIME/1440.0, 0.0)  AS ST_SUM
															   , ROW_NUMBER() OVER (ORDER BY AIF.OPERATION_SEQ, OPERATION_STEP) AS ROW_NUM
														  FROM   SCM_AGING_ITEM_FLOW_M  AIF WITH(NOLOCK)
														  WHERE  AIF.DEFAULT_ROUTE = 'Y'
														  AND   AIF.DEFAULT_FLAG = 'B' -- 기본 Route
														  AND   AIF.COMPANY_ID   = DPP.COMPANY_ID
														  AND   AIF.DIVISION_ID  = DPP.DIVISION_ID
														  AND   AIF.SITE_ID      = DPP.SITE_ID
														  AND   AIF.PLANT_ID     = DPP.PLANT_ID
														  AND   AIF.FACTORY_ID   = DPP.FACTORY_ID
														  AND   AIF.ITEM_ID      = DPP.ITEM_ID
														  AND   AIF.LINE_ID      = (SELECT TOP 1 FL.SEGMENT2
																					FROM   [DBO].[SCM_SYS_LOOKUP_VALUE]  FL WITH(NOLOCK)
																					WHERE  FL.LOOKUP_TYPE_CODE = 'FORMATION_LINE_MAPPING' 
																					AND    FL.ACTIVE_FLAG = 'Y'
																					AND    FL.SEGMENT1 = DPP.SITE_ID
																					AND    FL.SEGMENT5 = DPP.LINE_ID)) AIF 
												 WHERE ROW_NUM = 1), CONVERT(NUMERIC(20,10), FLO.ATTRIBUTE3) ) - 2 , CONVERT(datetime,  SLV.ATTRIBUTE1 + ' 00:00:00', 120) )
-- 2018-11-29 kimcd 조립 실적 기반으로 특성 계획 형성 추가 종료  


